# Arquitetura Lua modular

A automação do BizHawk foi dividida em módulos para evitar que `chase_ball.lua` vire um arquivo monolítico.

## Entrada

```text
tools/bizhawk/chase_ball.lua
        ↓
tools/bizhawk/issd/main.lua
```

`chase_ball.lua` é apenas um launcher compatível com o fluxo já usado no BizHawk.

## Módulos

```text
tools/bizhawk/issd/
├── main.lua
├── config.lua
├── memory.lua
├── players.lua
├── ball.lua
├── game_state.lua
├── gameplay_active.lua
├── geometry.lua
├── movement.lua
├── defense.lua
├── live_defense.lua
├── team_possession.lua
├── possession_context.lua
├── restart.lua
└── overlay.lua
```

### config.lua

Centraliza:

- endereços WRAM;
- offsets das structs;
- intervalos dos jogadores;
- deadzones;
- Player 1 / domínio WRAM.

### memory.lua

Único ponto para leituras primitivas da RAM:

- `s16`;
- `u16`;
- `u8`.

### players.lua

Responsável por:

- validar bases de structs;
- ler world/camera X/Y;
- iterar os 11 jogadores de cada time;
- decodificar jogadores conhecidos.

### ball.lua

Responsável por:

- `Ball X/Y`;
- `Possession`.

### game_state.lua

Decodifica `WRAM 0x00BA`:

```text
0 = LIVE
1 = ENDLINE
2 = THROW_IN
```

### gameplay_active.lua

Lê `WRAM 0x0006` como guarda global:

```text
1 = gameplay ativo
0 = gameplay inativo (pause/replay)
```

Quando o valor não é `1`, `main.lua` entra em `BOT_IDLE`, limpa estados temporários e chama `movement.stop()` antes de qualquer lógica de posse ou reposição.

### geometry.lua

Funções geométricas sem dependência do emulador.

### movement.lua

Converte deltas X/Y em comandos direcionais e envia o movimento ao controle.

### defense.lua

Seleciona alvo defensivo por `marking_score`. Antes do peso final, cada componente é normalizado por min-max entre os candidatos da própria reposição:

```text
norm = (valor - mínimo) / (máximo - mínimo)

score =
    0.35 * me_norm
  + 0.25 * ball_norm
  + 0.40 * goal_norm
```

Assim os pesos 35% / 25% / 40% deixam de ser distorcidos pelas escalas originais das distâncias e do eixo X.

O cobrador é excluído. O termo territorial usa `My_Side` validado em `0x056E`:

```text
My_Side = 0 -> defendemos a esquerda -> X menor é mais perigoso
My_Side = 1 -> defendemos a direita  -> X maior é mais perigoso
```

A implementação usa somente a ordem do eixo X, sem depender de uma coordenada exata ainda não validada para a linha do gol.

Depois de calcular os scores, os candidatos são ordenados do menor para o maior. O primeiro é o alvo usado pelo bot, e o HUD mostra o Top 3:

```text
#1 CPU ... S=.xxx M=.xx B=.xx G=.xx
#2 CPU ... S=.xxx M=.xx B=.xx G=.xx
#3 CPU ... S=.xxx M=.xx B=.xx G=.xx
```

Isso permite auditar não só o vencedor, mas também a margem para os próximos candidatos antes de recalibrar os pesos.

Para evitar oscilação entre candidatos com scores muito próximos, `restart.lua` aplica histerese somente durante `RESTART_DEFENSE`:

```text
TARGET_LOCK_FRAMES = 10
SWITCH_MARGIN      = 0.05
```

Regras:

- o primeiro alvo fica comprometido por pelo menos 10 frames;
- depois disso, um novo #1 só assume se melhorar o score em mais de 0.05;
- se o alvo atual deixar de ser válido, a troca é imediata;
- se o cobrador mudar, o lock é reiniciado;
- quando `Game_State` volta para `0`, `restart.clear()` apaga imediatamente o lock e o bot retorna ao fluxo normal.

O HUD mostra `Lock`, `delta` e `HOLD/FREE` para auditar a histerese.

Quando uma troca é realmente autorizada por `delta > SWITCH_MARGIN`, o evento fica visível por 60 frames:

```text
SWITCH CPU slot 9 -> CPU slot 5 d=0.071 age=6
```

Esse evento persiste após o frame da troca, permitindo comprovar a mudança sem precisar capturar exatamente o instante em que ela ocorreu. Trocas forçadas por mudança de cobrador ou invalidação do alvo não são registradas como evento de histerese.

### live_defense.lua

Implementa o primeiro baseline de defesa em jogo corrido. Quando `Game_State=0` e `Possession` pertence a um jogador da CPU, o próprio valor de `Possession` é usado como base da struct do portador.

O alvo defensivo fica `goal_side_offset` unidades no lado do nosso gol em relação ao portador:

```text
My_Side = 0 -> target_x = carrier_x - offset
My_Side = 1 -> target_x = carrier_x + offset
target_y = carrier_y
```

Baseline atual:

```text
goal_side_offset = 48
```

Isso evita depender de uma coordenada exata do gol ainda não validada e já muda o comportamento de perseguição da bola para posicionamento entre portador e nosso lado defensivo.

