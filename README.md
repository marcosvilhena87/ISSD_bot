# ISSD_bot — Radar v0.5.0

Radar de calibração em **Lua / BizHawk** para International Superstar Soccer Deluxe (SNES). Somente leitura: nenhum botão é pressionado e nenhuma posição de memória é alterada.

## O que há nesta versão

- 22 jogadores: **ciano** (meu time) e **vermelho** (CPU); bola **amarela**.
- **Quatro cruzes magenta nos cantos do retângulo**, sem fundo ou bordas, para alinhar o quadro ao radar nativo.
- `FX, FY, FW, FH` controlam somente a posição e dimensões de referência do retângulo.
- `OFFSET_X/Y` deslocam **apenas jogadores e bola**, não os cantos de referência.
- `ORIGIN_X/Y`, `SCALE_X/Y` e `INVERT_X/Y` controlam a normalização, ainda não calibrada empiricamente.
- `SHOW_NUMBERS` identifica o índice mapeado de cada jogador para diagnóstico; desativado por padrão.
- CSV inclui coordenadas WRAM, coordenadas normalizadas, pixels projetados e parâmetros de calibração. Entidades fora do retângulo são **registradas**, mas não desenhadas.

## Usar

1. Abra uma partida no BizHawk e execute `lua/radar.lua` no **Tools → Lua Console**.
2. **Etapa 1 (quadro):** alinhe as cruzes magenta aos 4 cantos do radar nativo, ajustando `FX, FY, FW, FH`. As cruzes são desenhadas no perímetro e podem ultrapassar um pixel.
3. **Etapa 2 (pontos):** compare bola e jogadores com o radar original. Se o desvio for uniforme, tente `OFFSET_X/Y`; se crescer com a distância, ajuste escala; se estiver espelhado, teste `INVERT_X/Y`. Use `ORIGIN_X/Y` caso a origem da WRAM não corresponda à origem do radar.
4. Reinicie o script após cada ajuste e compare novas capturas. Habilite `SHOW_NUMBERS` apenas para investigar correspondências.
5. Examine `issd_radar_calibration.csv`, salvo no diretório de trabalho do BizHawk. Cada amostra tem **23 linhas**, coletadas a cada 10 frames. Uma nova execução sobrescreve o arquivo.

Configuração padrão (pixels lógicos do BizHawk):

```lua
local FX, FY, FW, FH = 88, 161, 79, 54
local SHOW_CORNERS = true
local ORIGIN_X, ORIGIN_Y = 0, 0
local SCALE_X, SCALE_Y = 1, 1
local INVERT_X, INVERT_Y = false, false
local OFFSET_X, OFFSET_Y = 0, 0
local SHOW_ENTITIES = true
local SHOW_NUMBERS = false
local SHOW_BALL = true
local SHOW_OVERLAY = true
```

### Endereços WRAM

Todas as coordenadas X/Y são **i16 little-endian** (Y em X+2). Bola: `0x042A`; meu time: `0x052A+i*0x100`; CPU: `0x102A+i*0x100`, com i=0…10. `Stadium_ID` em `0x0086` (i16); `field_length` em `0x12A2`, `field_width` em `0x12A4` (u16).

### Atenção

As dimensões da WRAM não comprovam, por si só, os limites da coordenada. **As quatro cruzes validam apenas o retângulo visual**; não confirmam a transformação espacial. Para medir erro real em pixels, é necessário obter posições correspondentes do radar nativo em várias capturas. Ainda não há detecção automática de alvos ou ajuste automático.
