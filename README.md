# ISSD_bot

Bot experimental para **International Superstar Soccer Deluxe (SNES)**, executado no **BizHawk**, com leitura de RAM, controle via Lua e decisões táticas baseadas em regras.

**Estado atual:** a leitura de memória e os planejadores de **tiki-taka** e **gegenpressing** estão implementados. O `main.lua` coordena as decisões, mas a emissão automática de comandos de jogo pelo controle Lua ainda não está integrada nem validada no BizHawk. O radar permanece um módulo somente leitura.

## Radar v0.15.7

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
| 7 | 2176 × 704 | 4 | 2172 | 4 | 700 | Observado; ainda não validado contra pixels nativos |

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
    [7] = {min_x=4, max_x=2172, min_y=4, max_y=700, validated=false},
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

## Rastreador de transições geométricas — v0.12.0

O `lua/radar.lua` agora produz **dois CSVs independentes**:

- `issd_radar_calibration.csv`: amostragem das 23 entidades (22 jogadores + bola), preservando as colunas e o intervalo `SAMPLE_EVERY` da v0.11.0.
- `issd_radar_geometry_transitions.csv`: **um evento por frame em que qualquer um dos quatro campos mudar**, mesmo entre frames não amostrados pelo CSV de calibração.

O segundo arquivo registra `frame`, `event`, `changed_fields`, valores anteriores e atuais de `stadium_id`, `game_state`, `field_length`, `field_width`, mais `geometry_status`, `game_state_kind` e `gameplay_active` anteriores e atuais para contextualizar a mudança. Campos múltiplos em `changed_fields` são separados por ponto e vírgula, sem alterar o delimitador CSV (vírgula).

| event | Quando ocorre |
| --- | --- |
| `INITIAL` | Primeira observação da sessão; não representa uma mudança real |
| `CHANGE` | Um ou mais dos quatro campos diferem do frame observado anteriormente |
| `TIMELINE_RESET` | `frame <= previous_frame` (ex.: rewind/load state); os campos anteriores são preservados somente para diagnóstico |

O rastreador atualiza sua observação anterior **a cada frame**, mesmo quando não há eventos, portanto não acumula duplicações em períodos estáveis. Uma única linha representa mudanças simultâneas dos quatro campos. O arquivo é descarregado (`flush`) a cada evento para facilitar captura de sessões interrompidas.

A saída não adivinha as causas das transições: uma divergência de dimensão pode ocorrer tanto em fases de jogo quanto em transições e é contextualizada, não automaticamente corrigida. O bloqueio das projeções inválidas da v0.11.0 continua ativo e os oito perfis individuais permanecem preservados com `validated=false`.

**Como testar:** execute `python -m unittest discover -s tests -v` e, no BizHawk, capture uma sessão com mudanças de estádio, gol e fim de período. Envie os dois CSVs: a análise pode cruzar os `frame` do rastreador com a telemetria do radar. Os testes adicionados verificam o contrato no código-fonte; a execução real ainda precisa ser validada no BizHawk.

## Classificação de transições — v0.13.0

A v0.13.0 adiciona uma **classificação diagnóstica separada de `geometry_status`**, sem alterar os limites dos oito perfis individuais, seus `validated=false` nem a política de bloqueio das projeções.

- `STADIUM_CHANGE_PENDING`: `Stadium_ID` acabou de mudar, as dimensões ainda correspondem **exatamente ao perfil do estádio anterior** e não ao atual. A classificação dura até que as dimensões mudem, a geometria se normalize ou sejam ultrapassados `PENDING_MAX_FRAMES=1200` frames.
- `PERSISTENT_DIMENSION_MISMATCH`: incompatibilidade geométrica sem transição pendente, persistente por pelo menos `PERSISTENT_LIVE_FRAMES=120` frames consecutivos de `Game_State=0` (LIVE). Esse critério é operacional e não prova erro permanente de mapeamento.
- Outras observações repetem `geometry_status`, inclusive `VALID`, `PERIOD_ENDED`, `ZERO_DIMENSIONS_UNEXPECTED`, `UNKNOWN_STADIUM` e `DIMENSION_MISMATCH`.

O contador da incompatibilidade persistente reinicia ao sair do estado LIVE, quando a geometria é válida ou quando muda o estádio. Rewind/carregamento de savestate detectado pelo retrocesso do contador de frames também reinicia a classificação temporal. Uma nova sessão iniciada já com dimensões incorretas **não é considerada pendente** sem evidência do estádio anterior; nesses casos, o diagnóstico persistente depende de observação em LIVE.

