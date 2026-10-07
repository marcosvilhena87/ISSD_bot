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
| Ball X | `0x042A` | word signed | 🟡 | `ISSD_players.wch` |
| Ball Y | `0x042C` | word signed | 🟡 | `ISSD_players.wch` |
| My Controlled Player | `0x1ACC` | word unsigned | 🟡 | `flags.wch`; semântica/ID ainda precisa ser confirmada |
| CPU Controlled Player | `0x1AFC` | word unsigned | 🟡 | `flags.wch` |
| My Controlled Player X (camera) | `0x1AA8` | word signed | 🟡 | `ISSD_players_cam.wch` |
| My Controlled Player Y (camera) | `0x1AAC` | word signed | 🟡 | `ISSD_players_cam.wch` |
| CPU Controlled Player X (camera) | `0x1AD8` | word signed | 🟡 | `ISSD_players_cam.wch` |
| CPU Controlled Player Y (camera) | `0x1ADC` | word signed | 🟡 | `ISSD_players_cam.wch` |
| Player Ball Possession | `0x00A6` | word unsigned | 🟡 | `flags.wch`; valores ainda não decodificados |
| Game State | `0x00BA` | word unsigned | 🟡 | `flags.wch`; enum ainda não decodificado |
| My Side | `0x056E` | byte unsigned | 🟡 | `flags.wch` |
| CPU Side | `0x106E` | byte unsigned | 🟡 | `flags.wch` |
| Score For | — | — | 🔴 | ainda não localizado |
| Score Against | — | — | 🔴 | ainda não localizado |
| Match Time | — | — | 🔴 | ainda não localizado |

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
