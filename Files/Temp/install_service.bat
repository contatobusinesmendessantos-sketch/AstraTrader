@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Astra Mempool Pressure Service Installer

set "SERVICE_NAME=AstraMempoolService"
set "INSTALL_DIR=%ProgramFiles%\AstraMempoolService"
set "SOURCE_DIR=%~dp0"
set "STAGING_DIR=%TEMP%\AstraMempoolService_NSSM_%RANDOM%"
set "NSSM_URL=https://nssm.cc/release/nssm-2.24.zip"
set "PYTHON_EXE="
set "NSSM_SOURCE="

rem Service installation changes machine-wide configuration and requires elevation.
net session >nul 2>&1
if errorlevel 1 (
    echo ERRO: execute este instalador como Administrador.
    echo Clique com o botao direito em install_service.bat e escolha Executar como administrador.
    exit /b 1
)

rem Select the newest Python from the launcher, then validate Python 3.10+ below.
where py >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%P in ('py -3 -c "import sys;print(sys.executable)" 2^>nul') do set "PYTHON_EXE=%%P"
)
if not defined PYTHON_EXE (
    where python >nul 2>&1
    if not errorlevel 1 (
        for /f "delims=" %%P in ('python -c "import sys;print(sys.executable)" 2^>nul') do set "PYTHON_EXE=%%P"
    )
)
if not defined PYTHON_EXE (
    echo ERRO: Python 3.10 ou superior nao foi encontrado no PATH nem pelo launcher py.
    echo Instale Python 3.10+ e marque a opcao para adiciona-lo ao PATH.
    exit /b 1
)
"%PYTHON_EXE%" -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)"
if errorlevel 1 (
    echo ERRO: versao encontrada ^(%PYTHON_EXE%^) e inferior a Python 3.10.
    exit /b 1
)
echo Python: %PYTHON_EXE%

if not exist "%SOURCE_DIR%astra_mempool_pressure_api.py" (
    echo ERRO: astra_mempool_pressure_api.py nao esta ao lado deste instalador.
    exit /b 1
)
if not exist "%SOURCE_DIR%config.json" (
    echo ERRO: config.json nao esta ao lado deste instalador.
    exit /b 1
)

rem Update path: stop/remove an existing service before replacing its executable.
if exist "%INSTALL_DIR%\nssm.exe" (
    "%INSTALL_DIR%\nssm.exe" stop "%SERVICE_NAME%" >nul 2>&1
    "%INSTALL_DIR%\nssm.exe" remove "%SERVICE_NAME%" confirm >nul 2>&1
) else (
    sc.exe stop "%SERVICE_NAME%" >nul 2>&1
)
sc.exe delete "%SERVICE_NAME%" >nul 2>&1
for /l %%N in (1,1,10) do (
    sc.exe query "%SERVICE_NAME%" >nul 2>&1
    if errorlevel 1 goto :old_service_removed
    timeout /t 1 /nobreak >nul
)
sc.exe query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo ERRO: o Windows ainda nao liberou o servico existente.
    exit /b 1
)
:old_service_removed

rem Install the application and reuse a detected NSSM before downloading it.
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if errorlevel 1 goto :failed
if not exist "%INSTALL_DIR%\logs" mkdir "%INSTALL_DIR%\logs"
if errorlevel 1 goto :failed
if not exist "%STAGING_DIR%" mkdir "%STAGING_DIR%"
if errorlevel 1 goto :failed
copy /Y "%SOURCE_DIR%astra_mempool_pressure_api.py" "%INSTALL_DIR%\astra_mempool_pressure_api.py" >nul
if errorlevel 1 goto :failed
copy /Y "%SOURCE_DIR%config.json" "%INSTALL_DIR%\config.json" >nul
if errorlevel 1 goto :failed

