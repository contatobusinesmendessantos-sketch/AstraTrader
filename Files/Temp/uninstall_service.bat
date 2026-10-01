@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Astra Mempool Pressure Service Uninstaller

set "SERVICE_NAME=AstraMempoolService"
set "INSTALL_DIR=%ProgramFiles%\AstraMempoolService"
set "STAGING_DIR=%TEMP%\AstraMempoolService_NSSM_*"

rem Removing a Windows service and its Program Files installation requires elevation.
net session >nul 2>&1
if errorlevel 1 (
    echo ERRO: execute este desinstalador como Administrador.
    echo Clique com o botao direito em uninstall_service.bat e escolha Executar como administrador.
    exit /b 1
)

sc.exe query "%SERVICE_NAME%" | findstr /I "SERVICE_NAME" >nul
if not errorlevel 1 (
    if exist "%INSTALL_DIR%\nssm.exe" (
        "%INSTALL_DIR%\nssm.exe" stop "%SERVICE_NAME%" >nul 2>&1
    ) else (
        sc.exe stop "%SERVICE_NAME%" >nul 2>&1
    )
    for /l %%N in (1,1,10) do (
        sc.exe query "%SERVICE_NAME%" | findstr /I "STOPPED" >nul
        if errorlevel 1 timeout /t 1 /nobreak >nul
    )
    sc.exe query "%SERVICE_NAME%" | findstr /I "STOPPED" >nul
    if errorlevel 1 (
        echo ERRO: o servico nao parou; os arquivos instalados foram preservados.
        exit /b 1
    )
    if exist "%INSTALL_DIR%\nssm.exe" (
        "%INSTALL_DIR%\nssm.exe" remove "%SERVICE_NAME%" confirm
    )
    sc.exe delete "%SERVICE_NAME%" >nul 2>&1
)
for /l %%N in (1,1,10) do (
    sc.exe query "%SERVICE_NAME%" >nul 2>&1
    if errorlevel 1 goto :service_removed
    timeout /t 1 /nobreak >nul
)
sc.exe query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo ERRO: o Windows ainda registra o servico; os arquivos instalados foram preservados.
    exit /b 1
)
:service_removed

rem The installer creates no scheduled tasks; remove a legacy task with this product name if present.
schtasks.exe /Delete /TN "\AstraMempoolService" /F >nul 2>&1

rem Remove installer staging files and the installed copy, including its logs.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { Get-ChildItem -Path '%TEMP%' -Directory -Filter 'AstraMempoolService_NSSM_*' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; if (Test-Path -LiteralPath '%INSTALL_DIR%') { Remove-Item -LiteralPath '%INSTALL_DIR%' -Recurse -Force }; if (Test-Path -LiteralPath '%INSTALL_DIR%') { exit 1 } } catch { exit 1 }"
if errorlevel 1 (
    echo AVISO: nao foi possivel remover todos os arquivos instalados.
    exit /b 1
)
echo Servico removido e arquivos instalados limpos.
echo Os arquivos originais deste pacote nao foram removidos.
exit /b 0
