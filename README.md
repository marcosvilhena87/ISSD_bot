# ISSD_bot — Radar v0.11.0

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
-- "empirical" (padrao), "geometric", "field_dimensions"
local PROJECTION_MODEL = "empirical"
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

- `PROJECTION_MODEL="empirical"`: usa o perfil individual do `Stadium_ID` (com fallback para `field_dimensions` quando ausente ou inválido).
- `PROJECTION_MODEL="geometric"`: calcula dinamicamente os limites `min_x=4`, `max_x=field_length-4`, `min_y=4`, `max_y=field_width-4`, quando as dimensões são maiores que 8.
- `PROJECTION_MODEL="field_dimensions"`: mantém a normalização original por `field_length` e `field_width`.
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
3. Para comparar as projeções, capture o mesmo savestate com `PROJECTION_MODEL="empirical"`, `"geometric"` e `"field_dimensions"`.
4. Analise `issd_radar_calibration.csv` em ambos os testes. Salve uma cópia antes de reiniciar: o CSV é sobrescrito.
5. Se tiver posições nativas anotadas por frame, informe-as em `REFERENCES` como descrito no código; apenas essas linhas permitem calcular `MATCHED`.

## WRAM (i16 little-endian nas posições)

- Bola: X `0x042A`, Y `0x042C`.
- Meu time: X `0x052A + i*0x100`, Y = X+2, para i=0…10.
- CPU: X `0x102A + i*0x100`, Y = X+2, para i=0…10.
- Estádio: `0x0086` (i16).
- Comprimento/largura: `0x12A2` / `0x12A4` (u16).

Não altera a memória nem envia inputs. O código foi publicado, mas ainda requer execução no BizHawk para validar esta versão.

## Comparação dos três modelos — v0.10.0

| Modelo | Dados utilizados | Histórico de validação |
| --- | --- | --- |
| `field_dimensions` | WRAM `0x12A2` e `0x12A4`; `ORIGIN_X/Y`, `SCALE_X/Y` | Independente dos perfis |
| `empirical` | `STADIUM_CALIBRATION[Stadium_ID]` | Cada perfil mantém `validated=false` até aferição nativa |
| `geometric` | Regra dinâmica `(4, L-4, 4, W-4)` | Hipótese derivada de escanteios, não validação nativa |

A regra geométrica produz os mesmos **limites min/max** que os oito perfis atuais; isso não significa que o modelo reproduza com exatidão as posições nativas. Também não reproduz a assimetria da posição da bola nos cantos superiores (X=4 ou L-8) e inferiores (X=8 ou L-4); os limites são extremos globais observados.

As colunas anteriores do CSV são preservadas. A v0.10.0 acrescenta `geometric_norm_x/y`, `geometric_pixel_x/y`, `geometric_min_x/max_x/min_y/max_y` e `geometric_minus_empirical_pixel_x/y`. Essas diferenças **não** são erros contra o radar nativo.

### Teste de regressão

Execute na raiz do repositório:

```bash
python -m unittest discover -s tests -v
```

O teste `tests/test_stadium_geometry.py` lê os oito perfis reais do Lua, verifica presença, `validated=false` e igualdade dos limites com a fórmula para as dimensões medidas. Não testa a execução no BizHawk, a correspondência visual no radar nativo ou a exatidão dos pixels do jogo.

**Atenção:** se `Stadium_ID` e dimensões WRAM forem inconsistentes durante transições de partida, os modelos `empirical` e `geometric` podem divergir. Essa diferença é informativa; não marca nenhum perfil como validado automaticamente.

## Integridade geométrica — v0.10.0

O radar agora confere **em todo frame** se `Stadium_ID` (WRAM 0x0086) e as dimensões `field_length`/`field_width` são coerentes com o perfil individual cadastrado. As dimensões esperadas são recuperadas dos perfis: `expected_field_length = max_x - min_x + 8` e `expected_field_width = max_y - min_y + 8`.