As novas colunas `transition_status`, `transition_age_frames`, `pending_from_stadium` e `pending_to_stadium` são acrescentadas ao fim de **ambos os CSVs**. No arquivo `issd_radar_geometry_transitions.csv` existe ainda `previous_transition_status`. O rastreador registra um evento `CLASSIFICATION_CHANGE` quando a classificação muda mesmo que nenhuma das quatro variáveis rastreadas mude no mesmo frame. Eventos normais `INITIAL`, `CHANGE` e `TIMELINE_RESET` permanecem.

**Segurança:** somente `geometry_status=VALID` libera projeções no radar. `STADIUM_CHANGE_PENDING` e `PERSISTENT_DIMENSION_MISMATCH` continuam bloqueados, com coordenadas brutas preservadas no CSV. Nenhum perfil é reajustado automaticamente.

Os limites temporais iniciais (1200/120 frames) são hipóteses de diagnóstico ajustáveis mediante novas coletas, e não parâmetros comprovados do jogo. O teste estático cobre o contrato; a execução e a precisão espacial no BizHawk ainda precisam ser verificadas.

## Descoberta conservadora de variantes geométricas — v0.14.0

A versão acrescenta um terceiro relatório: `issd_radar_geometry_variants.csv`. Uma combinação (`stadium_id`, `field_length`, `field_width`) divergente do perfil original é reportada como **candidata**, não como uma nova calibração válida, quando:

1. O estádio tem perfil individual cadastrado;
2. `Game_State=0` (`LIVE`);
3. `geometry_status=DIMENSION_MISMATCH`;
4. A classificação não é `STADIUM_CHANGE_PENDING`;
5. A mesma combinação persiste em **120 frames consecutivos**.

O script mantém o exemplo observado `STADIUM_VARIANT_CANDIDATES[7] = {{length=2176, width=704, validated=false}}`. A lista serve só para indicar candidatos conhecidos; dimensões diferentes também podem ser descobertas. O novo CSV registra `stadium_id`, `field_length`, `field_width`, `first_frame`, `confirmed_frame`, `consecutive_live_frames`, `predefined_candidate`, `validated=0` e `status=OBSERVED_UNVALIDATED`.

Uma linha é emitida ao completar o limiar de estabilidade de uma sequência contínua. Se essa sequência for interrompida e depois voltar, pode haver outra linha para a mesma variante — útil para investigar sessões distintas. Rewind ou load state que retrocede o contador de frames reinicia o contador de estabilidade.

**Importante:** nenhuma variante descoberta modifica `STADIUM_CALIBRATION` ou ativa projeções. A política `geometry_status=VALID` permanece como única condição para desenhar entidades. A dimensão observada, por si só, não comprova escanteios nem correspondência com o radar nativo. Para validar o candidato 2176 × 704 do Stadium_ID 7, é necessário coletar novamente os quatro escanteios nessa configuração e medir referências visuais sincronizadas.

O radar continua produzindo `issd_radar_calibration.csv` e `issd_radar_geometry_transitions.csv`, sem alterar seus formatos. Executar testes estáticos: `python -m unittest discover -s tests -v`. Testes reais de execução no BizHawk permanecem necessários.

## Calibração multivariante — v0.15.0

Os oito perfis originais em `STADIUM_CALIBRATION` foram mantidos. A tabela separada `STADIUM_VARIANT_PROFILES` permite manter múltiplas configurações por `Stadium_ID`, identificadas pela combinação de dimensões. A variante observada para o estádio 7 é:

```lua
[7] = {
    {id="7_1856x640", length=1856, width=640,
     min_x=4, max_x=1852, min_y=4, max_y=636,
     geometry_observed=true, projection_validated=false}
}
```

`geometry_observed=true` significa que as dimensões e quatro cantos foram observados. **Não implica** `projection_validated=true`, que exige medições sincronizadas em pixels do radar nativo. Também não altera o `validated=false` do perfil original.

Quando o `Stadium_ID` e as dimensões coincidem com uma variante, a v0.15.0 calcula projeções **experimentais** de bola e jogadores, porém sem desenhá-las no radar e sem preenchê-las nas colunas antigas de projeção ativa, caso `geometry_status` não seja `VALID`. O CSV principal ganhou as colunas finais `variant_id`, `variant_geometry_observed`, `variant_projection_validated`, `variant_pixel_x`, `variant_pixel_y`, `variant_norm_x`, `variant_norm_y`. Assim é possível comparar numericamente a hipótese multivariante com referências manuais antes de autorizá-la visualmente.

