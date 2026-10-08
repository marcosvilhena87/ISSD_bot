# Relatorio automatico do ISSD Bot

Ao abrir `tools/bizhawk/issd/main.lua` pelo Lua Console do BizHawk, o script tenta criar ou acrescentar registros em:

`tools/bizhawk/issd/issd_report.csv`

O CSV e gravado imediatamente (flush) e pode ser aberto no Excel. Cada nova execucao substitui o relatorio anterior para manter somente um arquivo com o formato atual.

## Eventos
- `SESSION_START`: inicializacao do script.
- `BOT_ON` / `BOT_OFF`: alternancia pela tecla K.
- `SETTING_CHANGE`: alternancia da configuracao pela tecla L.
- `STATE_CHANGE`: alteracao no estado tatico do bot (sem gravar cada frame).
- `HEARTBEAT`: amostra de estado a cada 300 frames do emulador, quando ligado.

## Colunas

`timestamp,session,frame,event,enabled,status,game_state,gameplay_active,player_possession,team_possession,controlled_player,ball_dx,ball_dy,ball_speed,action,detail`

Os numeros de jogadores e possuidores sao as bases da WRAM. `ball_dx` e `ball_dy` indicam deslocamento estimado da bola entre observacoes, nao posicao absoluta.

O painel visual permanece ativo. Para analisar o arquivo com seguranca no Excel, prefira fechar/parar o script antes de importar. Se o BizHawk nao permitir gravar no diretorio, o console mostrara `CSV indisponivel`; o bot continuara funcionando sem telemetria.

A gravacao exige que o ambiente Lua do BizHawk disponibilize `io.open`. O CSV nao armazena dados de pixels ou todas as amostras de RAM; e uma trilha compacta de diagnostico.

O relatorio e criado somente quando o script e executado localmente no BizHawk. A alteracao no GitHub por si so nao gera um relatorio de partida.

## Relatorio v2: contexto da decisao

A versao atual escreve exclusivamente em `tools/bizhawk/issd/issd_report.csv`, substituindo seu conteudo ao iniciar o script. Acrescenta `ball_x/y`, `player_x/y`, `target_x/y`, `target_distance`, `controller_command`, `attack_mode`, `lane_direction`, `blocker_base/forward/lateral`, `up/down_clearance`, `restart_taker`, `restart_taker_team`, `mark_target` e `team_possession_source`.

O comando representa as teclas enviadas pelo modulo Movement no frame amostrado, ou NONE. Em estados sem alvo definido as coordenadas de destino ficam vazias. As justificativas em `detail` sao classificacoes da regra aplicada, nao provas de que a jogada foi correta. O sistema continua registrando transicoes e heartbeats, nao todos os frames. Nenhum destes registros muda a politica do bot.

## Lateral ofensivo experimental

Em `Game_State=2` com cobrador MY, a politica `tactics/throw_in.lua` busca um receptor proximo e privilegia espaco livre, progressao e distancia. O script so tenta cobrar quando `MyCtrl == restart.taker`, evitando apertar B enquanto outro jogador e controlado. Em caso contrario apresenta `THROW_IN_WAIT_TAKER_CONTROL`.

Estados adicionais: `THROW_IN_WAIT_SIDE`, `THROW_IN_WAIT_RECEIVER`, `THROW_IN_WAIT_CLEARANCE`, `THROW_IN_READY`. As mudancas registram em `detail` cobrador, receptor, direcao, folga e score. Tentativas adicionais sao registradas como `THROW_ATTEMPT`. O mesmo arquivo `issd_report.csv` continua sendo usado.

**Importante:** a associacao do botao B e o criterio do cobrador sao hipoteses operacionais; verificar na ROM alvo em execucao. O script nao troca automaticamente para o cobrador. Se `MyCtrl` divergir do cobrador, nao envia o comando. Ajustes de distancia, clearance e intervalo de tentativa ficam em `core/config.lua`.

## Posicionamento de receptor em lateral (experimental)

