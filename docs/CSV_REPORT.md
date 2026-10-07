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