### team_possession.lua

Lê `WRAM 0x104C` como fonte primária de posse lógica por equipe em jogo corrido:

```text
0 = MY
1 = CPU
```

`0x00A6` continua sendo usado para identificar o jogador fisicamente ligado à bola. Assim, durante passes longos com `0x00A6=0`, `0x104C` preserva o lado da jogada.

### possession_context.lua

Mantém contexto temporal quando `Possession (0x00A6)` cai para `0x0000`.

O módulo guarda:

```text
last_team
last_owner
frames_without_possession
prev_ball_x / prev_ball_y
ball_dx / ball_dy
ball_speed
```

Parâmetros atuais:

```text
grace_frames        = 18
initial_grace_frames= 2
moving_threshold    = 2.0
```

Classificação:

```text
MY_CONTROLLED
CPU_CONTROLLED
MY_BALL_IN_FLIGHT
CPU_BALL_IN_FLIGHT
TRUE_LOOSE_BALL
UNKNOWN_POSSESSION
```

Quando `Possession=0`, o contexto anterior é preservado por até 18 frames se a bola estiver em movimento. Os primeiros 2 frames têm tolerância mesmo antes de a velocidade ficar clara.

Assim, um passe ou chute da CPU não vira imediatamente `LOOSE_BALL_CHASE`. Durante `CPU_BALL_IN_FLIGHT`, o bot tenta atacar/interceptar a posição atual da bola. Durante `MY_BALL_IN_FLIGHT`, o bot não injeta movimento e preserva controle manual. O contexto é zerado fora de `Game_State=0`.

### restart.lua

Identifica o provável cobrador pela proximidade da bola e delega a seleção do alvo defensivo.

### overlay.lua

Centraliza o HUD de debug.

### main.lua

Contém somente a orquestração / máquina de estados:

```text
0x0006 != 1
└─ BOT_IDLE

0x0006 == 1
└─ Game_State = 0
├─ 0x00A6 = jogador MY  -> POSSESSION_MANUAL
├─ 0x00A6 = jogador CPU -> LIVE_DEFENSE
└─ 0x00A6 = 0
   ├─ 0x104C = 0 -> MY_BALL_IN_FLIGHT
   ├─ 0x104C = 1 -> CPU_BALL_IN_FLIGHT
   └─ outro valor -> possession_context fallback

Game_State = 1/2
├─ cobrador MY  -> RESTART_ATTACK
└─ cobrador CPU -> RESTART_DEFENSE
```

## Regra de manutenção

Novas capacidades devem preferencialmente entrar no módulo responsável, não em `main.lua`.

Exemplos:

- novo endereço RAM -> `config.lua` / `memory.lua`;
- novo campo de jogador -> `players.lua`;
- interceptação -> `defense.lua`;
- nova reposição -> `game_state.lua` / `restart.lua`;
- novo HUD -> `overlay.lua`.

O objetivo é manter `main.lua` pequeno e previsível.


## RAM probes

### team_possession_probe.lua

Probe dedicado para procurar posse lógica por equipe na WRAM.

Ele compara quatro classes sem depender de `0x00A6` durante o passe:

```text
MY_CONTROLLED
MY_PASS
CPU_CONTROLLED
CPU_PASS
```

Critério de candidato:

```text
MY_CONTROLLED == MY_PASS
CPU_CONTROLLED == CPU_PASS
MY != CPU
```

O scanner mantém apenas endereços estáveis dentro de cada classe e imprime candidatos tanto como `u8` quanto `u16 little-endian`.

O objetivo é substituir, se possível, a heurística temporal de `possession_context.lua` por uma variável nativa do jogo que represente posse por equipe.


### team_possession_watch.lua

Probe focal para validar `WRAM 0x104C` antes de integrá-lo ao bot.

O HUD mostra em tempo real o candidato, `Player Possession`, `Game_State`, bola, controles e orientação dos lados. Toda mudança de `0x104C` é persistida no console com o contexto do frame.

Hipótese atual:

```text
0x104C = 0 -> MY
0x104C = 1 -> CPU
```

Foi validado em condução e passe longo dos dois times durante `Game_State=0`. O probe continua útil para caracterizar bola neutra, reposições, replay e troca de lados.


### replay_probe.lua

Probe dedicado para localizar uma flag que diferencie gameplay realmente ativo de replay.

Motivação: foi observado que `Game_State=0` também durante `RESUME REPLAY`. O scanner captura estados LIVE e REPLAY, mantém apenas bytes estáveis dentro de cada classe e ranqueia candidatos que mudam entre as duas.

A integração no bot só deve ocorrer depois de validar um endereço em múltiplos replays e partidas.


### gameplay_active_watch.lua

Watcher focal de `WRAM 0x0006`.

Hipótese:

```text
1 = gameplay ativo
0 = replay / pause / gameplay inativo
```

O watcher registra apenas transições e inclui no contexto `Game_State`, `TeamPoss`, `PlayerPoss`, bola, controles e lados.

A intenção é validar uma guarda global futura:

```text
0x0006 != 1 -> BOT_IDLE
0x0006 == 1 -> máquina normal
```

A guarda foi validada em gameplay normal, pause e replay e já está integrada ao bot principal.