Durante GS=2 com cobranca MY, o ponteiro MyCtrl pode referir-se a um receptor em campo, mesmo com Allejo como cobrador. Se o receptor estiver distante do cobrador, o bot tenta aproximar o jogador controlado com os direcionais. Quando outro companheiro esta substancialmente mais proximo, solicita uma troca com R (respeitando cooldown). O resultado efetivo de R depende do jogo e precisa ser observado no BizHawk.

Estados: `THROW_IN_SWITCH_RECEIVER`, `THROW_IN_MOVE_RECEIVER`, `THROW_IN_RECEIVER_POSITIONED`. Uma vez posicionado, o bot nao envia B automaticamente enquanto o controle real da cobranca nao estiver validado. O CSV unico `issd_report.csv` registra transicoes, comandos e distancia do candidato. Validar a tecla R em savestate antes de confiar na troca automatica.

## Controles confirmados para lateral

Durante GS=2, o jogador controlado (MyCtrl) recebe direcionais e R; o cobrador identificado (restart.taker) responde aos botoes B (curto) e A (longo), independentemente de MyCtrl coincidir com o cobrador. A rotina agora tenta B ao posicionar o receptor, registra a tentativa no CSV e limita a duas tentativas por cobrador/reinicio. Se nao houver candidato receptor, apos 180 frames tenta A como fallback experimental. Validar o resultado na ROM-alvo.

## Diagnostico de gol (historico circular)

Um buffer de 600 frames (~10 s a 60 FPS) amostra estado a cada 3 frames. Ao entrar em `Game_State=5`, o CSV unico `issd_report.csv` recebe `POST_GOAL_CANDIDATE` e as amostras `PRE_GOAL_TRACE` com o numero original do frame e `trigger_frame` em detail. O historico inclui bola, jogador controlado, estado tatico, alvo e comando de controle (quando o bot esta ligado). Quando estiver desligado, posicoes e comandos taticos nao sao disponiveis.

**Atenção:** `GS=5` significa sequencia pos-gol, mas o mapa atual nao revela qual equipe marcou; portanto `scoring_team=UNKNOWN` ate que enderecos de placar sejam descobertos e validados. O evento nao e automaticamente classificado como gol sofrido. A cada novo inicio de `main.lua`, o mesmo CSV e recriado; nao ha segundo relatorio.

## Identificacao do autor do gol pelo placar (candidato)

Enderecos WRAM candidatos: `0x0DA2` (My_Goal(s), u16 LE) e `0x0EA2` (CPU_Goal(s), u16 LE). Ao variar exatamente um gol, o bot registra `GOAL_FOR` ou `GOAL_AGAINST` e reconstitui ate 600 frames anteriores (`PRE_GOAL_TRACE`, amostra de 3 em 3). Mudancas negativas geram `SCORE_RESET` e saltos nao unitarios `SCORE_JUMP`, sem atribuir um gol. Entrada em GS=5 sem aumento detectado gera apenas `POST_GOAL_UNVERIFIED`. Todos os eventos vao para o unico `issd_report.csv`.

**Validacao necessaria:** marcar um gol de cada lado e confirmar visualmente o incremento exato nos enderecos indicados; testar load state/partida nova. Ainda nao ha teste executado no BizHawk.

## Interceptacao emergencial (CPU_DANGER_INTERCEPT)

Quando a bola esta livre, a posse de equipe indica CPU e a bola se move com velocidade >=3 unidades/frame e componente horizontal >=2 unidades/frame em direcao ao nosso goleiro, o bot pode priorizar um ponto futuro no caminho da bola. A ativacao exige distancia horizontal ao GK de ate 300 unidades e estimativa de chegada em ate 28 frames. A projecao usa lead de 3 a 16 frames (65% do tempo ate o GK) e nao ultrapassa sua coordenada X. A troca de jogador considera o novo ponto-alvo; o status `CPU_DANGER_INTERCEPT` registra a ativacao, e a coluna `detail` de STATE_CHANGE inclui `danger_intercept=true`, `frames_to_goal` e `lead_frames`.