| geometry_status | Condição | Renderizar entidades? |
| --- | --- | --- |
| `VALID` | Estádio conhecido e ambas dimensões correspondem exatamente | Sim |
| `ZERO_DIMENSIONS` | Uma ou ambas dimensões zeradas | Não |
| `DIMENSION_MISMATCH` | Estádio conhecido, mas dimensões não correspondem ao perfil | Não |
| `UNKNOWN_STADIUM` | Estádio sem perfil cadastrado | Não |

Política **fail-closed**: o script não projeta nenhum dos três modelos durante estados inválidos, mesmo que haja um perfil empírico salvo. Os quatro marcadores magenta de enquadramento, independentes da geometria de jogo, continuam visíveis. As leituras WRAM (posição e dimensões) permanecem integralmente no CSV; os campos de coordenadas projetadas ficam vazios e `projection_model="blocked"`.

As quatro novas colunas são: `geometry_status`, `geometry_valid` (1/0), `expected_field_length` e `expected_field_width`. Nos frames inválidos, `calibration_status` registra o motivo e **não calcula erro** nem atribui `MATCHED`, mesmo com referência manual anotada.

### Testes

```bash
python -m unittest discover -s tests -v
```

Os testes estáticos verificam oito perfis, dimensões esperadas e presença dos bloqueios no código-fonte. Não substituem um teste dinâmico de execução no BizHawk, que continua pendente.

**Compatibilidade:** as colunas antigas permanecem na mesma ordem e as quatro colunas novas são acrescentadas no final. Em estados suspeitos o radar não reutiliza dimensões do frame anterior nem tenta adivinhar o estádio.

## Contexto de partida — v0.11.0

O radar lê agora `Game_State` em `0x00BA` (u16 LE) e `Gameplay_Active` em `0x0006` (u8) a cada frame. Os rótulos do primeiro campo são derivados de `tools/bizhawk/issd/state/game_state.lua` do [ISSD_bot.v0](https://github.com/marcosvilhena87/ISSD_bot.v0/blob/main/tools/bizhawk/issd/state/game_state.lua).

| Game_State | game_state_kind | Interpretação do projeto anterior |
| --- | --- | --- |
| 0 | `LIVE` | Jogo corrido |
| 1 | `ENDLINE_RESTART` | Escanteio/tiro de meta |
| 2 | `THROW_IN` | Lateral |
| 3 | `FOUL_RESTART_SEQUENCE` | Sequência de falta |
| 4 | `OFFSIDE_SEQUENCE` | Sequência de impedimento |
| 5 | `POST_GOAL` | Após gol |
| 6 | `PERIOD_TIME_UP` | Fim de período |
| Outros | `UNKNOWN` | Não mapeado |

A combinação observada **`Game_State=6` e comprimento ou largura igual a zero** recebe `geometry_status=PERIOD_ENDED`; dimensões zeradas em outros estados recebem `ZERO_DIMENSIONS_UNEXPECTED`. `DIMENSION_MISMATCH`, `UNKNOWN_STADIUM` e `VALID` continuam disponíveis. **Todos os estados geométricos diferentes de `VALID` bloqueiam o desenho e as coordenadas projetadas.** O critério geométrico permanece independente de `Gameplay_Active`: este campo é registrado para análise, sem supor que todo replay ou pausa implica dimensões inválidas.

Três novas colunas foram adicionadas **ao final** do CSV, sem reorganizar as existentes: `game_state`, `game_state_kind` e `gameplay_active`. Assim, a classificação por estádio pode ser analisada por contexto, inclusive transições e final de período. A identificação de `PERIOD_TIME_UP` vem do código anterior; a correlação com dimensões zeradas foi observada experimentalmente, mas o comportamento de todos os estados ainda requer novas capturas.

Execute os testes estáticos com `python -m unittest discover -s tests -v` e valide a leitura dinâmica no BizHawk com um CSV que inclua passagem de tempo encerrado para uma nova partida/período. A versão segue somente leitura, sem automatizar inputs.
