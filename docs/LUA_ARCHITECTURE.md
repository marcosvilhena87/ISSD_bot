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
├── field_side.lua
├── geometry.lua
├── movement.lua
├── defense.lua
├── live_defense.lua
├── live_attack.lua
├── gk_distribution.lua
├── interception.lua
├── player_switch.lua
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
1 = ENDLINE_RESTART
2 = THROW_IN
3 = FOUL_RESTART_SEQUENCE
4 = OFFSIDE_SEQUENCE
5 = POST_GOAL
```

### gameplay_active.lua

Lê `WRAM 0x0006` como guarda global:

```text
1 = gameplay ativo
0 = gameplay inativo (pause/replay)
```

Quando o valor não é `1`, `main.lua` entra em `BOT_IDLE`, limpa estados temporários e chama `movement.stop()` antes de qualquer lógica de posse ou reposição.

### field_side.lua

Centraliza a orientação do campo usando `WRAM 0x106E (CPU_Side)`, validado como fonte operacional estável.

```text
CPU_Side = 0 -> derived My_Side = 1
CPU_Side = 1 -> derived My_Side = 0

My_Side = 1 - CPU_Side
```

Também fornece:

```text
attack_direction()
goal_direction()
```

`0x056E` não é mais usado para decisões de orientação porque foi observado assumindo valores internos como `0x80/0x81/0x88/0x89`.

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

O cobrador é excluído. O termo territorial usa o `My_Side` derivado de `CPU_Side` validado em `0x056E`:

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

### live_attack.lua

Implementa o primeiro baseline ofensivo com posse controlada.

Quando `0x00A6 == MyCtrl` e o jogador controlado não é o goleiro MY, o bot conduz a bola na direção do gol adversário usando o `My_Side` derivado de `CPU_Side`:

```text
My_Side = 0 -> atacar para a direita
My_Side = 1 -> atacar para a esquerda
```

Com corredor frontal livre:

```text
ATTACK_ADVANCE

target_x = player_x + attack_direction * 96
target_y = player_y
```

O módulo também detecta o primeiro bloqueador CPU dentro de:

```text
até 72 unidades à frente
até 32 unidades para cada lado do corredor
```

Quando há bloqueio, entra em `ATTACK_LANE` e compara duas diagonais:

```text
80 para frente
56 para cima  OU  56 para baixo
```

A diagonal escolhida é a que possui maior distância mínima aos jogadores CPU. A escolha fica travada por 12 frames para evitar oscilação UP/DOWN.

Ainda não há decisão de chute, passe ou drible; esta etapa acrescenta apenas progressão com desvio espacial.

Se a posse física estiver em outro jogador MY, ou no nosso goleiro, o bot não injeta condução automática.

### gk_distribution.lua

Implementa a primeira política de reposição quando o goleiro MY está com a bola nas mãos:

```text
P = 0x0500
MyCtrl = 0x0500
→ GK_DISTRIBUTE
```

Ações validadas pelo controle:

```text
B = reposição com as mãos
A = chutão
```

Direção:

```text
UP / DOWN = laterais
My_Side=0 -> frente = RIGHT
My_Side=1 -> frente = LEFT
```

O módulo procura um companheiro de linha dentro de 360 unidades e exige pelo menos 72 unidades de folga para o adversário mais próximo.

Score inicial:

```text
score =
    1.00 * clearance
  + 0.35 * forward_progress
  - 0.25 * distance_from_GK
```

Se houver receptor seguro:

```text
GK_THROW
→ direção do receptor
→ B
```

Sem receptor seguro:

```text
GK_LONG_KICK
→ direção para frente
→ A
```

O input é emitido por um frame e só pode ser repetido após 30 frames se a bola ainda continuar nas mãos, evitando spam.

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
gk_press_distance = 160
```

Para o goleiro adversário (`CPU_FIRST = 0x1000`), o bot aplica uma regra especial:

```text
distancia ao CPU GK > 160 -> CPU_GK_HOLD
distancia ao CPU GK <= 160 -> LIVE_DEFENSE normal
```