Limites: posicao do goleiro e aproximacao horizontal sao proxies para a linha de gol; nao ha calibracao da velocidade de corrida, colisao ou defesa do goleiro. A regra nao altera a IA de goleiro nem garante prevencao de gol. Validar em BizHawk e comparar PRE_GOAL_TRACE/GOAL_AGAINST antes de afinar os thresholds.

## Contadores de chutes (enderecos candidatos)

`My_Shot(s)` = WRAM `0x0DAA` e `CPU_Shot(s)` = WRAM `0x0EAA`, ambos unsigned 16-bit little-endian. Um incremento unitario isolado gera `SHOT_FOR` ou `SHOT_AGAINST` no arquivo unico `issd_report.csv`; reducoes geram `SHOTS_RESET` e variacoes simultaneas ou saltos geram `SHOTS_JUMP`. O primeiro valor observado e baseline, sem evento. Confirmar durante partida se os enderecos acompanham a tela de estatisticas; nao ha finalizacao automatica ainda.

## Primeira finalizacao automatica: ATTACK_SHOOT

No jogo corrido, apenas se o jogador controlado for o portador real da bola, o bot avalia chute com `X` (controle SNES). Criterios iniciais: distancia para o goleiro adversario <=310 unidades, pelo menos 25 unidades de progresso horizontal e corredor de largura 46 unidades livre de jogadores de linha adversarios. Ao disparar, o bot registra `SHOT_ATTEMPT` (comando enviado) e status `ATTACK_SHOOT`, com cooldown de 90 frames. O evento `SHOT_FOR` continua vindo **exclusivamente** do incremento da RAM `My_Shot(s)` (`0x0DAA`), permitindo separar acao do bot de finalizacao contabilizada. O chute usa o direcional horizontal na direcao do goleiro; forca e mira ainda nao calibradas. Validar no BizHawk antes de considerar sucesso.

## Diagnostico de elegibilidade de chute (SHOT_EVALUATION)

Quando o portador e exatamente o jogador controlado, o modulo shoot avalia a decisao a cada frame. Uma amostra a cada 60 frames durante posse ofensiva e escrita no CSV unico como `SHOT_EVALUATION`. O campo `action` recebe `TOO_FAR`, `GOAL_BEHIND`, `BLOCKED_LANE`, `COOLDOWN`, `INVALID_SIDE` ou `GOAL_TOO_CLOSE`. `detail` inclui `reason`, `distance`, `forward`, `blocker` (base WRAM) e `cooldown`. Chutes realmente comandados continuam como `SHOT_ATTEMPT`, enquanto `SHOT_FOR` depende do contador WRAM. A instrumentacao **nao** altera os limiares ou o comportamento de chute.

Importante: `SHOT_EVALUATION` e amostragem, nao contagem exaustiva de frames; estados sem posse ofensiva do jogador controlado nao geram avaliacao. Para entender zero tentativas, verificar tambem o tempo real em posse controlada.

## Geometria da finalizacao (linha de base 310)

O evento `SHOT_ATTEMPT` inclui em `detail` as medidas `distance` (distancia euclidiana ao goleiro CPU), `angle_deg` (angulo absoluto da linha ao goleiro em relacao ao eixo horizontal), `lateral_offset` (diferenca absoluta Y) e `nearest_defender` (distancia ate o adversario de linha mais proximo). As unidades sao coordenadas de mundo do jogo. Essas medidas nao sao xG e nao garantem que o chute seja no alvo. `SHOT_FOR` segue sendo incrementado apenas quando a RAM `0x0DAA` confirma um chute; compare frames para associar comando e estatistica. Os thresholds de chute seguem inalterados, com distancia maxima de 310.

## Escape com Y durante ATTACK_LANE

