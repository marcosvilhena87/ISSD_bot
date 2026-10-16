# ISSD_bot — Radar v0.3.0

Projeto iniciado do zero para International Superstar Soccer Deluxe (SNES), usando BizHawk e Lua.

## Radar somente leitura

A versão v0.3.0 lê **22 atletas e a bola**, renderiza marcadores em campo esquemático e gera `issd_radar_entities.csv` (uma linha por entidade a cada 10 frames). Não envia inputs nem altera a WRAM.

### Estrutura encontrada na WRAM

Todas as coordenadas X/Y são **inteiros de 16 bits com sinal, little-endian**:

| Entidade | X | Y | Regra |
| --- | --- | --- | --- |
| Bola | `0x042A` | `0x042C` | fixo |
| Meu time: goleiro/No.1 | `0x052A` | `0x052C` | primeiro |
| Meu time: No.2–11 | `0x062A`–`0x0F2A` | `0x062C`–`0x0F2C` | `0x052A + i*0x100` (i=0…10) |
| CPU: goleiro/No.1 | `0x102A` | `0x102C` | primeiro |
| CPU: No.2–11 | `0x112A`–`0x1A2A` | `0x112C`–`0x1A2C` | `0x102A + i*0x100` (i=0…10) |

Outros campos: `0x0086` Stadium_ID (i16), `0x12A2` comprimento (u16), `0x12A4` largura (u16).

## Executar

1. Abra a ROM e entre numa partida pelo BizHawk.
2. Em **Tools → Lua Console**, execute `lua/radar.lua`.
3. Confira a representação do campo: **ciano** = meu time, **vermelho** = CPU, **amarelo** = bola.
4. Confira `issd_radar_entities.csv` na pasta de trabalho configurada pelo emulador.

## Limitações conhecidas

- A origem das coordenadas e sua relação com as dimensões da WRAM ainda **não foram calibradas**. `ORIGIN_X/Y=0` e `SCALE_X/Y=1` são hipóteses; entidades podem ficar fora do retângulo até a calibração.
- A atribuição dos índices aos números dos atletas foi fornecida pelo mapeamento da memória, mas deve ser conferida durante partidas.
- O arquivo CSV é reescrito a cada execução, para não misturar sessões. Para preservar uma sessão, copie/renomeie o CSV antes de iniciar outra.
- O radar é sobreposição de observação, não inteligência do bot.

## Próximo teste

Capturar lances com bola no centro, cantos e laterais em diferentes estádios. Verificar a relação entre `raw_x/y`, `field_length/width` e `inside_bounds`, ajustando origem e escala quando necessário.

## Mini-radar v0.3.0

O overlay agora ocupa apenas **104 × 60 pixels lógicos**, em `FX=8, FY=36` (antes 220 × 120). Para alterar o posicionamento, edite `FX, FY, FW, FH` no começo de `lua/radar.lua`. Dependendo da resolução/configuração do BizHawk, talvez seja necessário ajustar esses valores.

Defina `SHOW_OVERLAY = false` para gravar as mesmas 23 entidades no CSV **sem desenhar nada sobre a partida**. A calibração da origem e da escala continua provisória. A v0.3.0 ainda não exibe números dos jogadores nem calcula proximidade com a bola.
