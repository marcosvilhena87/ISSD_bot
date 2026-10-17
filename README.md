# ISSD_bot — Radar v0.8.0

Radar somente leitura para **International Superstar Soccer Deluxe (SNES)** no BizHawk/Lua.

## Novidade: calibração por estádio (Stadium_ID 0–7)

A WRAM `0x0086` (i16) contém `Stadium_ID`. O script lê esse valor a cada frame e escolhe os limites observados **somente para o estádio correspondente**. Não transfere os limites para os demais estádios.

| Estádio | Dimensões observadas na WRAM | Escanteios: min_x | max_x | min_y | max_y | Situação |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 0 | 1792 × 576 | 4 | 1788 | 4 | 572 | Observado; ainda não validado contra pixels nativos |
| 1 | 1856 × 640 | 4 | 1852 | 4 | 636 | Observado; ainda não validado contra pixels nativos |
| 2 | 1984 × 704 | 4 | 1980 | 4 | 700 | Observado; ainda não validado contra pixels nativos |
| 3 | 2048 × 640 | 4 | 2044 | 4 | 636 | Observado; ainda não validado contra pixels nativos |
| 4 | 1920 × 640 | 4 | 1916 | 4 | 636 | Observado; ainda não validado contra pixels nativos |
| 5 | 1920 × 576 | 4 | 1916 | 4 | 572 | Observado; ainda não validado contra pixels nativos |
| 6 | 1792 × 704 | 4 | 1788 | 4 | 700 | Observado; ainda não validado contra pixels nativos |
| 7 | 1856 × 640 | 4 | 1852 | 4 | 636 | Observado; ainda não validado contra pixels nativos |

Esses limites representam **posições repetidas da bola em quatro escanteios**, não limites comprovados de todos os objetos do campo. Jogadores ou bola fora desses limites permanecem no CSV mesmo quando não são desenhados.

## Configuração principal

```lua
local USE_EMPIRICAL_BOUNDS = true
local STADIUM_CALIBRATION = {
    [0] = {min_x=4, max_x=1788, min_y=4, max_y=572, validated=false},
    [1] = {min_x=4, max_x=1852, min_y=4, max_y=636, validated=false},
    [2] = {min_x=4, max_x=1980, min_y=4, max_y=700, validated=false},
    [3] = {min_x=4, max_x=2044, min_y=4, max_y=636, validated=false},
    [4] = {min_x=4, max_x=1916, min_y=4, max_y=636, validated=false},
    [5] = {min_x=4, max_x=1916, min_y=4, max_y=572, validated=false},
    [6] = {min_x=4, max_x=1788, min_y=4, max_y=700, validated=false},
    [7] = {min_x=4, max_x=1852, min_y=4, max_y=636, validated=false},
}
```

- `USE_EMPIRICAL_BOUNDS=true`: usa modelo empírico quando existe e as dimensões da WRAM são válidas.
- `USE_EMPIRICAL_BOUNDS=false`: usa sempre a normalização original baseada em `field_length` e `field_width`.
- Sem perfil para o `Stadium_ID`, o modo volta automaticamente a `field_dimensions`; nunca copia os limites de outro estádio.
- `validated=false` indica que faltam correspondências **medidas no mesmo frame** com o radar nativo. A mudança de modelo não comprova melhora visual.
- `ORIGIN_X/Y` e `SCALE_X/Y` afetam somente a projeção original; no modelo empírico a origem é `min_x/y` e a escala é derivada de `max-min`. `INVERT_X/Y` e `OFFSET_X/Y` continuam aplicados aos dois modelos.
- Os quatro cantos magenta e o modo de destaque da v0.7.0 são preservados.

## Colunas adicionais no CSV

O arquivo `issd_radar_calibration.csv` mantém as colunas anteriores e acrescenta:

- `projection_model`: `empirical` ou `field_dimensions`, indicando o modelo efetivamente exibido;
- `raw_norm_x/y`, `raw_pixel_x/y`: projeção original;
- `empirical_norm_x/y`, `empirical_pixel_x/y`: projeção pelos limites dos escanteios, quando disponível;
- `delta_pixel_x/y`: **empírico menos original**, em pixels lógicos (não é erro contra o radar nativo);
- `empirical_min_x/max_x/min_y/max_y` e `empirical_validated`: parâmetros e estado do perfil aplicado ao estádio.

As colunas antigas `norm_x/y`, `pixel_x/y` e `inside_bounds` continuam descrevendo o **modelo ativo**. `error_x/y/distance` continuam exigindo referências manuais sincronizadas (tabela `REFERENCES`); não confundir delta entre modelos com erro real.

## Instruções

1. Abra partida no BizHawk e execute `lua/radar.lua` via **Tools → Lua Console**.
2. Confira as quatro cruzes magenta sobre os cantos do radar nativo. O retângulo inicial continua `FX=88, FY=161, FW=79, FH=54` em pixels lógicos.
3. Para comparar as projeções, capture o mesmo savestate com `USE_EMPIRICAL_BOUNDS=true` e depois `false`.
4. Analise `issd_radar_calibration.csv` em ambos os testes. Salve uma cópia antes de reiniciar: o CSV é sobrescrito.
5. Se tiver posições nativas anotadas por frame, informe-as em `REFERENCES` como descrito no código; apenas essas linhas permitem calcular `MATCHED`.

## WRAM (i16 little-endian nas posições)

- Bola: X `0x042A`, Y `0x042C`.
- Meu time: X `0x052A + i*0x100`, Y = X+2, para i=0…10.
- CPU: X `0x102A + i*0x100`, Y = X+2, para i=0…10.
- Estádio: `0x0086` (i16).
- Comprimento/largura: `0x12A2` / `0x12A4` (u16).

Não altera a memória nem envia inputs. O código foi publicado, mas ainda requer execução no BizHawk para validar esta versão.
