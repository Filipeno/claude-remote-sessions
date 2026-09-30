# Stops every Claude Remote Control server and the sessions it spawned.
# Also pauses the watchdog so it doesn't restart them. The pause ends at the next reboot or a manual start.
. (Join-Path $PSScriptRoot 'common.ps1')
Set-Content -LiteralPath $PauseFlag -Value (Get-Date -Format s)

$servers = @(Get-RcProcesses)
foreach ($s in $servers) {
    taskkill /PID $s.ProcessId /T /F 2>&1 | Out-Null
    Write-Host "Stopped remote-control server $($s.ProcessId)"
}
if (-not $servers) { Write-Host 'No remote sessions were running.' }
Write-Host 'Paused until the next reboot or "Start sessions now".'
