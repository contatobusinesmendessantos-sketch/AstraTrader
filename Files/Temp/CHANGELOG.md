# Changelog

## 2026-10-01

- Adicionados logs JSON rotativos com stack traces completos, health check detalhado e supervisor de polling com retry progressivo.
- Melhorado o instalador NSSM com detecção/reuso, início automático, recuperação em três falhas e validação de `/health` após startup.
- Adicionado `diagnose.bat` para verificar serviço, porta, PID, endpoints e gerar relatório.
- Atualizado o cliente MQL5 para validar estado, métricas, números finitos e timestamp Unix; mensagens de erro local 1001 e `WebRequest` 4014 mais claras.
- Documentados instalação, diagnóstico, recuperação e autorização de URLs `http://127.0.0.1:8765` e `https://mempool.space` no MT5.
- Corrigido o endpoint público do tamanho do mempool para `/api/mempool` após confirmar que `/api/v1/mempool` retorna HTTP 404.
- Configurado o NSSM para executar como `LocalSystem`, evitando falha de logon 1069 causada por senha pessoal inválida.
