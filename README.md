# ISSD_bot — Radar v0.1.0

Projeto novo, independente de versões anteriores, para **International Superstar Soccer Deluxe (SNES)** usando BizHawk/Lua.

## Primeiro marco: radar somente leitura

- Lê bola e dimensões conhecidas da WRAM.
- Desenha um campo esquemático com a bola no overlay do BizHawk.
- Grava amostras em `issd_radar_ball.csv` para validar coordenadas e limites.
- **Não pressiona botões, não modifica memória e não inventa endereços de jogadores.**

### Endereços iniciais (WRAM; validar empiricamente)

| Endereço | Tipo | Campo |
| --- | --- | --- |
| 0x042A | u16 little-endian | Ball_x |
| 0x042C | u16 little-endian | Ball_y |
| 0x0086 | i16 little-endian | Stadium_ID (observado 0–7) |
| 0x12A2 | u16 little-endian | field_length (x) |
| 0x12A4 | u16 little-endian | field_width (y) |

As dimensões são medidas da RAM, e não representam automaticamente os limites mínimos/máximos das coordenadas da bola. Por segurança, a visualização utiliza *normalização provisória* (origem 0); se as posições não corresponderem à imagem do jogo, calibrar offset e escala.

### Como executar

1. Abrir ROM no BizHawk e pausar em uma partida.
2. Em **Tools > Lua Console**, executar `lua/radar.lua`.
3. Continuar a emulação, observar o overlay e conferir o CSV na pasta de trabalho do Lua Console.
4. Comparar as coordenadas com movimentos conhecidos: bola no centro, nas laterais e nas linhas de fundo.
5. Ajustar `ORIGIN_X`, `ORIGIN_Y` e `SCALE_X`, `SCALE_Y` na seção de configuração, se necessário.

O arquivo CSV é criado no diretório de trabalho do processo BizHawk; o diretório pode variar conforme a configuração.

### Próximos passos

1. Calibrar limites/offset por estádio.
2. Descobrir endereços de posições de atletas usando amostras sincronizadas do radar real do jogo, **sem pressupor a estrutura de memória**.
3. Separar equipes, distinguir jogador controlado e medir persistência do rastreamento.
4. Testes com gravações reproduzíveis e detecção de leituras inválidas.

**Nota:** até a descoberta de posições dos atletas, este é um radar da **bola**, não um radar completo de 22 jogadores.
