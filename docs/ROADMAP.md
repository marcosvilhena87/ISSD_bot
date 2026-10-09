# Roadmap — ISSD Bot

**Revisado em 09/10/2026.** Este documento separa **código existente**, **comportamento validado** e **integrações futuras**. Um módulo presente no repositório não significa que a jogada esteja correta em todos os cenários.

Legenda: `[x]` implementado ou observado no código; `[ ]` ainda pendente de implementação/validação suficiente. Os itens assinalados não equivalem a testes automatizados concluídos.

## Trilha A — Controlador Lua operacional (prioridade imediata)

### A0. Base de RAM e execução — implementada

- [x] Ler posições X/Y da bola e dos jogadores
- [x] Identificar jogador controlado e sinais individuais/de equipe de posse
- [x] Ler estados de jogo e distinguir gameplay ativo/inativo
- [x] Enviar comandos ao controle pelo BizHawk
- [x] Controlador modular via `tools/bizhawk/issd/main.lua`
- [x] HUD e eventos CSV para diagnóstico
- [ ] Auditar/validar placar e cronômetro como observações para RL
- [ ] Automatizar verificação de estabilidade dos endereços em reinícios/cenários distintos

### A1. Regras de jogo e táticas — módulos presentes, qualidade ainda em evolução

- [x] Aproximação da bola, controle de movimento e troca de jogador
- [x] Módulos de defesa, interceptação, ataque, passe e chute
- [x] Módulos de lateral, escanteio, falta e tiro de meta
- [x] Distribuição do goleiro e tratamento inicial de bola aérea
- [x] Contextos de posse física, voo da bola, transições e rebotes
- [ ] Validar robustez de cada tática por cenário e evidência de partida
- [ ] Medir gols, gols sofridos, perdas de posse, saídas de campo e decisões inválidas em amostras comparáveis

### A2. **Próximo marco: bola em disputa e mudança de posse confiável**

- [x] Registrar transições brutas de `Team_Ball_Possession` em frames ativos/inativos
- [x] Preservar histórico do último possuidor individual
- [x] Detectar candidatos a rebote com contexto cinemático perto do goleiro
- [ ] Etiquetar casos `CPU_UNOWNED_BALL ↔ MY_UNOWNED_BALL` como **sinal lógico**, não domínio confirmado
- [ ] Definir evidências e critérios para `LOOSE_BALL`, `CONTESTED_BALL`, `GK_REBOUND` e `CONTROL_CONFIRMED`
- [ ] Separar bola em voo/sem controle de bola alcançável e efetivamente disputável
- [ ] Conferir classificações contra sequências reais dos CSVs, incluindo tiro, defesa, rebote e recuperação
- [ ] Adicionar testes de regressão com entradas reproduzíveis e falsos positivos/negativos registrados
- [ ] Só depois conectar classificações validadas às decisões de ataque/defesa

**Critério de conclusão:** transições relevantes revisadas contra evidências por frame; relatórios permitem explicar por que cada classificação foi emitida; ausência de regressões conhecidas no conjunto de casos de teste. Não estabelecer taxa de acerto sem amostra rotulada.

### A3. Qualidade de jogo e instrumentação

- [ ] Criar suíte de cenários de reposição e jogo corrido (defesa, rebote, escanteio, lateral, falta)
- [ ] Quantificar desempenho antes/depois de cada alteração tática
- [ ] Isolar a política de decisão de leitura da RAM e efeitos no controle para facilitar testes
- [ ] Registrar métricas e versões de configuração usadas em avaliações
- [ ] Consolidar documentos operacionais defasados com a implementação real

## Trilha B — Ambiente de RL (futuro; não confundir com Lua atual)

### B0. Bridge determinística BizHawk ↔ Python

- [ ] Expor observações e comandos em protocolo documentado
- [ ] Implementar reset determinístico e condições de episódio
- [ ] Validar frame skip configurável e sincronização
- [ ] Garantir repetibilidade de cenários e seeds

### B1. Gymnasium

- [ ] `ISSDEnv` executável de ponta a ponta
- [ ] `observation_space` e `action_space` consistentes
- [ ] `step()`, `reset()`, recompensas, `terminated` e `truncated` validados
- [ ] Logging por episódio e testes de integração

### B2. Baseline e currículo

- [ ] Baseline reprodutível por regras ou ações simples
- [ ] Currículo: aproximar, recuperar, manter, progredir, passar, finalizar, defender
- [ ] Medir sucesso de cada etapa separadamente
- [ ] Ajustar recompensas para evitar exploits e comportamentos artificiais

### B3. PPO e avaliação

- [ ] Treinamento reproduzível com PyTorch/Stable-Baselines3
- [ ] Checkpoints, seeds e experimentos rastreáveis
- [ ] Avaliação fora do treino contra baseline fixo
- [ ] Métricas de resultado e taxa de regressão

### B4. Self-play e extensões

- [ ] Pool de adversários e snapshots de políticas
- [ ] Elo interno e prevenção de regressão/exploits
- [ ] Behavioral cloning, políticas recorrentes e RL hierárquico (pesquisa)
- [ ] Experimento comparativo com visão por pixels

## Ordem de execução recomendada

**A2 → A3 → B0 → B1 → B2 → B3 → B4.** Priorizar correção observável da interpretação da bola e métricas antes de iniciar treinamento: RL não resolve automaticamente erros de estado ou rotulagem de posse.

Referências: [README](../README.md), [CSV_REPORT](CSV_REPORT.md), [LUA_ARCHITECTURE](LUA_ARCHITECTURE.md) e [RAM_MAP](RAM_MAP.md).
