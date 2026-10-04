# Starts a hidden `claude remote-control` in every folder listed in sessions.txt.
# - Folders you have trusted in Claude Code are added to sessions.txt automatically, unless the list already has them
#   (a line switched off with # counts, so switched-off folders stay off).
# - Folders whose server is still alive are skipped. A server that died is reattached with --continue when possible.
# -Watchdog: used by the scheduled task. Does nothing while "Stop all sessions" has paused it.
param([switch]$Watchdog)
. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-UserFiles

function Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $(if ($Watchdog) {'[watchdog]'} else {'[manual]'}) $msg"
    Write-Host $line
    [IO.File]::AppendAllText($LogFile, "$line`r`n", $Utf8)
}

# The pause lasts until a manual start or the next reboot.
if (Test-Path -LiteralPath $PauseFlag) {
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    if ($Watchdog -and (Get-Item -LiteralPath $PauseFlag).LastWriteTime -gt $boot) { exit 0 }
    Remove-Item -LiteralPath $PauseFlag
}

$claude = Find-Claude
if (-not $claude) { Log 'FAILED: Claude Code is not installed (no `claude` command found).'; exit 1 }

# Wait (up to 2 min) for the network, since this also runs right after login.
for ($i = 0; $i -lt 24; $i++) {
    try { [void][Net.Dns]::GetHostAddresses('api.anthropic.com'); break } catch { Start-Sleep 5 }
}

# Add newly trusted folders to sessions.txt.
$known = @([IO.File]::ReadAllLines($ListFile, $Utf8) | Where-Object { $_.Trim() } | ForEach-Object { ConvertTo-Key $_ })
foreach ($dir in Get-TrustedFolders) {
    $key = ConvertTo-Key $dir
    if ($known -contains $key) { continue }
    if ($dir.Length -le 3 -or -not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
    if ($key -eq (ConvertTo-Key $env:USERPROFILE) -or $key.StartsWith((ConvertTo-Key $env:TEMP)) -or
        $key.StartsWith('c:\tmp') -or $key.Contains('\.claude\worktrees\')) { continue }
    $text = [IO.File]::ReadAllText($ListFile, $Utf8)
    $sep = if ($text -and -not $text.EndsWith("`n")) { "`r`n" } else { '' }
    [IO.File]::AppendAllText($ListFile, "$sep$dir`r`n", $Utf8)
    $known += $key
    Log "Added (trusted in Claude): $dir"
}

$chromeArg = switch ((Get-Settings).Chrome) { 'on' { @('--chrome') } 'off' { @('--no-chrome') } default { @() } }

function Start-Server($dir, [string[]]$extra) {
    $p = Start-Process $claude -WorkingDirectory $dir -WindowStyle Hidden -PassThru `
        -ArgumentList (@('remote-control') + $chromeArg + $extra)
    return -not $p.WaitForExit(15000)
}

foreach ($dir in Get-Folders) {
    if (-not (Test-Path -LiteralPath $dir)) { Log "Missing folder: $dir"; continue }
    if ((Get-ServerState $dir) -eq 'alive') {
        Save-Pointer $dir
        if (-not $Watchdog) { Write-Host "Already running: $dir" }
        continue
    }

    # Reattach to the last session so the app doesn't get a new duplicate entry; start a new one only if that fails.
    if ((Restore-Pointer $dir) -and (Start-Server $dir @('--continue'))) { Log "Reattached: $dir" }
    elseif (Start-Server $dir @()) { Log "Started new session: $dir" }
    else { Log "FAILED: $dir. Is the folder trusted, and are you logged in? Use 'Add a folder' in the menu to fix trust."; continue }
    Save-Pointer $dir
}