Quando o jogador controlado carrega a bola, ha bloqueador no corredor escolhido e o cooldown permite, o bot envia simultaneamente direcionais do waypoint e um pulso `Y`. Nao e mantido pressionado em frames consecutivos: cooldown de 24 frames. O evento `LANE_ESCAPE_ATTEMPT` registra comando, base do bloqueador e waypoint no CSV unico. O `shoot_diag` agora alimenta `live_attack.target_for_carrier`, permitindo que `BLOCKED_LANE` oriente o corredor lateral. O significado/eficacia do comando Y durante condução depende de validacao pratica no BizHawk; o evento mede tentativa, nao drible bem-sucedido.

## ATTACK_LANE_DASH e ATTACK_LANE_FEINT (manual Konami, pp. 16-17)

O manual do ISS Deluxe confirma: direcional+Y mantido = Dash Dribble e toque leve de Y = Feint. O bot usa `LANE_DASH_START` ao iniciar 12 frames de direcional+Y (com cooldown de 24 frames) quando ha bloqueador a frente; para bloqueador bem proximo (ate 28 unidades no eixo da trajetoria), usa `LANE_FEINT` com pulso de um frame e cooldown de 32 frames. O modo ofensivo permanece `ATTACK_LANE`, e `ATTACK_SHOOT` continua sendo avaliado primeiro a cada frame. O CSV unico registra inicio das manobras, nao sucesso garantido. Comparar saidas de posse, distancia ao gol e `SHOT_FOR` para calibrar. O comportamento so se aplica ao portador controlado em jogo corrido.

## Dynamic field bounds for throw-in receiver

Candidate WRAM addresses: stadium 0x0086, length 0x12A2, width 0x12A4, center X 0x12F2, center Y 0x12D8. The reception planner derives field edges from the center and dimensions, with a configurable 40-unit safety margin. It rejects receiver targets outside these bounds and reports THROW_IN_WAIT_FIELD_BOUNDS when no validated target exists. Validate coordinate origin and scale inside BizHawk before considering the boundaries confirmed.

## Feasibility and emergency-defense hysteresis

During CPU loose-ball flight toward our goalkeeper, defense_interception samples projected ball positions at 3-frame intervals and estimates the nearest outfield defender's arrival time using a provisional 4 world-units/frame speed. It favors the earliest reachable point (2-frame safety margin), or the least-late point when none is feasible. Emergency mode persists across up to 5 brief frames without a danger reading; preferred defender identity is held for 8 frames, but target coordinates are recalculated. State-change details include eta, slack, reachable, best_base and preferred_base. These are estimates, not measured player velocities; R selection still follows existing player-switch behavior and must be confirmed in the emulator.

## Goal kick baseline (GS=1)

If restart assignment identifies MY goalkeeper (MY_FIRST/0x0500) as taker in GS=1, the bot executes a conservative long kick with attack-direction+A after 10 frames. It waits 60 frames before one optional retry, capped at 2 attempts. Every command is logged as GOAL_KICK_ATTEMPT in the existing issd_report.csv, including direction and distance to nearest opponent. The game state transitioning away from GS=1 indicates restart progression but does not alone prove clean possession. GS=1 may cover other endline situations: never attempt the MY goal kick unless the goalkeeper is the detected taker. Control behavior and resulting state must be tested in BizHawk.

## Player switch verification (defense)

The bot now writes SWITCH_REQUEST when pressing R for defense and then checks MyCtrl over the next 8 frames. SWITCH_CONFIRMED means the actually selected player matches the predicted best player; SWITCH_MISMATCH means R selected someone else; SWITCH_UNCHANGED means MyCtrl stayed unchanged throughout the verification window. Every result includes from, expected, actual and age. A 24-frame settling window follows the verification result, preventing repeated R requests. This does not assume that R can directly select any particular player. Goal kick behavior is unchanged.

## Throw-in receiver selection guard

