# WCH source notes

Arquivos Watch do BizHawk usados como base inicial de engenharia reversa.

## Fontes analisadas

- `International Superstar Soccer Deluxe (USA) ball.wch`
- `International Superstar Soccer Deluxe (USA) flags.wch`
- `ISSD_field.wch`
- `ISSD_players.wch`
- `ISSD_players_cam.wch`

Os arquivos não são tratados como prova definitiva. Eles fornecem nomes, endereços e tipos que devem ser confirmados na ROM-alvo.

## Resumo

### `ISSD_players.wch`

Fonte mais valiosa até agora.

Revela:

- bola em `0x042A/0x042C`;
- coordenadas X/Y dos 22 jogadores;
- layout regular com stride de `0x100`;
- words signed para coordenadas.

### `ISSD_players_cam.wch`

Revela:

- coordenadas de câmera dos 22 jogadores;
- coordenadas do jogador controlado;
- bola relativa à câmera em `0x1FFA6/0x1FFA8`;
- anotação `center = 128`.

### `flags.wch`

Revela candidatos para:

- jogador controlado;
- posse;
- estado do jogo;
- lado de cada equipe.

### `ISSD_field.wch`

Revela:

- stadium ID;
- dimensões do campo;
- centro do campo.

### `ball.wch`

Contém 84 candidatos sem rótulo, provavelmente de uma etapa anterior de busca. Não inclui os endereços rotulados `Ball_x/Ball_y` do arquivo de jogadores.

## Próxima validação

O teste de maior retorno é comparar em tempo real:

```text
Ball world:  0x042A / 0x042C
Ball camera: 0x1FFA6 / 0x1FFA8
```

Se ambos acompanharem a bola corretamente, o Milestone 0 pode ser parcialmente fechado e podemos avançar para a transformação mundo ↔ câmera.
