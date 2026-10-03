# PROTOCOLO OFICIAL — DESAFIOS E CORREÇÕES DO ASTRATRADER

**Objetivo:** conduzir o AstraTrader até produção por etapas controladas, preservando sua arquitetura, segurança, rastreabilidade e comportamento operacional.

## ETAPA 1 — AUDITORIA DA ARQUITETURA REAL
**Desafio:** comprovar que o fluxo executado pelo código corresponde à arquitetura projetada.

Verificar:

- AstraTrader.mq5
- Include/AstraTrader/**
- fluxo completo do AstraPipeline
- AnalysisContext como fonte única de verdade
- contratos entre todos os módulos
- ordem real das etapas
- entradas, saídas e estados de cada Gate

**Critério de conclusão:** arquitetura real documentada e inconsistências comprovadas.

---

## ETAPA 2 — CONSISTÊNCIA E DUPLA CONTAGEM DE EVIDÊNCIAS
**Desafio:** impedir que a mesma informação seja contabilizada várias vezes e distorça a decisão.

Verificar especialmente:

- Structure
- FVG
- Order Block
- Smart Money
- Liquidity
- Wyckoff
- Market Evidence
- Prediction
- MarketDecisionEngine

Verificar também:

- sobreposição de sinais
- evidências derivadas umas das outras
- pesos duplicados
- conflitos de classificação
- coerência de confidence, consensus e confluence

**Critério de conclusão:** cada evidência possui função clara e não gera vantagem artificial por dupla contagem.

---

## ETAPA 3 — INTEGRIDADE DOS GATES
**Desafio:** garantir que nenhum estágio de autorização possa ser contornado.

Fluxo obrigatório:

**Decision → Signal Validation → Risk → Exposure → Position Gate → Trade Validation → Execution → Execution Confirmation**

Verificar:

- bloqueios
- permissões
- estados internos
- condições de bypass
- inconsistências entre `approved`, `allowed`, `validated` e `confirmed`
- política SINGLE / HEDGE_ALLOWED / PYRAMID_LIMITED

**Critério de conclusão:** nenhuma ordem pode chegar à execução sem atravessar todos os controles obrigatórios.

---

## ETAPA 4 — INTEGRIDADE DOS DADOS E FONTES EXTERNAS
**Desafio:** impedir que dados inválidos, ausentes, atrasados ou inconsistentes contaminem a decisão.

Auditar:

- Market Data
- BTC
- On-Chain
- Quant
- Mempool
- timestamps
- dados opcionais
- estados de conexão
- stale data
- valores inválidos
- propagação de erros

Verificar especialmente:

- Mempool nunca decide direção sozinho
- dados externos opcionais não podem produzir sinais falsos
- dados inválidos devem ser identificados e tratados corretamente

**Critério de conclusão:** todo dado possui estado de validade claramente definido.

---

## ETAPA 5 — TELEMETRIA, SEMÂNTICA E RASTREABILIDADE
**Desafio:** garantir que logs, diagnósticos e nomes representem exatamente o que o código está fazendo.

Auditar:

- nomes de variáveis
- nomes de parâmetros
- indicadores
- logs
- diagnósticos
- estados
- métricas
- mensagens de auditoria

Investigar obrigatoriamente:

- comparação FVG/Order Block identificada anteriormente
- possíveis nomes semanticamente incorretos
- divergências entre cálculo e telemetria
- informações registradas que possam induzir diagnóstico errado

**Critério de conclusão:** o log deve permitir reconstruir por que uma decisão foi tomada ou bloqueada.

---

## ETAPA 6 — COMPILAÇÃO E VALIDAÇÃO NO MT5
**Desafio:** comprovar que o código corrigido funciona no ambiente real.

Executar:

- compilação MetaEditor
- zero errors
- zero warnings relevantes
- testes funcionais
- testes de integração
- testes de Gates
- validação de execução
- análise dos logs

Validar também:

- abertura de posição
- SL
- TP
- volume
- margem
- execução
- confirmação
- gerenciamento de posição

**Critério de conclusão:** comportamento observado no MT5 corresponde ao comportamento esperado pela arquitetura.

---

## ETAPA 7 — BACKTEST E HOMOLOGAÇÃO PARA PRODUÇÃO
**Desafio:** validar estabilidade e comportamento operacional antes da liberação.

Executar:

- backtests
- diferentes períodos
- diferentes regimes de mercado
- avaliação de drawdown
- estabilidade operacional
- comportamento dos Gates
- comportamento de risco
- consistência dos sinais
- testes controlados em ambiente real/simulado

Nenhuma alteração de produção deve ser considerada concluída apenas porque compila.

**Critério de conclusão:** AstraTrader aprovado tecnicamente para homologação e posterior produção.

---

## REGRA CENTRAL
As etapas devem ser executadas **sequencialmente**.

**Não pular etapas.**

Uma etapa só pode ser encerrada quando possuir evidências suficientes para demonstrar sua conclusão.

Nenhuma correção deve destruir ou contornar os contratos das etapas anteriores.

**AstraSentinel permanece fora do escopo do AstraTrader durante todo este protocolo.**

## REGRA DE CONSULTA E EXECUÇÃO PERMANENTE

Antes de qualquer futura correção, refatoração, alteração arquitetural, alteração de lógica, alteração de Gate, alteração de risco, alteração de execução, alteração de integração ou alteração de telemetria:

1. Consulte primeiro `.github/copilot-instructions.md` e este protocolo.
2. Identifique explicitamente qual etapa do protocolo a alteração afeta.
3. Comprove que os critérios das etapas anteriores foram atendidos antes de avançar.
4. Execute as etapas obrigatoriamente na sequência **ETAPA 1 → ETAPA 2 → ETAPA 3 → ETAPA 4 → ETAPA 5 → ETAPA 6 → ETAPA 7**.
5. Se uma instrução temporária conflitar com este protocolo permanente, destaque o conflito antes de alterar qualquer código.
6. Para uma correção fora do escopo descrito, registre previamente a etapa afetada, o contrato arquitetural que será alterado, os riscos e os testes necessários.

## REGRA DE PROTEÇÃO

Nunca:

- misture AstraSentinel ao AstraTrader;
- altere arquitetura sem evidência;
- remova módulos sem comprovar que estão fora do fluxo;
- altere parâmetros de estratégia/risco sem autorização específica;
- permita bypass de Gates;
- introduza dupla contagem de evidências;
- trate dados externos inválidos como dados válidos;
- considere “compila” como equivalente a “está pronto para produção”.

## REGRA DE MEMÓRIA

Este protocolo salvo no repositório é a fonte permanente de referência do projeto. Em futuras sessões, antes de modificar o AstraTrader, leia e siga `.github/copilot-instructions.md` e este documento.