if exist "%INSTALL_DIR%\nssm.exe" goto :nssm_ready
for %%I in (nssm.exe) do set "NSSM_SOURCE=%%~$PATH:I"
if defined NSSM_SOURCE (
    echo NSSM detectado no PATH: %NSSM_SOURCE%
    copy /Y "%NSSM_SOURCE%" "%INSTALL_DIR%\nssm.exe" >nul
    if errorlevel 1 goto :failed
    goto :nssm_ready
)
echo NSSM nao encontrado; baixando NSSM 2.24 oficial.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%NSSM_URL%' -OutFile '%STAGING_DIR%\nssm.zip'; Expand-Archive -LiteralPath '%STAGING_DIR%\nssm.zip' -DestinationPath '%STAGING_DIR%' -Force; Copy-Item -LiteralPath '%STAGING_DIR%\nssm-2.24\win64\nssm.exe' -Destination '%INSTALL_DIR%\nssm.exe' -Force"
if errorlevel 1 goto :failed
:nssm_ready

rem Register NSSM as the Windows service wrapper and configure automatic recovery.
"%INSTALL_DIR%\nssm.exe" install "%SERVICE_NAME%" "%PYTHON_EXE%" "%INSTALL_DIR%\astra_mempool_pressure_api.py"
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" DisplayName "Astra Mempool Pressure Service"
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" Description "Bitcoin Mempool Pressure Provider for MetaTrader 5"
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppDirectory "%INSTALL_DIR%"
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" Start SERVICE_AUTO_START
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppExit Default Restart
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppRestartDelay 30000
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppStdout "%INSTALL_DIR%\logs\service-stdout.log"
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppStderr "%INSTALL_DIR%\logs\service-stderr.log"
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppRotateFiles 1
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppRotateOnline 1
if errorlevel 1 goto :failed
"%INSTALL_DIR%\nssm.exe" set "%SERVICE_NAME%" AppRotateBytes 5242880
if errorlevel 1 goto :failed
sc.exe description "%SERVICE_NAME%" "Bitcoin Mempool Pressure Provider for MetaTrader 5" >nul
if errorlevel 1 goto :failed
sc.exe config "%SERVICE_NAME%" start= auto >nul
if errorlevel 1 goto :failed
sc.exe failure "%SERVICE_NAME%" reset= 86400 actions= restart/30000/restart/30000/restart/30000 >nul
if errorlevel 1 goto :failed
sc.exe failureflag "%SERVICE_NAME%" 1 >nul
if errorlevel 1 goto :failed

"%INSTALL_DIR%\nssm.exe" start "%SERVICE_NAME%"
if errorlevel 1 goto :failed
for /l %%N in (1,1,20) do (
    sc.exe query "%SERVICE_NAME%" | findstr /I "RUNNING" >nul
    if not errorlevel 1 (
        powershell.exe -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8765/health' -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>&1
        if not errorlevel 1 goto :health_ready
    )
    timeout /t 1 /nobreak >nul
)
echo ERRO: o servico iniciou, mas /health nao respondeu dentro de 20 segundos.
goto :failed
:health_ready

echo.
echo Servico instalado e iniciado: %SERVICE_NAME%
echo Aplicacao: %INSTALL_DIR%
echo Logs: %INSTALL_DIR%\logs\astra.log
echo Endpoint: http://127.0.0.1:8765/health
echo.
sc.exe query "%SERVICE_NAME%"
powershell.exe -NoProfile -Command "Remove-Item -LiteralPath '%STAGING_DIR%' -Recurse -Force -ErrorAction SilentlyContinue" >nul 2>&1
exit /b 0

:failed
echo.
echo ERRO: instalacao nao concluida.
echo Consulte a mensagem acima. Para uma atualizacao interrompida, execute novamente como Administrador.
if exist "%INSTALL_DIR%\nssm.exe" (
    "%INSTALL_DIR%\nssm.exe" stop "%SERVICE_NAME%" >nul 2>&1
    "%INSTALL_DIR%\nssm.exe" remove "%SERVICE_NAME%" confirm >nul 2>&1
)
sc.exe delete "%SERVICE_NAME%" >nul 2>&1
powershell.exe -NoProfile -Command "Remove-Item -LiteralPath '%STAGING_DIR%' -Recurse -Force -ErrorAction SilentlyContinue" >nul 2>&1
exit /b 1