A short throw is READY only if the controlled receiver is within 160 world units of the taker AND within target tolerance AND has sufficient clearance. A nearer outfield teammate triggers an R switch when the distance improvement exceeds 32 units, with 12 frames reserved to observe the resulting player selection. The report detail includes receiver_distance_to_taker, receiver_distance_to_target, near_taker, and nearest_distance, where available. READY_LONG remains a time-based fallback and is not evidence of a short receiver nearby. Review on-screen positioning because player world coordinates may not align perfectly with camera visibility.

## Active throw-in selection A versus B

GS=2 now evaluates a high throw (A) proactively when the selected outfield receiver is inside the candidate stadium field boundaries, 150-500 world units from the taker, and at least 55 units from the closest opponent; it may fire after 12 frames without waiting for the old 180-frame timer. Short B still requires the receiver within 160 units of the taker, close to its safe planned waypoint, and with clear space. Invalid receiver selection is not treated as a safe long-throw target. The CSV detail includes the selected throw mode, receiver distances and clearance. High versus straight toss comes from the Konami manual (page 16); numerical thresholds are experimental and need BizHawk validation. An ATTEMPT indicates button issuance, not successful possession.

## GK safe distribution, experimental

When the goalkeeper possesses the ball in live play, short B distribution now requires receiver clearance >=72, forward progress >=12, AND minimum distance of any opponent to the projected GK-to-receiver segment >=56 world units (opponents projected near the corridor). Otherwise the bot uses directional A long kick. Each actual button pulse writes GK_DISTRIBUTION_ATTEMPT with receiver, mode, lane_clearance and reason. Subsequent player-possession changes produce GK_SAFE (outfield Brazil), GK_TURNOVER (CPU player), or GK_OUTCOME_UNKNOWN (120-frame timeout/stoppage). Outcomes are approximate: they report first observed possession, not verified quality of pass or direct causality; clearances/forward cutoffs must be tuned in BizHawk. This change does not adjust GS=1 goal kicks.

## Defensive box coverage (experimental)

When CPU controls the ball within 340 world units of Brazil goalkeeper, the bot may prioritize an unmarked secondary CPU attacker (within 220 units of GK and 260 of ball) whose closest Brazilian outfield defender is at least 75 units away. Such target is chosen by combined goal proximity, ball proximity, and lack of marking. The controlled Brazilian player moves to the opponent; R selection uses the existing verification and cooldown. Status `DEFENSE_BOX_COVERAGE`; `BOX_THREAT` logged every 30 frames with threat id and distances. IMPORTANT: if the CPU ball carrier is already within 120 units of GK, this secondary coverage is disabled and existing direct-carrier defense takes priority. GK location is a proxy for goalmouth and all distances are provisional; headers/rebound prediction and multi-player coordinated coverage are not yet implemented. `GS=1` unchanged.

## Safe forward B passes (experimental)

During live play, when an outfield Brazilian player is the controlled ball carrier and a safe X shot is not available, the bot evaluates teammates **ahead in the attacking X direction**. It only sends B+Right/Left to a candidate 75-260 units ahead, within 24 lateral units, with at least 72 units of receiver clearance and 52 units of passing corridor clearance. The highest-scoring candidate balances progress, lane and receiver space. If no safe candidate qualifies, ordinary attacking movement continues. A 75-frame cooldown limits repeated passes. `ATTACK_FORWARD_PASS` and `FORWARD_PASS_ATTEMPT` record intended receiver, distance, progress, lateral offset, lane clearance, receiver clearance, score and button. These measurements evaluate the intended straight-line segment; the actual in-game target selection for B and possession outcome still require BizHawk verification. GS=1 goal kicks and goalkeeper distribution are unchanged.

## Lane progress validation (experimental)

During active attacking `LANE` maneuvers, track the controlled carrier's forward X movement in the attack direction across a 45-frame window. If forward progress is below 24 world units, classify `LANE_STALLED`, log `LANE_ABORTED`, and suspend Y lane maneuvers for 80 frames; the player instead attempts direct forward recovery movement without Y. Successful windows log `LANE_PROGRESS`. The events include carrier, elapsed frames, and progress. A new carrier resets the monitor, as does returning to ordinary ADVANCE. Shooting and eligible forward B passing keep priority. This is position-based progress measurement, **not** detection of a successful dribble or an actual opponent beaten. Thresholds need BizHawk validation.

