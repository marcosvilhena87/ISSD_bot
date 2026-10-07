# RAM Map

Documento de trabalho para registrar endereços de memória descobertos no ISS Deluxe.

> Regra: endereço vindo de arquivo `.wch` é tratado como **candidato forte**, não como confirmado, até ser validado em execução na ROM-alvo documentada em `TARGET_ROM.md`.

## Status

- 🔴 não localizado
- 🟡 candidato forte / fonte WCH
- 🟢 validado em execução

## Variáveis prioritárias

| Variável | Endereço WRAM | Tipo WCH | Status | Fonte / observações |
|---|---:|---|---|---|
| Gameplay Active | `0x0006` | byte unsigned | 🟢 | `1` = gameplay ativo; `0` = pause/replay; usado como guarda global do bot |
| Ball X | `0x042A` | word signed | 🟢 | validado em execução |
| Ball Y | `0x042C` | word signed | 🟢 | validado em execução |
| My Controlled Player | `0x1ACC` | word unsigned | 🟢 | base da struct do jogador controlado |
| CPU Controlled Player | `0x1AFC` | word unsigned | 🟢 | base da struct do jogador controlado pela CPU |
| My Controlled Player X (camera) | `0x1AA8` | word signed | 🟡 | `ISSD_players_cam.wch` |
| My Controlled Player Y (camera) | `0x1AAC` | word signed | 🟡 | `ISSD_players_cam.wch` |
| CPU Controlled Player X (camera) | `0x1AD8` | word signed | 🟡 | `ISSD_players_cam.wch` |
| CPU Controlled Player Y (camera) | `0x1ADC` | word signed | 🟡 | `ISSD_players_cam.wch` |
| Player Ball Possession | `0x00A6` | word unsigned | 🟢 | `0x0000` = sem jogador fisicamente ligado; caso contrário base da struct do possuidor |
| Team Possession | `0x104C` | byte unsigned | 🟢* | em jogo corrido: `0=MY`, `1=CPU`; validado também durante passes longos; bola neutra/restarts ainda em caracterização |
| Game State | `0x00BA` | word unsigned | 🟢 | `0` live; `1` endline; `2` lateral; `3` falta; `4` impedimento; `5` pós-gol |
| My Side (legacy) | `0x056E` | byte unsigned | 🔴 | instável; assume valores como `0x80/0x81/0x88/0x89` conforme estado do jogador, inclusive posse do GK; não usar para orientação |
| CPU Side | `0x106E` | byte unsigned | 🟢 | fonte operacional validada; permaneceu em `0/1`, inverteu na troca de lados e não apresentou frames inválidos no watcher |
| Score For | `0x0DA2` | word unsigned | 🟡 | My_Goal(s), fonte fornecida pelo usuário; aguarda validação em execução |
| Score Against | `0x0EA2` | word unsigned | 🟡 | CPU_Goal(s), fonte fornecida pelo usuário; aguarda validação em execução |
| Match Time | — | — | 🔴 | ainda não localizado |

## Side / orientação do campo

A fonte operacional passou a ser `WRAM 0x106E (CPU_Side)`.

Validação focal observada:

```text
CPU_Side = 1 -> derived My_Side = 0
CPU_Side = 0 -> derived My_Side = 1

derived My_Side = 1 - CPU_Side
```

No watcher dedicado, `0x106E` permaneceu estritamente em `0/1`, com `Invalid CPU_Side frames=0`, e inverteu de valor na troca de lados.

O antigo `0x056E` foi rebaixado: ele varia com estado interno do jogador e assumiu valores como `0x80/0x81/0x88/0x89`, inclusive durante posse do goleiro. Portanto não deve ser usado diretamente para orientação.

O eixo X de mundo cresce da esquerda para a direita:

- `derived My_Side = 0`: defendemos a esquerda e atacamos para a direita;
- `derived My_Side = 1`: defendemos a direita e atacamos para a esquerda.

A implementação centraliza essa lógica em `field_side.lua`.

## Game_State — estados da partida

Validado em execução em `WRAM 0x00BA`:

```text
0 = LIVE
1 = ENDLINE_RESTART
    corner ou goal kick; não distingue os dois
2 = THROW_IN
3 = FOUL_RESTART_SEQUENCE
    falta comum, cartão, free kick e penalty kick
4 = OFFSIDE_SEQUENCE
    impedimento / free kick após impedimento
5 = POST_GOAL
```

Observações importantes:

```text
GS=3 pode continuar durante cartão e preparação de cobrança.
GS=4 aparece na sequência de impedimento.
GS=5 aparece na sequência pós-gol, inclusive gol contra.
GS=0 pode reaparecer durante algumas fases de cobrança.
```

Por isso `Game_State` tem prioridade sobre `PlayerPoss` ao classificar a fase do jogo. O bot usa automação ativa em `0/1/2` e trata `3/4/5` conservadoramente sem movimento até a transição para outro estado.

## Team Possession / posse lógica por equipe

