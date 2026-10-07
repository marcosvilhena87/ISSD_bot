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