## Zone-aware outfield B passing

The attacking field is divided into thirds using candidate world field length and center X WRAM. Invalid/out-of-range geometry disables automatic passing rather than guessing. In thirds 1 and 2, the existing conservative B+Left/Right progressive policy targets a teammate 75-260 units ahead with up to 24 units lateral offset. In the attacking third, B+Up/Down evaluates a teammate 65-220 units to the side, within 28 forward/backward units, with 82 receiver clearance and 62 corridor clearance. Shooting (X) still has precedence; if no passing candidate qualifies, the bot retains normal dribbling. The FORWARD_PASS_ATTEMPT detail adds `zone` (1/2/3) and `intent` (PROGRESSIVE/LATERAL). Directional passing mechanics, candidate field coordinates, and thresholds remain unvalidated in BizHawk; an attempted B is not a completed pass. These are open-play lateral passes, not throw-ins (GS=2).

## Attacking free kicks (`GS=3`, experimental)

`FREE_KICK_WAIT_TAKER` waits if the nearest Brazilian outfield player is more than 115 world units from the ball or the closest CPU player is not at least 16 units farther. After the same Brazilian taker stays the nearest candidate for 18 frames, the bot sends directional B for a routine kick or X if the CPU GK is within 260 world units in the attack direction. It permits one delayed retry with directional A after 75 frames while GS=3 persists. `FREE_KICK_ATTEMPT` records button, mode, taker, distances, stability and attempt count. **Caveat:** GS=3 is classified as a foul restart sequence, not a confirmed directly executable set piece; camera state, team award and animation phases are not yet verified in WRAM. The nearest-to-ball heuristic is not authoritative ownership. Watch BizHawk behavior before treating attempts as valid kicks. GS=1 goal kicks were not changed.

## Attacking corner kick (experimental GS=1)

Unlike a goal kick, an attacking corner is attempted only when nearest-to-ball restart assignment points to a Brazilian outfielder, and the ball is within 90 world units of the opponent's endline and a sideline according to candidate stadium field bounds, with the taker within 120 world units of the ball. After 12 stable frames, the bot sends inward directional A (high cross), then at most one B retry after 65 frames if GS=1 persists. `CORNER_KICK_ATTEMPT` records button, mode, taker and location checks. `CORNER_KICK_WAIT` is not proof of an actual corner; `CORNER_KICK_ATTEMPT` is not confirmation of a completed cross. World field bounds, classification and A/B execution must be validated with BizHawk. This change leaves the goalkeeper's GS=1 routine unchanged.

## Active tackle (conservative B charge)

When a Brazilian outfield player is controlled in live play and a CPU outfielder controls the ball within 40 world units, the bot sends a single B charge before ordinary defensive movement. There is a 30-frame cooldown; no sliding tackles or X+A shoulder tackles are used. `TACKLE_ATTEMPT` records defender, CPU carrier, distance, and B input. For up to 45 frames afterward, the first detected Brazilian possession creates `TACKLE_SUCCESS`, a different CPU ball holder creates `TACKLE_FAILED`, or timeout creates `TACKLE_UNKNOWN`. These are heuristics based on the first observed possession, not proof that B caused the outcome; a CPU carrier retaining possession at timeout yields UNKNOWN. Distances and timing require BizHawk calibration. Foul attribution remains unimplemented.

## Goal-side defensive positioning (experimental)

