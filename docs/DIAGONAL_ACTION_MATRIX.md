# Matriz diagnóstica: Control Pad diagonal + A/B/X/Y

## Objetivo

Sonda isolada que testa as 16 combinações (quatro diagonais × A, B, X, Y)
sem alterar a política do bot. O fato de o controle aceitar as entradas
não comprova a direção ou a eficácia do passe, chute, lançamento ou corrida.

## Execução no BizHawk

1. Abra a ROM de ISS Deluxe em uma situação reproduzível de jogo ativo, com
   **posse individual da sua equipe** e espaço livre para observar as ações.
2. Pare o script `main.lua` no Lua Console (não execute ambos ao mesmo tempo).
3. Carregue `tools/bizhawk/issd/probes/diagonal_action_matrix.lua`.
4. A sonda salva um snapshot **em memória**, restaura esse mesmo snapshot
   antes de cada um dos 16 experimentos, envia a combinação por um frame,
   solta o controle e observa a bola por 30 frames.
5. O arquivo `tools/bizhawk/issd/diagonal_action_matrix.csv` terá uma linha
   por experimento, na ordem Right+Up, Right+Down, Left+Up, Left+Down;
   dentro de cada direção, A, B, X, Y.
6. Ao concluir, a sonda restaura o snapshot inicial. Se o jogo não estiver
   em andamento ou a bola não estiver sob posse individual da sua equipe,
   o experimento aborta sem enviar comandos.

O experimento requer o mecanismo de savestates em memória da versão do
BizHawk em uso. Não execute com scripts de controle simultâneos.

## Interpretação

Os campos `action_dx/dy` medem a mudança da bola logo após o frame da
entrada. `end_dx/dy` medem a diferença após 30 frames; `max_displacement`
mede a maior distância observada até a posição inicial.
`first_owner_change_frame` e `first_ball_change_frame` marcam a primeira
mudança observada. Uma mudança de `team` ou `owner` **não confirma**
recepção ou controle físico. Velocidade prévia, animação do jogador e
adversários influenciam resultados; repita em cenários diferentes antes de
habilitar mais ações no bot.

Esta sonda é distinta do observador passivo v42 e dos passes experimentais
v43. Não é um classificador de resultado tático.
