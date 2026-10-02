# Astra Mempool Pressure Service

Serviço HTTP local para fornecer métricas de congestionamento do Bitcoin a um Expert Advisor do MetaTrader 5. O servidor é implementado apenas com a biblioteca padrão do Python; a instalação como serviço usa o NSSM oficial como wrapper de serviço do Windows.

## Requisitos

- Windows 10 ou Windows 11, 64 bits.
- Python 3.10 ou superior, disponível pelo launcher `py` ou no `PATH`.
- Acesso HTTPS à Internet para consultar `mempool.space`.
- Permissão de Administrador para instalar ou remover o serviço.
- A porta TCP 8765 livre em `127.0.0.1`.

## Arquivos

- `astra_mempool_pressure_api.py`: servidor HTTP, coleta e cálculo das métricas.
- `config.json`: host, porta, frequência de atualização e nível de log.
- `install_service.bat`: copia a aplicação para `%ProgramFiles%`, baixa NSSM 2.24 do site oficial e registra/inicia o serviço.
- `uninstall_service.bat`: para e remove o serviço e a cópia instalada.
- `check_port.bat`: mostra estado, PID e nome do processo que escuta na porta 8765.
- `diagnose.bat`: verifica o SCM, porta/PID, faz chamadas locais e grava `logs\diagnose-report.txt`.
- `README.md`: esta documentação.

## Instalação como serviço

1. Mantenha os arquivos do pacote na mesma pasta.
2. Clique com o botão direito em `install_service.bat` e escolha **Executar como administrador**.
3. O instalador verifica Python 3.10+, cria `%ProgramFiles%\AstraMempoolService`, copia o script e `config.json`, detecta NSSM no diretório da instalação ou no `PATH`, e baixa o NSSM 2.24 oficial se necessário.
4. Ele registra `AstraMempoolService` com inicialização automática e configura três ações do SCM: primeira, segunda e terceira falhas reiniciam em 30 segundos. O NSSM também reinicia o processo monitorado com atraso de 30 segundos.
5. O instalador espera até 20 segundos pelo `/health`; se a aplicação não responder, informa falha de inicialização e remove o registro parcial do serviço.

O download do NSSM exige Internet e é feito de `https://nssm.cc/release/nssm-2.24.zip`. A aplicação instalada fica em `%ProgramFiles%\AstraMempoolService`; portanto, continua disponível sem depender da pasta de dados ou do login do MetaTrader. O instalador configura explicitamente a conta `LocalSystem`, sem senha por usuário. O endpoint fica acessível apenas na máquina local.

## Inicialização manual

Para executar sem instalar o serviço, abra um terminal na pasta dos arquivos e rode:

```powershell
python .\astra_mempool_pressure_api.py
```

O processo faz a primeira consulta imediatamente, inicia o listener local e repete a coleta a cada `refresh_seconds`. Use `Ctrl+C` para encerrar. No modo interativo, se a porta estiver ocupada, o programa mostra o nome do processo e PID e pergunta antes de executar `taskkill`. Sem terminal interativo (como no serviço), ele não encerra processos de terceiros: registra o conflito e aborta a inicialização.

## Configuração

Edite `config.json` antes da instalação. O instalador copia a configuração para `%ProgramFiles%\AstraMempoolService\config.json`; alterações posteriores devem ser feitas nessa cópia e o serviço reiniciado.

```json
{
  "host": "127.0.0.1",
  "port": 8765,
  "refresh_seconds": 60,
  "log_level": "INFO"
}
```

`host` precisa ser um endereço de loopback para impedir exposição na rede. `port` deve ficar entre 1 e 65535, `refresh_seconds` deve ser positivo e `log_level` pode ser `DEBUG`, `INFO`, `WARNING`, `ERROR` ou `CRITICAL`.

## API

### `GET /health`

Indica que o listener HTTP está atendendo e informa também o estado do polling. HTTP `200` com `status: "ok"` confirma que o processo responde; `data_success` indica se a coleta externa mais recente foi válida. O endpoint permanece vivo durante uma falha de Internet.

