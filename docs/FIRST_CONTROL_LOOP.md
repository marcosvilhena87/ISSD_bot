# First control loop

Esta etapa fecha o primeiro ciclo funcional do projeto:

```text
RAM -> estado -> decisao -> controle -> novo estado
```

## Estrutura validada

```text
base + 0x08 = camera X
base + 0x0C = camera Y
base + 0x2A = world X
base + 0x2C = world Y
```

Associações observadas:

```text
0x0D00 = Beranco
0x0E00 = Gomez
0x0F00 = Allejo
```

## chase_ball.lua

O bot é híbrido:

- em jogo normal com bola livre, persegue a bola usando coordenadas de mundo;
- quando a CPU tem posse, posiciona-se do lado do próprio gol em relação ao portador;
- com posse própria, devolve o controle ao humano;
- em reposição a favor, mantém controle manual;
- em reposição contra, ignora o cobrador e marca outro adversário.

### Atalhos

```text
K = bot ON/OFF
L = stop_on_possession ON/OFF
```

Essas teclas evitam conflito com F1/F2 do BizHawk, usados para load state.

## Máquina de estados

```text
Game_State = 0
├─ 0x00A6 aponta MY   -> POSSESSION_MANUAL
├─ 0x00A6 aponta CPU  -> LIVE_DEFENSE
└─ 0x00A6 = 0
   ├─ 0x104C = 0 -> MY_BALL_IN_FLIGHT
   ├─ 0x104C = 1 -> CPU_BALL_IN_FLIGHT
   └─ outro valor -> fallback temporal

Game_State = 1 ou 2
├─ cobrador MY  -> RESTART_ATTACK
└─ cobrador CPU -> RESTART_DEFENSE
```

`Game_State` fica em `WRAM 0x00BA`:

```text
0 = bola em jogo
1 = reposição pela linha de fundo
2 = lateral
```

Transições observadas e validadas:

```text
2 -> 0 após lateral
1 -> 0 após reposição pela linha de fundo
```

## Comportamento defensivo em reposição

O provável cobrador é o jogador mais próximo da bola.

Em reposição contra:

1. identificar o cobrador;
2. excluir esse jogador;
3. escolher o adversário sem bola mais próximo do jogador controlado;
4. mover-se para marcá-lo;
5. quando `Game_State` volta para `0`, retornar a `CHASING`.

## Status do marco

Validado em execução:

- leitura da RAM;
- coordenadas de mundo;
- envio de direções pelo BizHawk;
- perseguição automática da bola;
- detecção de posse;
- devolução do controle manual;
- lateral a favor/contra;
- reposição pela linha de fundo;
- retorno automático para jogo normal.

O próximo salto é melhorar a seleção defensiva do alvo e, depois, transformar o estado validado em observação para Gymnasium/RL.


## Contexto temporal de posse

`Possession=0x0000` significa que nenhum jogador está vinculado fisicamente à bola naquele frame; isso pode acontecer em passe, chute ou bola realmente solta.

O bot agora memoriza o último time/possuidor e a velocidade da bola para distinguir:

```text
CPU_BALL_IN_FLIGHT
MY_BALL_IN_FLIGHT
TRUE_LOOSE_BALL
```

Isso evita classificar imediatamente todo `Possession=0` como bola neutra.


## Posse por equipe nativa

`WRAM 0x104C` foi validado em jogo corrido:

```text
0 = MY
1 = CPU
```

Ele permanece estável durante passes longos mesmo quando `Player Possession (0x00A6)` cai para zero. Por isso passou a ser a fonte primária para identificar o lado da jogada sem possuidor físico. `possession_context.lua` permanece apenas como fallback defensivo.