`WRAM 0x104C` (u8) foi validado em jogo corrido como indicador do lado da posse/jogada:

```text
0 = MY
1 = CPU
```

A validação incluiu condução e passe longo dos dois times, inclusive quando `0x00A6 = 0x0000`. O comportamento em bola verdadeiramente neutra, reposições e replay ainda está sendo caracterizado; por isso a tabela usa 🟢*.

Hipótese de trabalho: existe uma flag separada de `Player Ball Possession (0x00A6)` que mantém o time responsável pela jogada mesmo quando a bola está em trânsito.

Foi adicionado:

```text
tools/bizhawk/issd/probes/team_possession_probe.lua
```

O probe procura endereços `u8` e `u16 little-endian` que satisfaçam:

```text
MY_CONTROLLED == MY_PASS
CPU_CONTROLLED == CPU_PASS
MY_* != CPU_*
```

Classes de captura:

```text
Y = MY_CONTROLLED
U = MY_PASS
I = CPU_CONTROLLED
O = CPU_PASS
C = imprimir candidatos
R = reset
```

Para reduzir falsos positivos, o ideal é capturar pelo menos 3 amostras por classe, usando jogadores, zonas do campo e passes diferentes.

Após múltiplas amostras, `0x104C` sobreviveu com o padrão:

```text
MY_CONTROLLED  = 0
MY_PASS        = 0
CPU_CONTROLLED = 1
CPU_PASS       = 1
```

Foi adicionado um probe focal:

```text
tools/bizhawk/issd/probes/team_possession_watch.lua
```

Ele mostra em tempo real:

```text
0x104C
0x00A6 Player Possession
0x00BA Game_State
Ball X/Y
MyCtrl / CPUCtrl
My_Side / CPU_Side
```

e registra no console toda transição de `0x104C` com o contexto do frame.

Observado em execução:

```text
MY conduz       -> 0x104C = 0
MY passe longo  -> 0x104C = 0, mesmo com 0x00A6 = 0
CPU conduz      -> 0x104C = 1
CPU passe longo -> 0x104C = 1, mesmo com 0x00A6 = 0
```

O bot agora usa `0x104C` como fonte primária para o lado da posse quando nenhum jogador está fisicamente ligado à bola; a heurística temporal ficou somente como fallback para valores fora de `0/1`.

## Possession

Validado em `WRAM 0x00A6`:

```text
0x0000 = bola livre / sem possuidor

0x0500..0x0F00 = jogador do meu time
0x1000..0x1A00 = jogador da CPU
```

Quando um jogador possui a bola, o valor coincide com a base da estrutura desse jogador.

Exemplos observados:

```text
0x0D00 = Beranco
0x0E00 = Gomez
0x0F00 = Allejo
```

## Bola — coordenadas de mundo

`ISSD_players.wch` fornece diretamente:

- `WRAM 0x042A` = `Ball_x`
- `WRAM 0x042C` = `Ball_y`

Ambos estão salvos no Watch como **word signed**.

### Bola — coordenadas relativas à câmera

`ISSD_players_cam.wch` fornece:

- `WRAM 0x1FFA6` = `Ball_x (cam)`
- `WRAM 0x1FFA8` = `Ball_y (cam)`
- anotação da fonte: `center = 128`

Esses endereços são especialmente úteis para validar a relação entre posição de mundo, câmera e posição na tela.

## Estrutura dos jogadores — coordenadas de mundo

Os dados sugerem uma estrutura extremamente regular, com **stride de `0x100` bytes por jogador**.

### Meu time

| Jogador | X | Y |
|---|---:|---:|
| GK | `0x052A` | `0x052C` |
| No.2 | `0x062A` | `0x062C` |
| No.3 | `0x072A` | `0x072C` |
| No.4 | `0x082A` | `0x082C` |
| No.5 | `0x092A` | `0x092C` |
| No.6 | `0x0A2A` | `0x0A2C` |
| No.7 | `0x0B2A` | `0x0B2C` |
| No.8 | `0x0C2A` | `0x0C2C` |
| No.9 | `0x0D2A` | `0x0D2C` |
| No.10 | `0x0E2A` | `0x0E2C` |
| No.11 | `0x0F2A` | `0x0F2C` |

### CPU

| Jogador | X | Y |
|---|---:|---:|
| GK | `0x102A` | `0x102C` |
| No.2 | `0x112A` | `0x112C` |
| No.3 | `0x122A` | `0x122C` |
| No.4 | `0x132A` | `0x132C` |
| No.5 | `0x142A` | `0x142C` |
| No.6 | `0x152A` | `0x152C` |
| No.7 | `0x162A` | `0x162C` |
| No.8 | `0x172A` | `0x172C` |
| No.9 | `0x182A` | `0x182C` |
| No.10 | `0x192A` | `0x192C` |
| No.11 | `0x1A2A` | `0x1A2C` |

A fórmula candidata é:

```text
my_player[n].x = 0x052A + n * 0x100
my_player[n].y = 0x052C + n * 0x100

cpu_player[n].x = 0x102A + n * 0x100
cpu_player[n].y = 0x102C + n * 0x100
```

onde `n = 0..10`.

## Estrutura dos jogadores — coordenadas relativas à câmera

`ISSD_players_cam.wch` mostra o mesmo padrão de `0x100` bytes:

```text
my_player[n].cam_x = 0x0508 + n * 0x100
my_player[n].cam_y = 0x050C + n * 0x100

cpu_player[n].cam_x = 0x1008 + n * 0x100
cpu_player[n].cam_y = 0x100C + n * 0x100
```

Todos aparecem como **word signed**.

## Campo / estádio

Fonte: `ISSD_field.wch`.

| Variável | Endereço | Tipo |
|---|---:|---|
| Stadium ID | `0x0086` | word signed |
| Field length (X) | `0x12A2` | word unsigned |
| Field width (Y) | `0x12A4` | word unsigned |
| Center field (X) | `0x12F2` | word unsigned |
| Center field (Y) | `0x12D8` | word unsigned |

A fonte anota que comprimento, largura e centro variam conforme `stadium_id` (0 a 7).

## Arquivo `ball.wch`

Esse arquivo contém **84 endereços word unsigned sem rótulos**. Ele parece ser um conjunto de candidatos produzido durante uma busca de memória.

Importante: ele **não contém** `0x042A` nem `0x042C`, os endereços rotulados como `Ball_x/Ball_y` em `ISSD_players.wch`.

Portanto, por enquanto ele deve ser preservado como material histórico de busca, não como fonte principal para as coordenadas da bola.

Há duas interseções com `flags.wch`:

- `0x056E` — `My_Side`
- `0x106E` — `CPU_Side`

## Protocolo de validação

Para cada endereço candidato:

1. registrar valor e posição visual;
2. alterar apenas a variável que queremos testar;
3. observar correlação;
4. repetir em várias posições;
5. reiniciar a partida;
6. trocar de equipe/lado quando aplicável;
7. confirmar estabilidade;
8. verificar sinal, endianess, escala e offsets;
9. comparar coordenada de mundo × coordenada de câmera quando disponível.

## Primeiro teste recomendado

Validar simultaneamente:

```text
0x042A  Ball X (world)
0x042C  Ball Y (world)
0x1FFA6 Ball X (camera)
0x1FFA8 Ball Y (camera)
```

Mover a bola para esquerda/centro/direita e cima/centro/baixo deve permitir confirmar monotonicidade e descobrir a transformação entre mundo e tela.

## Critério para marcar como confirmado 🟢

Um endereço só deve virar 🟢 quando:

- acompanha a variável em múltiplos cenários;
- não apresenta falsos positivos óbvios;
- permanece válido após reiniciar a partida;
- tipo/sinal estiverem corretos;
- sua transformação para coordenada de campo ou tela estiver entendida.


## Replay / gameplay ativo

Problema observado em execução: durante a tela `RESUME REPLAY`, `Game_State (0x00BA)` continua em `0`, portanto ele não distingue gameplay real de replay.

Foi adicionado:

```text
tools/bizhawk/issd/probes/replay_probe.lua
```

O probe compara duas classes:

```text
N = LIVE normal
V = REPLAY
B = PAUSED
C = imprimir Top 30 candidatos
R = reset
```

Critério: o endereço deve permanecer estável dentro de várias amostras LIVE, estável dentro de várias amostras REPLAY e ter valores diferentes entre as duas classes.

O ranking prioriza flags simples, especialmente `0/1`, `0/255` e pequenos valores em regiões globais da WRAM.

Recomendação: capturar pelo menos 5 amostras LIVE, 5 REPLAY e 5 PAUSED em momentos variados antes de imprimir candidatos. A terceira classe ajuda a separar uma flag específica de replay de uma flag genérica de "jogo não ativo".


### Gameplay Active candidate

`WRAM 0x0006` (u8) foi validado em execução como guarda de gameplay:

```text
LIVE   = 1
REPLAY = 0
PAUSED = 0
```

Semântica validada:

```text
1 = gameplay ativo
0 = gameplay não ativo
```

Foi adicionado:

```text
tools/bizhawk/issd/probes/gameplay_active_watch.lua
```

O watcher mostra `0x0006`, `Game_State`, `TeamPoss`, `PlayerPoss`, bola, controles e lados, e registra somente transições de `0x0006`.

Validação desejada:

```text
jogo normal        -> 1
pause              -> 0
retorno do pause   -> 1
replay             -> 0
retorno do replay  -> 1
```

A integração foi feita no bot principal como guarda global:

```text
0x0006 != 1 -> BOT_IDLE + release de input + reset de estado temporário
0x0006 == 1 -> máquina normal
```

Ainda vale caracterizar estados adicionais como gol/comemoração, intervalo e fim de partida, mas pause e replay já foram validados.