```json
{
  "status": "ok",
  "service": "AstraMempoolService",
  "port": 8765,
  "last_update": "2026-10-01T16:00:00+00:00",
  "uptime": 120.5,
  "last_attempt": "2026-10-01T16:00:00+00:00",
  "data_success": true,
  "polling_status": "running",
  "consecutive_failures": 0
}
```

### `GET /pressure`

Retorna sempre o contrato estável abaixo. `success` indica se a coleta mais recente foi válida. Em falhas de rede ou respostas inválidas, o endpoint continua respondendo HTTP 200 e fornece `success: false` com métricas zeradas.

```json
{
  "success": true,
  "pressure_index": 25,
  "state": "LOW",
  "momentum": 10,
  "acceleration": 1,
  "recommended_fee": 3,
  "mempool_size": 12345,
  "timestamp": 1234567890
}
```

O `timestamp` é Unix epoch em segundos. `mempool_size` é a quantidade de transações no pool, `recommended_fee` é a taxa `fastestFee` em sat/vB, e `momentum`/`acceleration` são diferenças entre leituras consecutivas (não normalizadas por segundo). Na primeira leitura, ambas são zero.

## Cálculo

A fórmula própria usa três componentes, cada um normalizado e limitado a 0–100:

- Taxa mais rápida recomendada: `fastestFee` sat/vB, peso 55%.
- Quantidade de transações: 300.000 transações correspondem a 100, peso 30%.
- `vsize` do mempool: 1.500.000.000 vbytes correspondem a 100, peso 15%.

A soma ponderada é arredondada para um inteiro entre 0 e 100. Os estados seguem estes intervalos inclusivos: 0–25 `LOW`, 26–50 `NORMAL`, 51–75 `HIGH`, 76–100 `EXTREME`. Momentum é a pressão atual menos a anterior; aceleração é o momentum atual menos o momentum anterior. Os dados vêm de `https://mempool.space/api/mempool` e `https://mempool.space/api/v1/fees/recommended`.

## Logs

O log da aplicação fica em `%ProgramFiles%\AstraMempoolService\logs\astra.log`. Ele registra inicialização, encerramento, consultas, chamadas HTTP e erros, com rotação em 5 MB e até cinco arquivos de backup. O NSSM mantém também `service-stdout.log` e `service-stderr.log` com rotação configurada em 5 MB.

## Testes

Com o serviço instalado ou o servidor manual em execução, rode em outro terminal:

```powershell
curl.exe http://127.0.0.1:8765/health
curl.exe http://127.0.0.1:8765/pressure
```

No Windows PowerShell, prefira `curl.exe`, porque `curl` pode ser um alias de `Invoke-WebRequest`. Para testar somente a porta, execute `check_port.bat`.

O script de diagnóstico pode ser executado em qualquer estado e sempre grava seu relatório em `logs\diagnose-report.txt`:

```bat
diagnose.bat
```

Para verificar manualmente o serviço e a porta:

```powershell
sc.exe query AstraMempoolService
netstat -ano | findstr 8765
```

## Configuração do MetaTrader 5

`WebRequest` só funciona quando cada host necessário é autorizado no terminal. No MT5, abra **Tools → Options → Expert Advisors → Allow WebRequest for listed URL** e adicione as duas entradas:

```text
http://127.0.0.1:8765
https://mempool.space
```

A primeira permite ao indicador chamar o serviço local. A segunda permite ao módulo BTC buscar preços diretamente do mempool.space. Depois clique em OK e reinicie o EA (remova e anexe novamente ao gráfico, ou reinicie o terminal).

### Corrigir `BTC_PRICE Error MT5=4014`

O código MT5 `4014` significa que o terminal recusou uma chamada `WebRequest` não autorizada; não indica falha do serviço local. Para corrigir:

1. Abra **Tools → Options → Expert Advisors**.
2. Habilite **Allow WebRequest for listed URL**.
3. Adicione exatamente `https://mempool.space` à lista. Mantenha também `http://127.0.0.1:8765` para o módulo Mempool.
4. Clique em OK e reinicie o EA.
5. Confira a aba **Experts**: o erro 4014 deve desaparecer e, separadamente, o indicador Mempool deve registrar resposta HTTP `200`.

O serviço local não consegue alterar essa lista do terminal; ela é uma configuração de segurança do MT5.

## Atualização

