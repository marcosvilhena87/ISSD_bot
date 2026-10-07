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
├─ 0x00A6 == MyCtrl e jogador de linha -> ATTACK_ADVANCE
├─ 0x00A6 aponta outro MY              -> MY_TEAMMATE_POSSESSION
├─ 0x00A6 aponta MY GK                 -> GK_DISTRIBUTE
├─ 0x00A6 aponta CPU  -> LIVE_DEFENSE
└─ 0x00A6 = 0
   ├─ 0x104C = 0 -> MY_BALL_IN_FLIGHT
   ├─ 0x104C = 1 -> CPU_BALL_INTERCEPT
   └─ outro valor -> fallback temporal

Game_State = 1 ou 2
├─ cobrador MY  -> RESTART_ATTACK
└─ cobrador CPU -> RESTART_DEFENSE

Game_State = 3, 4 ou 5
└─ sem movimento automático
```

`Game_State` fica em `WRAM 0x00BA`:

```text
0 = LIVE
1 = ENDLINE_RESTART
2 = THROW_IN
3 = FOUL_RESTART_SEQUENCE
4 = OFFSIDE_SEQUENCE
5 = POST_GOAL
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


## Guarda global de gameplay

`WRAM 0x0006` foi validado:

```text
1 = gameplay ativo
0 = pause/replay
```

A primeira decisão do loop agora é:

```text
0x0006 != 1
→ BOT_IDLE
→ liberar input do bot
→ limpar restart/possession_context

0x0006 == 1
→ continuar para Game_State / TeamPoss / PlayerPoss
```

Isso impede que o bot continue executando lógica de jogo durante pause ou replay, mesmo quando `Game_State=0`.


## Prioridade de estados especiais

`Game_State=3/4/5` agora é interpretado antes de validar `MyCtrl`.

Isso evita classificar telas legítimas de seleção/cobrança como `BOT_IDLE_NO_PLAYER`. Mesmo com `MyCtrl=0`, o HUD mostra o estado semântico correto:

```text
3 -> FOUL_RESTART_SEQUENCE
4 -> OFFSIDE_SEQUENCE
5 -> POST_GOAL
```

Nesses estados o bot continua sem enviar movimento.


## Interceptação preditiva

Quando a CPU mantém a posse lógica da jogada (`0x104C=1`) mas `0x00A6=0`, o bot não corre mais para a posição atual da bola.

Ele projeta um alvo à frente da trajetória usando a velocidade observada da bola e um horizonte que cresce com a distância do defensor:

```text
lead = 3 + floor(distance(player, ball) / 24)
lead limitado a 3..12 frames

max_lead_distance = 96
min_ball_speed    = 1.0
```

O HUD expõe `BallV`, `Dist`, `Intercept`, `lead`, `pred`, `LeadVec` e `clip` para calibração empírica.


## Posse do goleiro adversário

Quando `PlayerPoss = 0x1000` (CPU GK), o bot não persegue mais o goleiro de qualquer distância.

Regra inicial:

```text
distancia > 160 -> CPU_GK_HOLD + movement.stop()
distancia <= 160 -> LIVE_DEFENSE normal
```

O HUD mostra `GK dist`, `threshold` e `HOLD/PRESS` para calibração.


## Troca automática de defensor

Antes de executar `LIVE_DEFENSE` ou `CPU_BALL_INTERCEPT`, o bot compara o jogador atual com os jogadores MY de linha para o mesmo alvo tático.

Regra inicial:

```text
ganho de distancia > 80
e cooldown = 0
→ PLAYER_SWITCH
→ pulso de R por 1 frame
→ cooldown de 12 frames
```

O goleiro MY é excluído da seleção automática.

O HUD mostra:

```text
Switch current -> best via R
Dist current=... best=... gain=...
Cooldown=...
```

Importante: `best` é a referência espacial usada para decidir se vale pedir a troca; o jogador realmente escolhido é determinado pelo mecanismo nativo de troca do ISSD.


## Progressão ofensiva

Com posse física no próprio jogador controlado, o bot agora inicia a primeira política ofensiva:

```text
My_Side=0 -> avançar para a direita
My_Side=1 -> avançar para a esquerda

advance_distance = 96
```

Estados:

```text
ATTACK_ADVANCE -> corredor frontal livre
ATTACK_LANE    -> adversário bloqueando a progressão
```

Critério inicial de bloqueio:

```text
forward <= 72
lateral <= 32
```

Em `ATTACK_LANE`, o bot testa alvos diagonais `80` à frente e `56` para cima/baixo, escolhendo o lado com maior folga para adversários. A decisão fica travada por 12 frames para reduzir zigue-zague.

O HUD mostra alvo, direção, modo, bloqueador, direção da diagonal, lock e clearance UP/DOWN.

Proteções iniciais:

```text
possession != MyCtrl -> não mover automaticamente
MyCtrl == MY GK      -> não avançar automaticamente
```

Ainda não há escolha de corredor, passe, drible ou chute; esta etapa valida somente a capacidade de ganhar território com posse.


## Reposição com o goleiro

Quando o goleiro controlado está com a bola nas mãos:

```text
P=$0500
MyCtrl=$0500
→ GK_DISTRIBUTE
```

A política inicial tenta primeiro uma saída curta:

```text
companheiro <= 360 unidades
e clearance >= 72
→ escolher melhor receptor
→ UP/DOWN ou frente
→ B
```

Score do receptor:

```text
1.00 * clearance
+ 0.35 * progressao para frente
- 0.25 * distancia ao goleiro
```

Se não houver receptor curto seguro:

```text
frente relativa ao gol adversário + A
→ chutão
```

A direção para frente usa `My_Side`:

```text
My_Side=0 -> RIGHT
My_Side=1 -> LEFT
```

O HUD mostra ação, direção, botão, receptor, distância, clearance, progressão e score.


## Orientação do campo consolidada

`WRAM 0x106E (CPU_Side)` passou a ser a fonte operacional para direção do campo.

```text
CPU_Side=0 -> My_Side derivado=1
CPU_Side=1 -> My_Side derivado=0
```

O watcher focal manteve `Invalid CPU_Side frames=0` e confirmou a inversão na troca de lados.

A orientação é centralizada em:

```text
field_side.lua
```

e agora é usada por:

```text
live_attack.lua
live_defense.lua
gk_distribution.lua
defense.lua
```

O antigo `0x056E` permanece apenas como endereço legado/documental e não participa mais das decisões de ataque/defesa.
