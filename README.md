# ISSD_bot — Radar v0.6.0

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

## Calibração individual v0.6.0

Esta versão permite manter os quatro cantos magenta e destacar **uma entidade** (bola ou jogador) sem apagar seu monitoramento CSV completo.

```lua
local TARGET_TEAM, TARGET_NUMBER = "ball", 0 -- bola
-- local TARGET_TEAM, TARGET_NUMBER = "my", 1  -- goleiro meu
-- local TARGET_TEAM, TARGET_NUMBER = "cpu", 11
local FOCUS_ONLY = true
local SHOW_TARGET_CROSS = true
local REFERENCE_X, REFERENCE_Y = nil, nil
```

- `FOCUS_ONLY=true`: exibe apenas a entidade selecionada mais os quatro cantos magenta; **o CSV continua contendo os 22 jogadores e a bola**.
- A mira branca de quatro pixels em torno da entidade indica a posição que o Lua **calculou**; ela não identifica o ponto nativo automaticamente.
- Para medir o erro, pause um frame em que você consiga identificar inequivocamente o ponto nativo do alvo, anote suas coordenadas **em pixels lógicos do BizHawk** e informe `REFERENCE_X` e `REFERENCE_Y`. Reinicie o script no **mesmo frame/savestate**, evitando comparar posições de instantes distintos.
- Na linha do alvo (`is_target=1`), o CSV traz `pixel_x/y`, `reference_x/y`, `error_x/y` e `error_distance` em pixels. Erro = projeção − referência e distância = raiz quadrada da soma dos erros quadráticos. Sem referência, os campos de erro ficam vazios.
- As referências definidas são estáticas; **não representam rastreamento do ponto nativo**. Só interprete o erro para o frame ao qual a medição manual pertence. As linhas de frames posteriores com a mesma referência são apenas hipóteses e não constituem erros válidos sem nova anotação.
- `REFERENCE_X/Y` devem ser ambos números ou ambos `nil`. Os limites do retângulo continuam configurados em `FX, FY, FW, FH`.
- Se desejar sobrepor todos novamente, defina `FOCUS_ONLY=false`. `SHOW_OVERLAY=false` desliga toda a visualização, mas continua exportando CSV.

**Ainda não há calibração automática** nem validação em execução real no BizHawk.
