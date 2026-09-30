# Shared paths and helpers. Dot-sourced by the other scripts.
$Root = $PSScriptRoot
$ListFile = Join-Path $Root 'sessions.txt'
$SettingsFile = Join-Path $Root 'settings.psd1'
$LogFile = Join-Path $Root 'remote-sessions.log'
$PauseFlag = Join-Path $Root 'paused.flag'
$TaskName = 'Claude Remote Sessions'
$RepoZip = 'https://github.com/Filipeno/claude-remote-sessions/archive/refs/heads/main.zip'
$Utf8 = New-Object Text.UTF8Encoding $false

# Creates your personal files on first run. They are not part of the repo, so updates never overwrite them.
function Initialize-UserFiles {
    if (-not (Test-Path -LiteralPath $ListFile)) {
        [IO.File]::WriteAllText($ListFile, (
            "# Folders that get a Claude Remote Control session.`r`n" +
            "# One folder per line. Put # in front of a line to switch that folder off.`r`n" +
            "# Folders you trust in Claude Code are added automatically.`r`n"), $Utf8)
    }
    if (-not (Test-Path -LiteralPath $SettingsFile)) {
        [IO.File]::WriteAllText($SettingsFile, (
            "@{`r`n" +
            "    # Claude in Chrome for the sessions: 'auto' = Claude's own /chrome setting, 'on' = always, 'off' = never`r`n" +
            "    Chrome = 'auto'`r`n" +
            "}`r`n"), $Utf8)
    }
}

function Get-Settings {
    $s = @{ Chrome = 'auto' }
    try { $s = Import-PowerShellDataFile -LiteralPath $SettingsFile } catch {}
    return $s
}

function Find-Claude {
    $native = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path -LiteralPath $native) { return $native }
    $cmd = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-Folders {
    [IO.File]::ReadAllLines($ListFile, $Utf8) | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
}

function ConvertTo-Key($path) { $path.Trim().TrimStart('#').Trim().Replace('/', '\').TrimEnd('\').ToLowerInvariant() }

# Folders where the "Do you trust the files in this folder?" question was answered yes.
function Get-TrustedFolders {
    try {
        $cfg = [IO.File]::ReadAllText((Join-Path $env:USERPROFILE '.claude.json'), $Utf8) | ConvertFrom-Json
        $cfg.projects.PSObject.Properties | Where-Object { $_.Value.hasTrustDialogAccepted } |
            ForEach-Object { $_.Name.Replace('/', '\').TrimEnd('\') }
    } catch { @() }
}

# Remote Control servers: claude.exe (native install) or node.exe (npm install) running `remote-control` / `rc`.
function Get-RcProcesses {
    Get-CimInstance Win32_Process | Where-Object {
        $_.Name -in 'claude.exe', 'node.exe' -and $_.CommandLine -match 'claude' -and
        $_.CommandLine -match '\s(rc|remote-control)(\s|"|$)'
    }
}

# Each server records its pid in ~/.claude/projects/<folder>/bridge-pointer.json. Returns alive, dead or none.
function Get-ServerState($dir) {
    $pointer = Join-Path $env:USERPROFILE ('.claude\projects\' + ($dir.TrimEnd('\') -replace '[^A-Za-z0-9]', '-') + '\bridge-pointer.json')
    if (-not (Test-Path -LiteralPath $pointer)) { return 'none' }
    try {
        $srvPid = ([IO.File]::ReadAllText($pointer, $Utf8) | ConvertFrom-Json).pid
        if (Get-RcProcesses | Where-Object ProcessId -eq $srvPid) { return 'alive' }
    } catch {}
    return 'dead'
}

# At logon + every 15 min, headless (conhost --headless), so no window ever flashes.
function Register-Watchdog {
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $action = New-ScheduledTaskAction -Execute 'conhost.exe' -WorkingDirectory $Root -Argument (
        "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Root\start-remote-sessions.ps1`" -Watchdog")
    $triggers = @(
        (New-ScheduledTaskTrigger -AtLogOn -User $user),
        (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15))
    )
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Settings $settings -Principal $principal `
        -Description "Starts Claude Remote Control sessions ($Root)." -Force | Out-Null
}