O arquivo de descoberta de variantes `issd_radar_geometry_variants.csv` continua registrando ocorrências estáveis em `LIVE`; não promove perfis automaticamente. O rastreamento de transições e a política de bloqueio `geometry_status=VALID` permanecem preservados.

### Validação necessária

Execute `python -m unittest discover -s tests -v` e teste a v0.15.0 no BizHawk. Os testes Python são verificações estruturais; a precisão das projeções variantes depende de referências em pixels nativos sincronizadas com os frames. Não marque `projection_validated=true` apenas por observar quatro escanteios.

## Marcas magenta somente quando o campo estiver carregado — v0.15.2

As quatro cruzes de enquadramento são desenhadas quando `SHOW_OVERLAY=true`, `SHOW_CORNERS=true` e os dados de campo da WRAM estão carregados. A configuração padrão é `AUTO_HIDE_CORNERS=true`.

São lidos quatro valores u16 little-endian por frame:

| Endereço | Campo |
| --- | --- |
| `0x12A2` | `field_length` |
| `0x12A4` | `field_width` |
| `0x12F2` | `center_field (x)` |
| `0x12D8` | `center_field (y)` |

A condição para o desenho é comprimento e largura maiores que 8, centro X estritamente entre 0 e comprimento, e centro Y estritamente entre 0 e largura. Isso evita cruzes em telas com dimensões zeradas ou centro inconsistente.

**A pausa não oculta as cruzes:** o desenho delas não depende mais de `Game_State`, `Gameplay_Active` ou `geometry_status=VALID`. Portanto, variantes ainda não validadas, como o Stadium_ID 7 com dimensões 2176 × 704, continuam aptas a mostrar as cruzes quando os quatro valores estão carregados. O bloqueio das projeções das entidades em geometria inválida permanece inalterado.

O CSV principal mantém `corners_visible` e `corner_visibility_mode`; este último recebe o valor `field_loaded`. Definir `AUTO_HIDE_CORNERS=false` restaura o desenho incondicional das cruzes (desde que `SHOW_OVERLAY` e `SHOW_CORNERS` estejam ativos).

**Limitação:** dimensões e centro carregados não são uma prova de que o radar nativo esteja sendo renderizado: em algumas telas o jogo pode manter esses valores na WRAM. O comportamento solicitado deve ser confirmado no BizHawk, inclusive em pausa, menu e replay.

## Cruzes com geometria reconhecida — v0.15.3

As cruzes magenta exigem `field_loaded` (comprimento, largura e centro coerentes) **e** geometria reconhecida: `geometry_status=VALID` para o perfil original **ou** uma entrada de `STADIUM_VARIANT_PROFILES` correspondente às dimensões e com `geometry_observed=true`. A regra é independente de `Game_State` e `Gameplay_Active`: pausa não as oculta se a geometria permanecer carregada e reconhecida.

A variante 2176 × 704 do estádio 7 pode exibir as cruzes, mas **não libera projeções dos jogadores**: para isso continua exigido `geometry_status=VALID`. A coluna `corner_visibility_mode` do CSV passa a valer `known_geometry`.

Essa heurística **não identifica diretamente** a renderização nativa: menus podem preservar na WRAM uma geometria reconhecida, inclusive centro coerente. Nessa situação, as cruzes ainda podem aparecer; seria necessária uma flag de tela/radar para distinguir com garantia. `AUTO_HIDE_CORNERS=false` desativa a condição automática.

## PRE_MATCH_COIN_TOSS — Stadium_ID 8 (v0.15.4)

A captura fornecida identifica `Stadium_ID=8` como a tela pré-partida de **cara ou coroa**, com escolha de bola ou lado, e não como um nono estádio. O radar classifica esse valor como `geometry_status=PRE_MATCH_COIN_TOSS` **antes** de examinar dimensões zeradas ou o perfil de estádio.

Nesse estado as quatro cruzes magenta são ocultadas mesmo se `AUTO_HIDE_CORNERS=false`; projeções de jogadores e bola permanecem bloqueadas (`projection_model=blocked`). As coordenadas brutas e o estado são preservados nos CSVs para auditoria. `STADIUM_CALIBRATION` continua abrangendo somente os estádios 0–7, sem alteração dos seus limites ou indicadores `validated=false`.

## Revisão do perfil principal do Stadium_ID 7

O perfil principal do estádio 7 agora corresponde a **2176 × 704**, com `min_x=4`, `max_x=2172`, `min_y=4`, `max_y=700`, ainda `validated=false`. A configuração **1856 × 640** previamente observada foi preservada como variante histórica `7_1856x640`, com `geometry_observed=true` e `projection_validated=false`; não é utilizada automaticamente para liberar o desenho das entidades. Os demais sete perfis não foram alterados. As seções anteriores sobre a variante 2176 × 704 documentam a evolução histórica do projeto e devem ser lidas à luz desta revisão.

