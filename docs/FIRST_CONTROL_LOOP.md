# First control loop

Esta etapa introduz os primeiros scripts que fecham o ciclo:

```text
RAM -> estado -> decisao -> controle -> novo estado
```

## player_probe.lua

Valida a hipotese de estrutura generica:

```text
base + 0x08 = camera X
base + 0x0C = camera Y
base + 0x2A = world X
base + 0x2C = world Y
```

Tambem mostra:

- Ball world/camera;
- MyCtrl;
- CPUCtrl;
- possession;
- delta entre jogador controlado e bola.

Associacoes nominalmente observadas ate agora:

```text
0x0D00 = Beranco
0x0E00 = Gomez
0x0F00 = Allejo
```

## chase_ball.lua

Baseline deterministico.

Algoritmo:

```text
dx = ball_x - player_x
dy = ball_y - player_y

dx > deadzone  -> Right
dx < -deadzone -> Left

dy > deadzone  -> Down
dy < -deadzone -> Up
```

O script pode parar automaticamente quando:

```text
Possession == MyCtrl
```

Isto testa antes de RL:

1. leitura da RAM;
2. estrutura do jogador;
3. orientacao dos eixos;
4. escrita no controle;
5. ciclo percepcao-decisao-acao.

## Uso

No BizHawk:

```text
Tools -> Lua Console -> Open Script
```

Primeiro rode:

```text
tools/bizhawk/player_probe.lua
```

Depois:

```text
tools/bizhawk/chase_ball.lua
```

No chase bot:

- F1 liga/desliga;
- F2 alterna parar quando conquistar posse.

## Criterio de sucesso

O primeiro marco de controle esta concluido se:

- o jogador controlado se move consistentemente em direcao a bola;
- diagonais funcionam;
- a direcao nao se inverte quando a camera se move;
- o bot para quando `Possession == MyCtrl`.

Se algum eixo estiver invertido, corrija somente o mapeamento das direcoes; as coordenadas de mundo continuam sendo a fonte principal.
