# ISSD Bot ⚽🤖

Bot de IA para **International Superstar Soccer Deluxe (SNES)**.

O objetivo do projeto é construir um agente capaz de aprender a jogar ISS Deluxe usando **estado extraído da RAM do emulador + Reinforcement Learning**, evoluindo por currículo até partidas completas e, posteriormente, **self-play**.

## Estratégia principal

```text
ISS Deluxe
   ↓
Emulador
   ↓
Leitura de RAM
   ↓
Estado estruturado
   ↓
Gymnasium Environment
   ↓
PPO
   ↓
Curriculum Learning
   ↓
Self-play
```

A prioridade é evitar, no começo, aprendizado puramente por pixels. Ler diretamente variáveis relevantes da RAM reduz drasticamente a complexidade do problema e permite validar a lógica do agente antes de adicionar visão computacional.

## Fase 0 — Descoberta da RAM

Primeiro objetivo técnico:

- posição X/Y da bola;
- posição X/Y do jogador controlado;
- identificação do jogador controlado;
- posse de bola;
- placar;
- cronômetro/estado da partida.

Com esse conjunto mínimo já será possível criar um primeiro ambiente de RL.

Veja [docs/RAM_MAP.md](docs/RAM_MAP.md).

## Espaço de observação inicial

Exemplo conceitual:

```text
ball_x
ball_y
ball_vx
ball_vy

controlled_player_x
controlled_player_y
controlled_player_vx
controlled_player_vy

possession
score_for
score_against
match_time
attacking_direction
```

Depois o estado poderá ser expandido para incluir todos os companheiros e adversários.

## Espaço de ações

Primeira versão:

```text
NOOP
UP
DOWN
LEFT
RIGHT
UP_LEFT
UP_RIGHT
DOWN_LEFT
DOWN_RIGHT
PASS
SHOOT
SPECIAL
direction + PASS
direction + SHOOT
```

O agente não precisa decidir em todos os frames. A ideia inicial é usar **frame skip de 3–6 frames**, reduzindo a frequência de decisão e tornando as ações mais próximas de comandos humanos.

## Curriculum Learning

O bot não começará tentando vencer uma partida completa.

1. aproximar-se da bola;
2. conquistar posse;
3. manter posse;
4. conduzir em direção ao gol;
5. completar passe;
6. receber passe;
7. entrar no terço ofensivo;
8. finalizar;
9. marcar gol;
10. recuperar a bola;
11. defender;
12. disputar partidas completas;
13. self-play.

## Recompensa

No início, recompensas intermediárias ajudam o agente a descobrir comportamento útil:

```text
+ aproximação da bola
+ conquista de posse
+ avanço territorial
+ passe completo
+ entrada em zona ofensiva
+ finalização
+ gol

- perda de posse
- finalização perigosa sofrida
- gol sofrido
```

À medida que o agente melhora, essas recompensas devem ser reduzidas (**reward annealing**) para que o objetivo final se aproxime de:

```text
gol
saldo de gols
vitória
```

## Algoritmo

Primeiro baseline:

- **PPO**
- Gymnasium
- Stable-Baselines3
- PyTorch

Uma evolução possível é:

```text
Behavioral Cloning
        ↓
       PPO
        ↓
Curriculum Learning
        ↓
    Self-play
```

## Estrutura inicial

```text
ISSD_bot/
├── docs/
│   ├── RAM_MAP.md
│   └── ROADMAP.md
├── src/
│   └── issd_bot/
│       ├── __init__.py
│       └── env.py
├── .gitignore
├── requirements.txt
└── README.md
```

## Próximo marco

**Milestone 0: descobrir e validar os endereços de RAM da bola.**

Critério de conclusão:

- localizar X e Y;
- confirmar que os valores acompanham a bola durante a partida;
- identificar escala/faixa dos valores;
- verificar se os endereços permanecem estáveis após reiniciar a partida.

Depois disso, repetir o procedimento para o jogador controlado e a posse de bola.

## Status

🟡 **Fase inicial — engenharia reversa / mapeamento da RAM**


## Arquitetura Lua modular

A lógica do BizHawk agora é modular. O arquivo `tools/bizhawk/chase_ball.lua` é apenas o launcher; a implementação fica em `tools/bizhawk/issd/`.

Veja [docs/LUA_ARCHITECTURE.md](docs/LUA_ARCHITECTURE.md).