## Cores configuráveis — v0.15.5

As cores das entidades do overlay foram invertidas para aumentar a distinção visual: **meu time em vermelho**, **CPU em ciano** e **bola em amarelo**. Altere na configuração inicial de `lua/radar.lua`:

```lua
local MY_COLOR, CPU_COLOR, BALL_COLOR = "red", "cyan", "yellow"
```

Essas opções afetam somente o desenho do overlay; não modificam a WRAM, os perfis geométricos, os cálculos de projeção nem as colunas CSV.

## Exibição dos jogadores — v0.15.6

O padrão `FOCUS_ONLY=false` permite desenhar simultaneamente os 11 marcadores do time `my` (vermelho), 11 da CPU (ciano) e a bola (amarelo), desde que estejam dentro do radar e com geometria válida. Antes, `FOCUS_ONLY=true` com `TARGET_TEAM="ball"` ocultava todos os jogadores, mesmo com as cores configuradas. `FOCUS_ONLY=true` ainda pode ser usado manualmente para calibrar apenas o alvo selecionado. O CSV continua registrando todas as entidades.

## Overlay oculto com sete leituras WRAM zeradas — v0.15.7

Quando **todas** as seis leituras abaixo são simultaneamente zero, nenhum marcador é desenhado (cruzes magenta, jogadores, bola ou mira), inclusive com `AUTO_HIDE_CORNERS=false`: `Ball_x` (0x042A), `Ball_y` (0x042C), `field_length` (0x12A2), `field_width` (0x12A4), `center_field_x` (0x12F2) e `center_field_y` (0x12D8). O `Stadium_ID` (0x0086) continua sendo lido para a calibração, mas não participa da condição de ocultação. Quando esses seis valores estão zerados, `gui.clearGraphics()` remove também os desenhos Lua remanescentes da tela. Essa chamada limpa a superfície gráfica Lua compartilhada, podendo afetar outros overlays; execute apenas uma instância do radar no Lua Console. Para visualizar a mudança, recarregue o script e avance pelo menos um frame; não é possível atualizar o overlay com o emulador totalmente pausado. Os relatórios continuam sendo coletados. A regra é de **todos zerados**, não de algum endereço isolado zerado; ela não garante ocultação em menus que mantenham valores residuais.


## Gegenpressing experimental (planejador tatico)

O modulo `lua/gegenpressing.lua` implementa uma maquina de estados **sem escrever controles** no BizHawk. A versao atual de `lua/radar.lua` continua somente leitura; nenhuma integracao automatica com joypad ou detector de posse foi presumida.

Interface:

```lua
local Gegenpressing = require("gegenpressing")
local plan = Gegenpressing.new({window=90, radius=260, max_pressers=2})
local decision = plan.update({
    frame=1234, active=true, possession="cpu",
    ball={x=800,y=320},
    own_goal={x=0,y=320},
    my_players={{id=1,x=830,y=320},{id=2,x=760,y=350}}
})
-- decision.mode: INACTIVE, NORMAL, GEGENPRESS, RECOVER_SHAPE
-- decision.pressers: {id, role, target_x, target_y, distance}
```

O integrador precisa alimentar **a cada frame** `possession` confirmado ("my", "cpu" ou "loose"), coordenadas das entidades e `active=true` apenas em jogo válido. Os identificadores de jogador devem ser estaveis. A perda `my -> cpu/loose` inicia uma janela de pressao; o mais proximo vai na bola e o segundo fecha a linha para `own_goal`. Goleiros marcados `is_goalkeeper=true` sao excluidos. Fora do raio, na expiracao da janela ou em estado desconhecido, nao gera alvo de pressao. Reset de timeline e estado invalido impedem falsas transicoes.

**Nao ha comando de movimento nem de desarme** neste modulo. O controlador do bot deve traduzir as decisoes para a API do BizHawk somente apos validar selecao de jogadores, posse e direcao do campo. Os offsets existentes no radar informam coordenadas, mas **nao comprovam posse de bola**.

Testes Lua (requer interpretador Lua instalado): `lua tests/test_gegenpressing.lua`. Estes testes nao foram executados no BizHawk.


## Tiki-taka experimental — circulação e passes curtos

O planejador puro `lua/tiki_taka.lua` complementa `lua/gegenpressing.lua` sem alterar `lua/radar.lua`. Ele **não aciona botões**: classifica linhas de passe e indica receptores. O controlador externo deve fornecer posse de bola **validada**, jogador portador, coordenadas das equipes, gols e estado de jogo.

