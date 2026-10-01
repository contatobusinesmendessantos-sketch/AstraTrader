@echo off
setlocal EnableExtensions DisableDelayedExpansion
echo Verificacao da porta TCP 8765
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$connections = @(Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue); if ($connections.Count -eq 0) { Write-Output 'Porta: 8765'; Write-Output 'Estado: LIVRE' } else { $connections | ForEach-Object { $process = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue; [PSCustomObject]@{Porta=$_.LocalPort; Estado=$_.State; PID=$_.OwningProcess; Processo=$(if ($process) {$process.ProcessName} else {'desconhecido'})} } | Format-Table -AutoSize }"
echo.
echo Diagnostico alternativo:
netstat -ano -p tcp | findstr LISTENING | findstr ":8765"
exit /b 0