Against a CPU outfield ball carrier during live play, `LIVE_DEFENSE` targets a point on the line between the carrier and Brazil's goalkeeper (GK world position used only as a provisional goalmouth proxy), up to 65 world units from the carrier and at most 65% of their separation. The existing player-switch logic selects a defender by distance to that target, and close B charge still has priority. Every 30 frames of LIVE_DEFENSE, `GOAL_SIDE_POSITION` records whether the controlled defender projects between the carrier and goalkeeper within a 65-unit lateral tolerance, its normalized projection, lateral deviation, carrier-to-goalkeeper distance, and emergency flag (within 125 units). This does not assert that a defender physically blocks a shot or that the GK is the exact goal center; outcomes need BizHawk validation. Existing box coverage may override this target when it detects an unmarked secondary attacker.

## Corner wait diagnostics (2026-10-08)

GS=1 attacking corner now reports `CORNER_KICK_STABILIZING`, `CORNER_KICK_COOLDOWN`, `CORNER_KICK_EXHAUSTED`, or `CORNER_KICK_BALL_MOVED` rather than a generic `CORNER_KICK_WAIT`. After issuing a crossing command it watches the ball's world displacement relative to its pre-kick position (threshold 18 units); if moved, it suppresses the follow-up retry for that corner. When the state still persists, the second attempt remains B after 65 frames and no third command is issued. `CORNER_KICK_DIAGNOSTIC` samples terminal observations and `CORNER_KICK_ATTEMPT` contains wait reason and cooldown. BALL_MOVED is evidence of displacement, **not** proof of a successful corner or confirmed GS=0. An EXHAUSTED status means attempts were consumed without observed exit and the control mapping/animation readiness needs inspection. All thresholds and directional mechanics remain experimental.

## Defensive possession transition (first third)

In live play, when the currently controlled Brazilian **outfielder** holds the ball within the defending first third according to candidate field length/center and validated attack orientation, the bot first looks for a conservative progressive B outlet via `forward_pass.plan()`. If safe, it records `DEFENSIVE_OUTLET_PASS` along with the normal `FORWARD_PASS_ATTEMPT` data. Otherwise, it sends no movement or Y dash and shows `DEFENSIVE_HOLD` until a safe pass becomes available, the player changes, or the ball leaves the defensive third. A new protected possession logs `DEFENSIVE_RECOVERY` and prolonged holding is sampled as `DEFENSIVE_HOLD` every 60 frames. Goalkeeper distribution is unchanged; normal shooting/dribbling resume outside the first third. Caveats: player roles are not yet explicitly read from WRAM, so this protection applies to *all* outfield carriers in the first third, not just center backs. Passive holding may still lead to dispossession under pressure. Field coordinate calibration and eventual controlled clearance/escape policy remain future work.

## Defensive safe exit (B lateral and bounded repositioning)

In defensive first-third controlled outfield possession, the bot tries the existing safe forward B pass first. When unavailable, `defensive_exit.lua` selects a nearby teammate in a lateral Up/Down corridor (65-190 units lateral, <=30 units horizontal, <=210 total), checking nearest-CPU receiver clearance >=80 and passing-segment clearance >=60. It sends B via the existing 75-frame forward-pass cooldown and logs `DEFENSIVE_OUTLET_PASS`, `FORWARD_PASS_ATTEMPT` with intent `DEFENSIVE_LATERAL` and status `DEFENSIVE_LATERAL_PASS`. If neither pass qualifies, it holds for 45 frames then uses limited directional (no Y) movement toward the safer nearby side while making slight forward progress. Total movement from the initial escape location is bounded to 70 world units; if there is no safe local space or movement budget is used, `DEFENSIVE_HOLD` remains the fallback. Periodic `DEFENSIVE_SHORT_ESCAPE` includes reason and possession age. This is conservative geometry using estimated player world coordinates, not validated button targeting; test actual receiver selection and possible turnovers in BizHawk. The GK and GS=1 routines remain unchanged.

## Pressure-aware defensive possession (2026-10-08)