```lua
local TikiTaka = require("tiki_taka") -- package.path deve incluir lua/
local planner = TikiTaka.new()
local decision = planner.update({
  frame=1200, active=true, possession="my", carrier_id=1,
  ball={x=500,y=300},
  own_goal={x=0,y=300}, opponent_goal={x=1800,y=300},
  my_players={{id=1,x=500,y=300},{id=2,x=610,y=320},{id=3,x=540,y=410}},
  cpu_players={{id=8,x=560,y=300}}
})
-- decision.mode: PASS, HOLD ou INACTIVE
-- decision.target_id: receptor recomendado apenas no modo PASS
-- decision.candidates: passes seguros ordenados por pontuacao
-- decision.support: jogadores proximos para apoio
-- APENAS quando o controlador realmente iniciar o passe:
-- planner.confirm_pass(decision.target_id, 1200)
```

A linha de passe é testada pela menor distância dos adversários ao **segmento** entre portador e receptor. A pontuação combina liberdade do corredor, progressão em direção ao gol e penalidade por distância. Há uma penalização contra passes repetidos para o mesmo receptor e intervalo mínimo entre passes confirmados. A orientação ofensiva é determinada pela direção entre `own_goal` e `opponent_goal`, sem presumir que a equipe ataque sempre pela direita. Fora da posse, em reinício, sem portador válido ou com telemetria incompleta, o módulo não recomenda passes.

**Limitações:** ainda não existe calibração empírica de tempos, controles B/Y, interceptações dinâmicas, triangulações coordenadas nem execução autônoma integrada ao BizHawk. A métrica geométrica de segurança é uma heurística, não garantia de passe bem-sucedido. Para executar testes Lua localmente: `lua tests/test_tiki_taka.lua`. O teste Lua não foi executado neste ambiente.


## Main.lua — coordenador de tiki-taka + gegenpressing

O arquivo raiz `main.lua` carrega `lua/tiki_taka.lua` e `lua/gegenpressing.lua` e pode ser executado no BizHawk via **Tools → Lua Console → Open Script** a partir da raiz do repositório (diretório de trabalho contendo `lua/`). Carregue somente uma instância para evitar múltiplos loops. O coordenador **não envia botões** e não altera o radar.

- `TIKI_TAKA`: nossa posse, passe recomendado; `KEEP_POSSESSION`: nossa posse, sem passe recomendado.
- `GEGENPRESS`: perda da posse detectada pelo módulo de pressão; `RECOVER_SHAPE`: janela encerrada/sem jogadores próximos; `DEFEND`: defesa sem pressão ativa.
- `INACTIVE`: estado inválido ou ausente, sem decisão tática.
- Recuperar a posse cancela a pressão; perda da posse zera o planejador ofensivo.

### Fonte de estado obrigatória

O radar existente fornece coordenadas brutas, mas **não identifica posse nem portador com confiabilidade**. Sem um fornecedor de estados validado, o `main.lua` funciona em modo `INACTIVE` (seguro) e não tenta deduzir a posse por mera proximidade com a bola.

Para integrar um detector validado, defina a função global `ISSD_STATE_PROVIDER(frame)` **antes de carregar o script**. Ela deve retornar a cada frame uma tabela:

```lua
{
  frame=frame, active=true, possession="my", carrier_id=1,
  ball={x=500,y=300},
  own_goal={x=0,y=300}, opponent_goal={x=1800,y=300},
  my_players={{id=1,x=500,y=300},{id=2,x=600,y=330}},
  cpu_players={{id=1,x=700,y=300}}
}
```

`active=true` exige gameplay vivo e válido; `possession` deve ser `"my"`, `"cpu"` ou `"loose"`. Não forneça `carrier_id` estimado como confirmado. Coordenadas e lados do campo devem estar sincronizados e calibrados. `ISSD_TACTICAL_OBSERVER(decision,state)` é um callback **opcional apenas para receber decisões**; não confirma execução de passes. O coordenador não aciona automaticamente `confirm_pass`: o integrador só deve chamá-lo depois de confirmar o início efetivo do passe.

Testes: `lua tests/test_main.lua`, `lua tests/test_tiki_taka.lua` e `lua tests/test_gegenpressing.lua`. Requer interpretador Lua; os testes não foram executados neste ambiente nem no BizHawk.


## Posse WRAM integrada ao main.lua

`lua/possession.lua` agora fornece snapshots de leitura direta do BizHawk, sem alterar a memória ou emitir comandos. `main.lua` utiliza `Possession.bizhawk()` automaticamente quando nenhum `ISSD_STATE_PROVIDER` externo foi definido.