1. Prepare a nova versão dos arquivos do pacote na pasta de origem.
2. Execute `install_service.bat` como Administrador. O instalador tenta parar e remover a instância existente antes de registrar a nova e preserva a pasta de logs instalada.
3. Verifique o status com `sc.exe query AstraMempoolService` e teste `/health` e `/pressure`.

Para aplicar uma alteração somente no `config.json` instalado, edite `%ProgramFiles%\AstraMempoolService\config.json` como Administrador e reinicie o serviço:

```powershell
Restart-Service -Name AstraMempoolService
```

## Desinstalação

Execute `uninstall_service.bat` como Administrador. O serviço é parado e removido, uma tarefa agendada antiga com o nome do produto é removida se existir, e a instalação em `%ProgramFiles%\AstraMempoolService` (incluindo os logs) e arquivos temporários de instalação são apagados. Os arquivos originais do pacote não são removidos.

## Troubleshooting

- **Erro HTTP 1001 / sem conexão local:** `1001` não é um status HTTP normal do serviço; no wrapper MQL5 indica que não houve uma resposta HTTP válida. Execute `diagnose.bat`. Se `sc.exe query` disser que o serviço não existe, rode `install_service.bat` como Administrador. Se o serviço existir mas não houver listener, consulte os logs e valide `config.json`. Confirme que `/health` e `/pressure` retornam HTTP `200` com `curl.exe`.
- **Serviço ausente (SCM 1060):** significa que `AstraMempoolService` não foi registrado. Execute `install_service.bat` elevado; a API não inicia sozinha só por existir na pasta.
- **Python não encontrado ou versão antiga:** instale Python 3.10+ e habilite o launcher `py` ou a inclusão de Python no `PATH`; rode o instalador novamente.
- **Instalador requer Administrador:** ele cria serviço e grava em `%ProgramFiles%`; execute com elevação.
- **SCM 1069 / falha de logon:** o instalador usa `LocalSystem` para não depender da senha da conta pessoal. Para reparar um serviço existente como Administrador, rode `sc.exe config AstraMempoolService obj= LocalSystem`; depois libere a porta 8765 do processo manual e execute `install_service.bat` novamente.
- **Download do NSSM falha:** verifique conectividade/proxy e acesso HTTPS a `nssm.cc`; o serviço não será registrado sem o wrapper.
- **Porta ocupada:** rode `check_port.bat`. Para diagnóstico manual, execute `netstat -ano | findstr 8765` e consulte o nome com `tasklist /FI "PID eq <PID>"`. Finalize apenas se reconhecer o processo: `taskkill /F /PID <PID>`. O modo serviço não mata processos automaticamente.
- **Serviço não inicia:** consulte `sc.exe query AstraMempoolService`, `logs\astra.log`, `logs\service-stderr.log` e `logs\service-stdout.log` na pasta instalada. Confirme que `config.json` está válido e que `127.0.0.1:8765` está livre.
- **`/health` funciona, mas `success` é falso:** o servidor está vivo, mas uma consulta HTTPS falhou ou retornou dados inválidos. Verifique Internet, proxy/firewall e `astra.log`; uma nova tentativa ocorre após o intervalo de polling.
- **EA não acessa o endpoint:** confirme que está usando exatamente `http://127.0.0.1:8765/pressure` e adicione a URL à lista permitida de `WebRequest` no MT5.
- **Polling interrompido:** exceções são registradas com stack trace em JSON; após erro de rede o serviço repete a coleta com espera progressiva (10, 20, 40, 60 segundos no máximo) sem parar o HTTP listener. Se a thread morrer, um supervisor interno a cria novamente.
- **Recuperação do processo:** NSSM reinicia a aplicação se ela terminar; o Windows Service Control Manager está configurado para três reinicializações com atraso de 30 segundos. O health check distingue processo vivo de dados externos atualizados.
- **Erro `BTC_PRICE Error MT5=4014`:** siga a seção acima e autorize `https://mempool.space` em **Tools → Options → Expert Advisors → WebRequest**; depois reinicie o EA.
- **HTTP 404 no polling externo:** a rota de métricas do mempool é `/api/mempool` (não `/api/v1/mempool`); o script usa a rota documentada atual.
