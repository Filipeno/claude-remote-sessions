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

function Start-Server($dir) {
    Start-Process $claude -WorkingDirectory $dir -WindowStyle Hidden -PassThru -ArgumentList (@('remote-control') + $chromeArg)
}

# Always a fresh server: `--continue` would reattach the old chat, but in "Single session" mode (one chat, no new
# ones). A fresh server allows many chats, at the cost of a new sidebar section after each restart.
# All folders start at once; a server still running after 15 s counts as started. Failed ones get one retry
# after 20 s, which covers the server side still holding the folder briefly after the old server died.
$pending = @{}
$loginChecked = $false
foreach ($dir in Get-Folders) {
    if (-not (Test-Path -LiteralPath $dir)) { Log "Missing folder: $dir"; continue }
    if ((Get-ServerState $dir) -eq 'alive') { if (-not $Watchdog) { Write-Host "Already running: $dir" }; continue }

    # Nothing can start while Claude Code is logged out, and every folder would report a misleading "FAILED".
    # Check once, only when something has to start, and log the problem once instead of every 15 minutes.
    if (-not $loginChecked) {
        $loginChecked = $true
        if (-not (Test-ClaudeLoggedIn)) {
            $msg = 'NOT LOGGED IN: Claude Code is signed out, so no sessions can start. Open PowerShell, run: claude auth login'
            $last = if (Test-Path -LiteralPath $LogFile) { Get-Content -LiteralPath $LogFile -Tail 1 -Encoding UTF8 } else { '' }
            if ($last -notlike "*$msg") { Log $msg } else { Write-Host $msg }
            exit 1
        }
    }
    $pending[$dir] = Start-Server $dir
}
for ($attempt = 1; $pending.Count -and $attempt -le 2; $attempt++) {
    Start-Sleep 15
    foreach ($dir in @($pending.Keys)) {
        if (-not $pending[$dir].HasExited) { Log "Started: $dir"; $pending.Remove($dir) }
        elseif ($attempt -eq 2) { Log "FAILED: $dir. Is the folder trusted, and are you logged in? Use 'Add a folder' in the menu to fix trust." }
    }
    if ($attempt -eq 1 -and $pending.Count) {
        Start-Sleep 5
        foreach ($dir in @($pending.Keys)) { $pending[$dir] = Start-Server $dir }
    }
}
