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

Seleciona alvo defensivo. O baseline atual é:

> adversário mais próximo do jogador controlado, excluindo o cobrador.

Este módulo é o ponto planejado para evoluir para `marking_score`, linha de passe e posicionamento entre atacante e gol.

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