`defensive_exit.lua` samples distance from the controlled Brazilian outfield carrier to the nearest CPU player. Existing safe progressive and lateral B outlets remain first priority. Without a pass, pressure within 95 world units bypasses the old 45-frame wait and allows a bounded, low-speed positional escape immediately (no Y). Under acute pressure within 38 world units, if the short escape has no safe space or its 70-unit displacement budget has been exhausted, the bot attempts a one-time `A+Right/Left` directional clearance in the attacking direction for that continuous possession; no repeating A every frame. It emits `DEFENSIVE_PRESSURE_CLEAR`. `DEFENSIVE_EXIT_DIAGNOSTIC` samples a `DEFENSIVE_HOLD` every 30 frames, recording `WAIT_OUTLET`, `NO_SAFE_SPACE`, `ESCAPE_LIMIT`, or `BAD_FIELD` and `threat_distance`. Directional clearance behavior is experimental and requires BizHawk validation. The telemetry measures issued inputs, not verified clearances or possession outcomes.

## Boundary-aware controlled dribbling

`field_boundary.lua` checks calibrated WRAM field length/width/center and places controlled-dribble targets at least 40 world units inside every touchline/endline. If the actual controlled player is within 30 units of the inner safety limit, an outward target is replaced by a 48-unit inward step. `orchestrator.lua` applies this to both `ATTACK_LANE`/`ATTACK_ADVANCE` and `DEFENSIVE_SHORT_ESCAPE`; when attacking near a boundary it suppresses Y dash/feint while using the corrected ordinary directional movement. Events `BOUNDARY_RISK` (every 30 qualifying frames) and `BOUNDARY_TARGET_CLAMPED` (every 15 corrected frames) show intervention. This does not change pass/shoot/clearance controls, scripted restarts or free-ball interception: boundary approaches may be legitimate for those. Calibrate field world coordinates, margins and real ball movement with BizHawk before claiming out-of-bounds prevention.

## GS=3 free-kick reliability (2026-10-08)

Fouls in `GS=3` use a free-kick-specific nearby outfield Brazilian candidate, shown in the restart HUD rather than an empty generic restart taker. The controller must match the candidate before a kick input is sent; if not, the bot attempts `R` no more than three times at 30-frame spacing, logged as `FREE_KICK_SWITCH_TAKER`. After a stable 18-frame candidate, the first attempt is progressive `B+Right/Left`, or `X` near the CPU goal; after 75 frames it can retry once with `A`. As soon as the ball moves at least 18 world units from its recorded pre-kick position, it shows `FREE_KICK_BALL_MOVED` and does not keep retrying; after two attempts it shows `FREE_KICK_EXHAUSTED`. `FREE_KICK_DIAGNOSTIC` samples GS=3 status every 60 frames including candidate, controlled player, cooldown, distances and ball displacement. These observations do not establish whether the free-kick reached a teammate; a captured screenshot with `RETRY_LONG` is not proof that an A kick was accepted. Control switching with R and ball displacement must still be verified in BizHawk.

## Final third shot-angle decision (experimental)

`shoot.lua` now rejects X shots with goalkeeper-relative angle above 30 degrees (`BAD_SHOT_ANGLE`) while retaining the shot-angle diagnostic. For this reason only, the controlled outfielder's normal attack flow first calls `forward_pass.plan(carrier, true)`: in third 3 it searches for an otherwise safe lateral B pass to a teammate whose Y position is at least 20 units closer to the opponent GK's Y coordinate than the carrier's. Eligible candidates retain normal receiver and passing-lane safety limits. On a fired pass, `ATTACK_CENTRALIZING_PASS` is logged, alongside standard `FORWARD_PASS_ATTEMPT`. If no safe centralizing outlet qualifies, movement reverts to the ordinary, boundary-guarded dribble; it does not force an unsafe pass or long Y dash near the field boundary. `ATTACK_SHOT_ANGLE_REJECTED` is sampled every 45 frames in the attack branch. The measured angle refers to goalkeeper world position, an approximation of goal-center orientation; real goals and shot-count reliability need emulator validation. This does not yet evaluate shot quality from keeper positioning or identify crosses/assists.
