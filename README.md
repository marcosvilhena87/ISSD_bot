# ISSD_bot — Radar v0.4.0

Projeto iniciado do zero para *International Superstar Soccer Deluxe* (SNES), BizHawk/Lua.

## Objetivo

Sobrepor **somente marcadores transparentes** ao radar nativo do ISSD, coletando 22 jogadores e bola. O script não altera a memória nem envia comandos ao jogo.

## Executar

1. Abra uma partida no BizHawk.
2. Em **Tools → Lua Console**, execute `lua/radar.lua`.
3. Compare os pixels: ciano = minha equipe; vermelho = CPU; amarelo = bola.
4. Se necessário, altere `OFFSET_X`/`OFFSET_Y` e reinicie o script.
5. Examine `issd_radar_entities.csv`: amostra a cada 10 frames, 23 linhas por amostra. O arquivo é sobrescrito a cada execução.

## Configuração visual (pixels lógicos)

```lua
local FX, FY, FW, FH = 88, 161, 79, 54
local OFFSET_X, OFFSET_Y = 0, 0
local SHOW_OVERLAY = true
```

- O ponto final é calculado por `FX + normalized_x * FW + OFFSET_X`, e analogamente para Y. Coordenadas normalizadas fora de [0,1] não são desenhadas, mas continuam no CSV.
- `SHOW_OVERLAY = false` deixa o script somente em modo de coleta.
- Nenhuma borda, fundo, linha ou texto é desenhado no radar. Cada entidade visível usa `gui.drawPixel`.
- Os deslocamentos são em pixels **lógicos** do BizHawk, não em pixels da imagem ampliada. Ajustar o overlay por capturas visuais exige considerar a escala.
- A imagem do jogo não demonstra, por si só, que origem e escala das coordenadas já estejam calibradas.

## Endereços WRAM

Todas as posições são `i16` little-endian, com X no endereço base e Y em `base + 2`:

| Entidade | X | Y |
| --- | --- | --- |
| Bola | `0x042A` | `0x042C` |
| Meu time, goleiro até camisa 11 | `0x052A + (i * 0x100)` | `0x052C + (i * 0x100)` |
| CPU, goleiro até camisa 11 | `0x102A + (i * 0x100)` | `0x102C + (i * 0x100)` |

Para as duas equipes, `i` varia de 0 a 10. Estádio em `0x0086` (i16). Comprimento e largura em `0x12A2` e `0x12A4` (u16).

## Calibração pendente

`ORIGIN_X/Y = 0` e `SCALE_X/Y = 1` são hipóteses iniciais. A presença dos marcadores sobre o radar nativo **não comprova** alinhamento exato. Testar bola e jogadores em diferentes posições e estádios, verificar os erros em X e Y e distinguir deslocamento, inversão e escala. O próximo marco é aferir a projeção com amostras reproduzíveis.
