# ISSD Bot ⚽🤖

Bot experimental para **International Superstar Soccer Deluxe (SNES)**, executado no **BizHawk**, com leitura de RAM, controle via Lua e decisões táticas baseadas em regras. O objetivo de longo prazo é evoluir para aprendizado por reforço (RL) com Gymnasium/PPO e, depois, self-play.

> **Estado em 09/10/2026:** já existe um controlador Lua modular com lógica de jogo, telemetria CSV e sondas de RAM. **Gymnasium, treinamento PPO e self-play ainda não estão integrados/validados.** Ter código de uma tática não significa que ela tenha desempenho comprovado em partidas.

## Como executar o controlador atual

1. Abra a ROM compatível do jogo no **BizHawk/EmuHawk** (consulte [TARGET_ROM](docs/TARGET_ROM.md)).
2. Abra o **Lua Console** do BizHawk.
3. Execute `tools/bizhawk/issd/main.lua` mantendo a árvore de módulos do repositório.
4. Observe o HUD e os eventos em `tools/bizhawk/issd/issd_report.csv`. Os atalhos e parâmetros operacionais estão no código e na documentação de diagnóstico.

O script legado `tools/bizhawk/issd/entry/chase_ball.lua` é apenas um ponto de compatibilidade; use `main.lua` para novas execuções. A geração do CSV depende da execução local no emulador; atualizar o GitHub não gera relatórios automaticamente.

## Arquitetura atual

```text
International Superstar Soccer Deluxe
              |
        BizHawk / Lua
              |
   WRAM -> state/* e core/*
              |
      app/orchestrator.lua
         /    |    \
 tactics/* control/* ui/*
              |
    comandos do controle
              |
  eventos / relatório CSV
```

Principais diretórios:

| Caminho | Responsabilidade |
| --- | --- |
| `tools/bizhawk/issd/main.lua` | Entrada oficial no emulador |
| `app/orchestrator.lua` | Loop principal, coordenação de estados e decisões |
| `core/` | Endereços/configuração, acesso à memória, geometria e relatórios |
| `state/` | Bola, jogadores, posse, contexto físico, voo, rebotes e transições |
| `control/` | Movimento e troca de jogador |
| `tactics/` | Ataque, defesa, interceptação, cobranças e distribuição do goleiro |
| `ui/` | HUD |
| `probes/` | Sondas e ferramentas de investigação da RAM |
| `src/issd_bot/` | Base Python para a futura integração com RL; não é o controlador operacional atual |

Para detalhes, consulte [LUA_ARCHITECTURE](docs/LUA_ARCHITECTURE.md), [RAM_MAP](docs/RAM_MAP.md) e [FIRST_CONTROL_LOOP](docs/FIRST_CONTROL_LOOP.md).

## Capacidades implementadas no código Lua

- Leitura estruturada da RAM: posição da bola, jogadores, estados de jogo e sinais de posse.
- Controle por estados e emissão de comandos, incluindo movimentação, defesa e ataque.
- Módulos específicos para passe, finalização, interceptação, laterais, escanteios, faltas, tiros de meta e goleiro.
- Tratamento de bola aérea, posse física, contexto de voo, recuperação de rebote e transições.
- Telemetria e diagnóstico por HUD, CSV e probes.

**Atenção à semântica da posse:** `Team_Ball_Possession` é um sinal bruto do jogo, **não prova um toque, domínio ou recuperação efetiva**. O monitor `state/ball_logical_team_transition.lua` observa mudanças e registra contexto; não deve converter automaticamente `CPU_UNOWNED_BALL ↔ MY_UNOWNED_BALL` em troca de posse confirmada. A análise de rebote do goleiro também produz **candidatos**, não confirmação de defesa.

## Próxima prioridade

**Validar e classificar a bola em disputa com evidências observáveis**, distinguindo sinal lógico, dono individual, trajetória, proximidade e contato efetivo. Em especial:

1. Correlacionar transições lógicas com `Last_Player_Ball_Possession`, altura, deslocamento da bola e distância aos jogadores.
2. Diferenciar rebote do goleiro, passe/chute em voo, recuperação e bola genuinamente disputável, sem inferir posse apenas pelo sinal de equipe.
3. Criar casos de regressão baseados em CSV e critérios objetivos para não degradar decisões existentes.
4. Medir efeitos táticos após validar o classificador, antes de aumentar a complexidade do agente.

A ordem de execução e os marcos de RL estão em [ROADMAP](docs/ROADMAP.md).

## Caminho para aprendizado por reforço (planejado)

```text
Estado validado da RAM + controlador Lua instrumentado
                    |
       bridge e reset reproduzíveis
                    |
       Gymnasium (observações/ações)
                    |
          baseline + currículo
                    |
         PPO / avaliação isolada
                    |
               self-play
```

A ideia é explorar primeiro observações estruturadas, em vez de depender somente de pixels. O plano contempla recompensas por aproximação, recuperação, progressão, passes e finalizações, com redução posterior dos incentivos intermediários para priorizar gols e vitórias. **Isso é uma direção de pesquisa, não uma capacidade pronta.**

## Documentação

- [ROADMAP.md](docs/ROADMAP.md) — entregas realizadas e pendências priorizadas.
- [RAM_MAP.md](docs/RAM_MAP.md) — memória e campos investigados.
- [CSV_REPORT.md](docs/CSV_REPORT.md) — eventos, colunas e diagnóstico.
- [LUA_ARCHITECTURE.md](docs/LUA_ARCHITECTURE.md) — módulos do controlador.
- [TARGET_ROM.md](docs/TARGET_ROM.md) — referência da versão do jogo.
- [WCH_SOURCES.md](docs/WCH_SOURCES.md) — fontes de investigação da memória.
