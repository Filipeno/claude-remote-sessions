# The main menu. -Status prints the status and exits.
param([switch]$Status)
. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-UserFiles

function Show-Status {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    $auto = if (-not $task) { 'not installed' } elseif ($task.State -eq 'Disabled') { 'OFF' } else { 'ON' }
    $paused = if (Test-Path -LiteralPath $PauseFlag) { '  (paused by "Stop all sessions")' } else { '' }
    Write-Host ''
    Write-Host '  CLAUDE REMOTE SESSIONS' -ForegroundColor Cyan
    Write-Host "  Autostart: $auto$paused    Chrome: $((Get-Settings).Chrome)"
    Write-Host ''
    $folders = @(Get-Folders)
    if (-not $folders) { Write-Host '  No folders yet. Choose 3 to add one.' -ForegroundColor Yellow }
    foreach ($dir in $folders) {
        if ((Get-ServerState $dir) -eq 'alive') { Write-Host '  [running] ' -ForegroundColor Green -NoNewline }
        else { Write-Host '  [stopped] ' -ForegroundColor DarkGray -NoNewline }
        Write-Host $dir
    }
    Write-Host ''
}

function Invoke-Uninstall {
    if ((Read-Host 'Remove Claude Remote Sessions from this PC? (y/N)') -ne 'y') { return }
    if ((Read-Host 'Also stop the sessions that are running now? (y/N)') -eq 'y') { & (Join-Path $Root 'stop-remote-sessions.ps1') }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath('Programs')) 'Claude Remote Sessions.lnk') -ErrorAction SilentlyContinue
    if ($Root -eq (Join-Path $env:LOCALAPPDATA 'ClaudeRemoteSessions')) {
        Start-Process cmd.exe -WindowStyle Hidden -ArgumentList '/c', "timeout /t 2 >nul & rmdir /s /q `"$Root`""
        Write-Host 'Uninstalled. Bye!'
    } else {
        Write-Host "Uninstalled. You can delete the folder $Root yourself."
    }
    exit
}

if ($Status) { Show-Status; return }

while ($true) {
    Clear-Host
    Show-Status
    Write-Host '  1  Start sessions now'
    Write-Host '  2  Stop all sessions'
    Write-Host '  3  Add a folder'
    Write-Host '  4  Edit the folder list'
    Write-Host '  5  Turn autostart on/off'
    Write-Host '  6  Show the log'
    Write-Host '  7  Update'
    Write-Host '  8  Uninstall'
    Write-Host '  Q  Quit'
    Write-Host ''
    $choice = (Read-Host '  Choose').Trim().ToUpperInvariant()
    Write-Host ''
    switch ($choice) {
        '1' { & (Join-Path $Root 'start-remote-sessions.ps1') }
        '2' { & (Join-Path $Root 'stop-remote-sessions.ps1') }
        '3' { & (Join-Path $Root 'add-folder.ps1') }
        '4' { Start-Process notepad.exe -ArgumentList "`"$ListFile`"" -Wait; continue }
        '5' {
            $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            if (-not $task) { Register-Watchdog; Write-Host 'Autostart is ON.' }
            elseif ($task.State -eq 'Disabled') { Enable-ScheduledTask -TaskName $TaskName | Out-Null; Write-Host 'Autostart is ON.' }
            else { Disable-ScheduledTask -TaskName $TaskName | Out-Null; Write-Host 'Autostart is OFF. Running sessions keep running.' }
        }
        '6' { if (Test-Path -LiteralPath $LogFile) { Get-Content -LiteralPath $LogFile -Tail 30 -Encoding UTF8 } else { Write-Host 'The log is empty.' } }
        '7' {
            if (Test-Path -LiteralPath (Join-Path $Root '.git')) { git -C $Root pull }
            else { & ([scriptblock]::Create((Invoke-RestMethod 'https://raw.githubusercontent.com/Filipeno/claude-remote-sessions/main/install-online.ps1'))) }
            Write-Host 'Updated. Restart the menu to use the new version.'
        }
        '8' { Invoke-Uninstall }
        'Q' { exit }
        default { continue }
    }
    Write-Host ''
    Read-Host '  Press Enter to go back'
}