Isso impede que um defensor atravesse o campo inteiro apenas para pressionar o goleiro rival, mas ainda permite pressão quando já está próximo.

Para jogadores de linha, o comportamento continua sendo posicionamento do lado do próprio gol em relação ao portador.

### interception.lua

Implementa o primeiro baseline de interceptação preditiva para bolas em trânsito da CPU.

Em vez de correr para a posição atual da bola, projeta:

```text
target = ball_pos + ball_velocity * lead_frames
```

O horizonte agora é dinâmico conforme a distância entre o defensor controlado e a bola:

```text
lead =
    min_lead_frames
    + floor(distance(player, ball) / distance_per_lead_frame)
```

Parâmetros iniciais:

```text
min_lead_frames         = 3
max_lead_frames         = 12
distance_per_lead_frame = 24
max_lead_distance       = 96
min_ball_speed          = 1.0
```

Assim o bot prevê pouco quando já está perto da jogada e mais quando está longe. O vetor previsto continua limitado a 96 unidades para reduzir overshoot. Se a bola estiver praticamente parada, o alvo volta a ser a posição atual da bola.

O HUD mostra velocidade, distância defensor-bola, alvo previsto, lead escolhido, vetor de lead e se houve clipping.

### player_switch.lua

Seleciona quando vale pedir ao próprio jogo uma troca de jogador defensivo via botão `R`.

O módulo não força diretamente uma base de jogador. Ele compara o jogador atualmente controlado com o jogador MY de linha mais próximo do alvo tático atual e, se a vantagem for grande o suficiente, pede uma troca ao engine:

```text
improvement =
    distancia(current, target)
    - distancia(best_MY, target)

improvement > 80
e cooldown == 0
→ pulso de R por 1 frame
```

Parâmetros iniciais:

```text
button = R
improvement_margin = 80
cooldown_frames = 12
exclude_goalkeeper = true
```

O alvo usado é o mesmo da decisão tática:

```text
CPU conduzindo -> Def target
bola em trânsito -> Intercept target
```

O jogador efetivamente selecionado ainda é decidido pelo próprio ISSD ao receber `R`; o cálculo do bot serve para decidir quando a troca vale a pena e evitar spam.

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
├─ Game_State = 3/4/5
│  └─ estado conhecido sem movimento
│
└─ Game_State = 0
   ├─ 0x00A6 == MyCtrl e jogador de linha
   │  ├─ corredor livre -> ATTACK_ADVANCE
   │  └─ bloqueador frontal -> ATTACK_LANE
   ├─ 0x00A6 = outro jogador MY -> MY_TEAMMATE_POSSESSION
   ├─ 0x00A6 = MY GK -> GK_DISTRIBUTE
   ├─ 0x00A6 = jogador CPU -> PLAYER_SWITCH se necessário -> LIVE_DEFENSE
   └─ 0x00A6 = 0
   ├─ 0x104C = 0 -> MY_BALL_IN_FLIGHT
   ├─ 0x104C = 1 -> PLAYER_SWITCH se necessário -> CPU_BALL_INTERCEPT
   └─ outro valor -> possession_context fallback

Game_State = 1/2
├─ cobrador MY  -> RESTART_ATTACK
└─ cobrador CPU -> RESTART_DEFENSE

Game_State = 3/4/5
└─ estado conhecido sem automação de movimento
   ├─ 3 -> FOUL_RESTART_SEQUENCE
   ├─ 4 -> OFFSIDE_SEQUENCE
   └─ 5 -> POST_GOAL
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


### Prioridade semântica de estados

Depois de validar telas de seleção de cobrador e cobrança com `GS=3` e `MyCtrl=0`, a ordem do loop passou a ser:

```text
GameplayActive
→ Game_State 3/4/5
→ validação de MyCtrl
→ demais estados
```

Assim `FOUL_RESTART_SEQUENCE`, `OFFSIDE_SEQUENCE` e `POST_GOAL` são reconhecidos mesmo quando não existe jogador controlável.
