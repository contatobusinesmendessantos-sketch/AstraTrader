# AstraTrader — permanent engineering instructions

These instructions apply to all engineering work on AstraTrader in this repository.

Before any correction, refactoring, architectural or logic change, Gate, risk, execution, integration, or telemetry change:

1. Read [ASTRATRADER_PROTOCOL.md](./ASTRATRADER_PROTOCOL.md).
2. Identify and state which of its seven stages the work belongs to.
3. Confirm that the preceding stages have sufficient evidence to meet their completion criteria. Work must proceed in order: **Stage 1 → Stage 2 → Stage 3 → Stage 4 → Stage 5 → Stage 6 → Stage 7**. Do not skip or advance past an unproven stage.
4. If a temporary instruction conflicts with the permanent protocol, explain the conflict and do not modify code until it is resolved.
5. For work outside the protocol, record the affected stage, architectural contract being changed, risks, and required tests before implementation.

Preserve valid existing project instructions when updating these instructions. Treat [ASTRATRADER_PROTOCOL.md](./ASTRATRADER_PROTOCOL.md) as the permanent project reference in future sessions.

## Protection rules

- Keep AstraSentinel outside the AstraTrader scope.
- Do not change architecture without evidence.
- Do not remove modules without proving they are unreachable from the active flow and confirming scope.
- Do not change strategy or risk parameters without specific authorization.
- Never bypass required Gates.
- Do not introduce double-counted evidence.
- Never treat invalid external data as valid.
- Compilation alone does not establish readiness for production.
- Do not declare production readiness without the Stage 7 evidence and approval described in the protocol.