Leituras: `0x1ACC` (u16, jogador controlado MY), `0x1AFC` (u16, jogador controlado CPU), `0x00A6` (u16, base do possuidor físico) e `0x104C` (u8, equipe lógica). Também lê gameplay `0x0006`, estado `0x00BA`, bola `0x042A/0x042C`, campo `0x12A2/0x12A4` e 22 jogadores por structs de bases `0x0500..0x0F00` e `0x1000..0x1A00` com stride `0x100`, offsets X/Y `0x2A/0x2C`. As posições dos dois goleiros são usadas como referências direcionais, de forma conservadora.

**Prioridade de evidência:** `0x00A6` com base válida identifica o time e o portador; conflito com `0x104C` é registrado em `logical_conflict`, mas a posse individual prevalece. `0x00A6=0` indica passe/chute em trânsito **ou** bola solta. `0x104C=0/1` identifica apenas a equipe lógica, e esse caso retorna `active=false`, `ownership_source=LOGICAL_UNVERIFIED`, sem disparar gegenpressing ou tiki-taka. Estados não-live e geometria/goleiros ambíguos também bloqueiam decisões. Portanto um passe longo em voo não aciona uma falsa perda de bola. Isso é mais conservador que o planejamento de passes com a posse lógica contínua; retomada exige confirmação física.

