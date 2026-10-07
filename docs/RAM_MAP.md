# RAM Map

Documento de trabalho para registrar endereços de memória descobertos no ISS Deluxe.

> Regra: nenhum endereço deve ser considerado confirmado após uma única observação.

## Variáveis prioritárias

| Variável | Endereço | Tipo | Faixa | Status | Observações |
|---|---:|---|---|---|---|
| Ball X | — | — | — | 🔴 não localizado | prioridade 1 |
| Ball Y | — | — | — | 🔴 não localizado | prioridade 1 |
| Controlled Player X | — | — | — | 🔴 não localizado | prioridade 2 |
| Controlled Player Y | — | — | — | 🔴 não localizado | prioridade 2 |
| Controlled Player ID | — | — | — | 🔴 não localizado | prioridade 2 |
| Possession | — | — | — | 🔴 não localizado | prioridade 3 |
| Score For | — | — | — | 🔴 não localizado | prioridade 4 |
| Score Against | — | — | — | 🔴 não localizado | prioridade 4 |
| Match Time | — | — | — | 🔴 não localizado | prioridade 5 |

## Protocolo de validação

Para cada endereço candidato:

1. registrar o valor parado;
2. alterar apenas a variável que queremos testar;
3. observar correlação;
4. repetir em várias posições;
5. reiniciar a partida;
6. trocar de equipe/lado quando aplicável;
7. confirmar estabilidade;
8. verificar byte order, escala e possíveis offsets.

## Bola X/Y

### Hipótese

Ainda não localizada.

### Testes sugeridos

- congelar a bola visualmente em diferentes regiões;
- comparar memória entre esquerda/centro/direita;
- repetir para topo/centro/base;
- procurar valores monotônicos;
- identificar se coordenadas são 8-bit, 16-bit ou fixed-point.

## Critério para marcar como confirmado 🟢

Um endereço só deve virar 🟢 quando:

- acompanha a variável em múltiplos cenários;
- não apresenta falsos positivos óbvios;
- permanece válido após reiniciar a partida;
- sua transformação para coordenada de campo estiver entendida.
