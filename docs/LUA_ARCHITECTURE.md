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
├── geometry.lua
├── movement.lua
├── defense.lua
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

### restart.lua

Identifica o provável cobrador pela proximidade da bola e delega a seleção do alvo defensivo.

### overlay.lua

Centraliza o HUD de debug.

### main.lua

Contém somente a orquestração / máquina de estados:

```text
Game_State = 0
├─ posse própria -> POSSESSION_MANUAL
└─ restante      -> CHASING

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