O interpretador Lua do BizHawk não foi executado neste ambiente. Teste estático previsto: `lua tests/test_possession.lua` e `lua tests/test_main.lua`. A execução **ainda não controla o videogame**: trata-se de recomendação tática baseada em WRAM, sem `joypad.set`. Os endereços e a distinção entre posse individual e posse lógica seguem o [mapa de RAM do ISSD_bot.v0](https://github.com/marcosvilhena87/ISSD_bot.v0/blob/main/docs/RAM_MAP.md).


## Correcao de inicializacao do main.lua

O `main.lua` agora localiza `lua/tiki_taka.lua`, `lua/gegenpressing.lua` e `lua/possession.lua` **relativamente ao proprio arquivo**, mesmo quando o diretorio de trabalho do BizHawk e diferente da raiz do repositorio. Falhas de leitura WRAM sao registradas no Lua Console uma vez por mensagem distinta, sem encerrar o loop; o estado correspondente fica `INACTIVE`. Confirme que `main.lua` e a pasta `lua/` estao no mesmo projeto e atualize com `git pull --ff-only origin main`. Se continuar sem executar, copie o erro integral do Lua Console. Mudanca ainda nao validada dentro do BizHawk.


## Telemetria de decisoes (issd_tactical_report.csv)

O `main.lua` gera automaticamente `issd_tactical_report.csv` no diretorio de trabalho do BizHawk. O arquivo e sobrescrito a cada nova execucao do script: salve uma copia antes de reiniciar se quiser preservar uma captura anterior. O registro ocorre a **cada frame**, inclusive `INACTIVE`, e e descarregado para disco a cada 60 frames ou imediatamente quando muda o estado tatico.

Colunas: `frame,epoch,mode,phase,possession,logical_team,raw_owner,raw_team,ownership_source,logical_conflict,carrier_id,my_controlled_id,cpu_controlled_id,target_id,pressers,reason,decision_reason,elapsed,ball_x,ball_y`. Campos nao conhecidos permanecem vazios. `pressers` usa formato `id:ROLE;id:ROLE`; `target_id` e apenas uma recomendacao, nao prova de passe executado. `epoch` aumenta sempre que o contador de frames retrocede (savestate/reset); permite separar trechos da mesma sessao. `raw_owner` corresponde a WRAM `0x00A6`, `raw_team` a `0x104C`. `logical_team` nao e posse confirmada: `0x00A6=0` ainda pode significar passe em voo ou bola solta.

Testes locais: `lua tests/test_tactical_telemetry.lua` (interpretador Lua requerido). O teste no BizHawk ainda precisa ser realizado; o script nao executa comandos `joypad`. Caso o CSV nao possa ser criado, o console apresenta `[ISSD] ERRO CSV` e o planejador permanece executando.


## Tiki-taka assistido pelo radar (experimental)

O `main.lua` agora usa `lua/tactical_radar.lua` para projetar recomendações de passe na mesma área usada pelo radar original (`FX=88, FY=161, FW=79, FH=54`). **Execute apenas `main.lua`** para esse modo; `radar.lua` continua sendo uma ferramenta de calibração independente e rodar os dois ao mesmo tempo pode sobrepor desenhos.

Legenda: jogador MY em vermelho, CPU em ciano, bola amarela, portador com contorno branco, melhor linha de passe verde e até duas alternativas cinza; número ao lado do receptor. As linhas são **sugestões**, não comandos enviados ao controle. Os passes continuam limitados pela checagem de distância e de corredor livre existente no `tiki_taka.lua`.

A projeção usa os perfis empíricos dos oito estádios cadastrados em `radar.lua`, sem modificar a calibração. Desenho tático bloqueado quando `Stadium_ID` é desconhecido, dimensões divergem, não há portador confirmado ou posse é incerta. Perfis observados não constituem prova de alinhamento visual com o radar nativo: valide os marcadores no BizHawk. O `main.lua` continua produzindo `issd_tactical_report.csv`, e o controle automático de passes permanece desativado.

Teste de lógica isolada: `lua tests/test_tactical_radar.lua` (a execução local requer Lua; a validação visual exige BizHawk).


## Diagnostico de passes tiki-taka (radar assistido)

`lua/tiki_taka.lua` agora avalia todos os jogadores de linha elegiveis (nao somente os aprovados) e fornece `decision.diagnostics.evaluations` com `id`, `distance`, `clearance`, `progression`, `score` e `reason`. As rejeicoes sao classificadas como `TOO_CLOSE`, `TOO_FAR` ou `BLOCKED`; `SAFE` representa passe que passou pelas regras atuais. Limites existentes permanecem inalterados.

O `issd_tactical_report.csv` conserva suas 20 colunas originais e acrescenta: `pass_safe`, `pass_too_close`, `pass_too_far`, `pass_blocked`, `best_rejected_id`, `best_rejected_reason`, `best_rejected_clearance`, `support_move_id`, `support_move_x`, `support_move_y`. Campos vazios indicam ausencia de avaliacao. `best_rejected` representa o candidato rejeitado com maior pontuacao, e nao um passe autorizado.

O radar passa a mostrar **linha laranja** para o candidato rejeitado com melhor pontuacao e **marcador magenta** para uma posicao hipotetica de apoio, quando uma mudanca lateral melhora a distancia minima aos adversarios e respeita o alcance maximo de passe. O movimento e apenas uma hipotese geometrica; **nenhum jogador e movimentado**. As marcacoes continuam ocultas quando a geometria ou a posse confirmada nao permitem projeção.

Teste local: `lua tests/test_tiki_taka_diagnostics.lua`. Ainda requer validacao real no BizHawk. O CSV e sobrescrito ao reiniciar o script.


## Identificacao da versao nos logs

A partir do bot **v1.12.0**, o console Lua mostra `versao=1.12.0 | telemetria_schema=2 | colunas=32` ao carregar `main.lua`. O arquivo `issd_tactical_report.csv` tem duas novas colunas finais, `bot_version` e `schema_version`, em todas as linhas. A versao e o esquema identificam a estrutura logica e o formato do relatorio, nao necessariamente o SHA do commit do GitHub. O esquema 2 tem 32 colunas; capturas com 20 ou 30 colunas foram geradas por revisoes anteriores. Feche o script antigo no BizHawk e abra novamente o `main.lua` apos `git pull --ff-only origin main` para confirmar a versao exibida.


### v1.12.1 — arquivo CSV junto ao script

Para evitar capturar um CSV antigo no diretorio de trabalho do BizHawk, `main.lua` agora grava `issd_tactical_report.csv` **na mesma pasta do proprio `main.lua`** quando o caminho do script puder ser identificado. O console exibe `arquivo principal:` e `caminho CSV:` antes de iniciar o relatorio, bem como a versao **1.12.1**, esquema **2**, **32 colunas**. Se o caminho nao puder ser identificado, usa o diretorio de trabalho como alternativa. A cada nova inicializacao o CSV no destino e sobrescrito. Para confirmar a versao, encerre a instancia antiga no Lua Console, rode `git pull --ff-only origin main`, abra novamente o script e procure `[ISSD] caminho CSV:`.


## Tiki-taka sequencial v1.13.0 (um jogador controlavel por vez)

A v1.13.0 integra `lua/sequential_tiki_taka.lua` ao `main.lua`. O planejamento nao tenta controlar companheiros simultaneamente: examina passes curtos disponiveis, sugere uma conducao do portador em **oito direcoes** quando nao ha passe seguro, e simula uma possivel segunda ligacao (`triangle`). Todos os alvos sao indicacoes, **sem `joypad.set`**.

Estados previstos: `PASS_READY` (exposto no coordenador como `TIKI_TAKA`), `DRIBBLE`, `HOLD`, `WAIT_RECEIVE` e `REPLAN`. Para iniciar `WAIT_RECEIVE`, um controlador futuro deve chamar `confirm_pass(target_id, frame)` **somente apos verificar que um passe real comecou**. Sem emissao de comandos, a confirmacao nao ocorre automaticamente e esses estados nao necessariamente aparecerao no log. A recepcao e confirmada apenas pela identificacao de posse fisica do novo jogador; ao receber, o plano e recalculado. Quando a posse e incerta, permanece o bloqueio conservador.

O radar desenha em amarelo o trecho de conducao sugerido, em verde os passes aprovados e em laranja a melhor rejeicao. A telemetria passou ao **schema 3 com 39 colunas**, preservando os campos anteriores e acrescentando `action`, `dribble_x`, `dribble_y`, `open_passes`, `triangle_via`, `triangle_next` e `triangle_score`. O posicionamento e geometricamente hipotetico: executar um deslocamento real exige calibrar velocidade, comando direcional, selecao do jogador e validacao de seguranca no BizHawk.

Teste isolado: `lua tests/test_sequential_tiki_taka.lua`. Os testes foram adicionados, mas a execucao no BizHawk ainda precisa ser validada.


## Tiki-taka v1.13.1: progressão com apoio lateral ou recuo

Com posse confirmada, `tiki_taka.lua` avalia passes de todas as direções pelo eixo dos gols: `PROGRESSIVE` (avança), `LATERAL` (apoio) e `BACKWARD` (recuo). Só entram na seleção passes aprovados pelos limites existentes de distância e corredor livre. Um passe progressivo válido tem preferência; um lateral ou recuo pode prevalecer quando apresentar corredor pelo menos `safety_override_margin=45` unidades mais livre que o melhor progressivo. Sem passe aprovado, o planejador sequencial considera `DRIBBLE`.

A v1.13.1 atualiza o CSV para **schema 4, 43 colunas**, acrescentando `pass_type`, `pass_score`, `pass_clearance` e `pass_progression`. O modo continua somente leitura, sem comandos `joypad`. Teste de regressão: `lua tests/test_pass_priority.lua`. A preferência de passe é uma hipótese de planejamento e exige validação visual no BizHawk.


## v1.13.2 — Diagnóstico dos companheiros próximos

O algoritmo de tiki-taka agora guarda os **três jogadores de linha mais próximos do portador**, mesmo quando seus passes são rejeitados. Para cada um, registra `id`, distância a partir do portador (`carrier_distance`), distância a partir da bola (`ball_distance`), motivo `SAFE/TOO_CLOSE/TOO_FAR/BLOCKED` e identificação do adversário cuja posição está mais próxima do segmento de passe. O cálculo do bloqueador é geométrico e **não prova que ele interceptaria a bola**.

O radar marca os três companheiros próximos com um pequeno contorno branco e destaca em laranja o bloqueador do melhor candidato rejeitado. A calibração do radar continua experimental. Os critérios de aceitação do passe e a prioridade progressiva/lateral/recuo **não foram alterados**.

O CSV v1.13.2 utiliza o **esquema 5, com 58 colunas**: acrescenta `near1_id`, `near1_carrier_distance`, `near1_ball_distance`, `near1_reason`, `near1_blocker_id` e equivalentes para `near2` e `near3`. Os diagnósticos ficam vazios quando não há posse confirmada ou avaliação disponível. Teste: `lua tests/test_nearest_passes.lua`. A execução real no BizHawk ainda precisa ser validada.


## Correção visual: limpeza das sugestões após perda da posse

O `main.lua` executa `gui.clearGraphics()` quando disponível antes de desenhar os indicadores de cada frame, inclusive quando a posse é da CPU ou não há dono confirmado. Assim, linhas de passes e sugestões anteriores não ficam presas na tela. As marcações táticas só são redesenhadas com `active=true`, `possession=my`, `ownership_source=PLAYER_BALL_POSSESSION` e `carrier_id` validado. Atenção: `gui.clearGraphics()` pode limpar desenhos de outros scripts Lua que compartilhem a mesma camada gráfica; recomenda-se executar o `main.lua` isoladamente. A telemetria permanece independente.


## Marcador de condução no radar

O marcador magenta de `support_move` não é mais desenhado no radar tático. Quando o planejador sequencial recomenda `DRIBBLE`, o radar mostra **linha amarela** do portador até o destino e **quadrado amarelo com a letra `D`** sobre o ponto de chegada. Fora do estado com sugestão de condução, o marcador `D` não aparece. As informações de `support_move` permanecem disponíveis na telemetria CSV para análise, sem comandar jogadores.
