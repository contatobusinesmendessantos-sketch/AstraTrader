@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Astra Mempool Service Diagnostics
set "ROOT=%~dp0"
set "LOG_DIR=%ROOT%logs"
set "REPORT=%LOG_DIR%\diagnose-report.txt"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
(
    echo Astra Mempool Pressure Service - Diagnostic Report
    echo Generated: %DATE% %TIME%
    echo Computer: %COMPUTERNAME%
    echo.
    echo ==== Windows service ====
    sc.exe query AstraMempoolService
    echo.
    echo ==== TCP listener / port 8765 ====
    netstat -ano -p tcp | findstr LISTENING | findstr ":8765"
    echo.
    echo ==== Listener PID and process ====
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$connections = @(Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue); if ($connections.Count -eq 0) { Write-Output 'No process is listening on TCP 8765.' } else { $connections | ForEach-Object { $process = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue; [PSCustomObject]@{Port=$_.LocalPort; State=$_.State; PID=$_.OwningProcess; Process=$(if ($process) {$process.ProcessName} else {'unknown'})} } | Format-Table -AutoSize | Out-String }"
    echo.
) > "%REPORT%" 2>&1

(
    echo ==== HTTP GET /health ====
) >> "%REPORT%" 2>&1
where.exe curl.exe >nul 2>&1
if errorlevel 1 (
    echo curl.exe not found; use Windows 10/11 curl or PowerShell Invoke-WebRequest.>> "%REPORT%"
) else (
    curl.exe --silent --show-error --include --max-time 5 "http://127.0.0.1:8765/health" >> "%REPORT%" 2>&1
    set "HEALTH_EXIT=!ERRORLEVEL!"
)
if not defined HEALTH_EXIT set "HEALTH_EXIT=127"
if not "!HEALTH_EXIT!"=="0" echo /health request failed with curl exit code !HEALTH_EXIT!.>> "%REPORT%"
(
    echo.
    echo ==== HTTP GET /pressure ====
) >> "%REPORT%" 2>&1
where.exe curl.exe >nul 2>&1
if errorlevel 1 (
    echo /pressure not executed because curl.exe is unavailable.>> "%REPORT%"
) else (
    curl.exe --silent --show-error --include --max-time 5 "http://127.0.0.1:8765/pressure" >> "%REPORT%" 2>&1
    set "PRESSURE_EXIT=!ERRORLEVEL!"
)
if defined PRESSURE_EXIT if not "!PRESSURE_EXIT!"=="0" echo /pressure request failed with curl exit code !PRESSURE_EXIT!.>> "%REPORT%"
(
    echo.
    echo ==== Application log ====
    echo %ROOT%logs\astra.log
    if exist "%ROOT%logs\astra.log" powershell.exe -NoProfile -Command "Get-Content -LiteralPath '%ROOT%logs\astra.log' -Tail 80"
) >> "%REPORT%" 2>&1

echo Relatorio gerado em: "%REPORT%"
echo.
type "%REPORT%"
exit /b 0
