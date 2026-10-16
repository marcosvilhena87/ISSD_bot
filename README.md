# ISSD_bot — Radar v0.7.0

Radar em **Lua/BizHawk** para International Superstar Soccer Deluxe (SNES), somente leitura da WRAM.

## Novidade: referencias sincronizadas por frame

A v0.7.0 nao aplica mais a mesma coordenada nativa a todos os frames. Cada referencia manual identifica **frame + equipe + numero + pixel nativo X/Y**. Erro so e calculado quando o frame emulado e a entidade coincidem com o registro.

No topo de `lua/radar.lua`:

```lua
local TARGET_TEAM, TARGET_NUMBER = "ball", 0
local REFERENCES = {
    -- EXEMPLOS FICTICIOS; substitua por medidas reais!
    -- {frame=123456, entity="ball", number=0, x=130, y=188},
    -- {frame=123900, entity="my", number=1, x=90, y=188},
    -- {frame=124200, entity="cpu", number=1, x=166, y=188}
}
```

Por padrao a tabela esta vazia. O modo de destaque segue `TARGET_TEAM/TARGET_NUMBER`, `FOCUS_ONLY`, `SHOW_TARGET_CROSS`; ele e independente das referencias registradas para calculo de erro.

## Procedimento experimental

1. Abra o jogo no BizHawk, entre na partida, escolha o alvo e execute o script.
2. Pause em um frame conhecido (`emu.framecount()` pode ser conferido no CSV); salve um **savestate** para reproduzir o mesmo instante e fotografe o radar nativo.
3. Identifique manualmente a coordenada nativa em **pixels logicos** do BizHawk. Nao confunda pixel logico com pixel da imagem ampliada.
4. Inclua `{frame=..., entity="...", number=..., x=..., y=...}` na tabela `REFERENCES`.
5. Retorne ao **mesmo savestate** e reinicie o script; reproduza ate o frame anotado para obter a linha `MATCHED`.
6. Repita para varias regioes do campo, com goleiros e bola, e outros estadios. Se o frame exato nao for reproduzido, o script **nao inventa erros**.

Observacao: savestates, reinicios de emulacao, ROMs ou partidas diferentes podem reutilizar numeros de frame. A associacao por frame e valida **apenas na mesma sequencia reproduzida**. O script nao identifica automaticamente a sequencia, ROM ou savestate.

## Status no CSV

`issd_radar_calibration.csv` tem uma linha por entidade amostrada; registra coordenadas da WRAM, dimensoes, coordenadas normalizadas, pixels projetados, parametros, referencias manuais e erros X/Y/distancia.

- `MATCHED`: frame/entidade correspondem a uma referencia, dimensoes validas e coordenadas projetadas dentro dos limites. Erro em pixels = projetado - referencia.
- `NO_REFERENCE`: nenhuma referencia manual corresponde a este frame/entidade; erros vazios.
- `INVALID_DIMENSIONS`: comprimento/largura zerados; sem calculo.
- `OUTSIDE_BOUNDS`: referencia presente mas projecao fora dos limites normalizados; nao calcula distancia.

O script amostra a cada 10 iteracoes e **forca uma amostra nos frames presentes em REFERENCES**. Sao 23 linhas por amostra (22 jogadores e bola). O CSV e sobrescrito ao reiniciar; guarde o arquivo antes de uma nova sessao.

## Ajustes visuais

```lua
local FX, FY, FW, FH = 88, 161, 79, 54
local SHOW_CORNERS = true
local ORIGIN_X, ORIGIN_Y = 0, 0
local SCALE_X, SCALE_Y = 1, 1
local INVERT_X, INVERT_Y = false, false
local OFFSET_X, OFFSET_Y = 0, 0
local TARGET_TEAM, TARGET_NUMBER = "ball", 0
local FOCUS_ONLY = true
local SHOW_TARGET_CROSS = true
```

Os quatro cantos magenta definem o enquadramento. A mira branca e os pontos desenhados so representam a posicao **projetada**, nao deteccao automatica do radar nativo.

## Mapeamento de memoria

Leitura signed 16-bit little-endian com Y em X+2:

- Bola: `0x042A`.
- Meu time: `0x052A+i*0x100`, i = 0...10.
- CPU: `0x102A+i*0x100`, i = 0...10.
- Estadio: `0x0086` (i16); comprimento: `0x12A2` (u16); largura: `0x12A4` (u16).

**Limites:** nem as dimensoes da WRAM nem a proximidade visual dos pontos validam automaticamente a escala/origem. A v0.7.0 calcula erros de referencias manuais, mas ainda nao estima a calibracao ideal automaticamente.
