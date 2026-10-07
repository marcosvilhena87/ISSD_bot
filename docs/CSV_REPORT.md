# Relatorio automatico do ISSD Bot

Ao abrir `tools/bizhawk/issd/main.lua` pelo Lua Console do BizHawk, o script tenta criar ou acrescentar registros em:

`tools/bizhawk/issd/issd_report.csv`

O CSV e gravado imediatamente (flush) e pode ser aberto no Excel. A coluna `session` separa as execucoes. O arquivo nao e apagado quando o script inicia novamente.

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
