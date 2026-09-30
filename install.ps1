# Installs from this folder: autostart task, Start Menu shortcut, first folders. Safe to run again (it updates).
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'

Write-Host ''
Write-Host '  Installing Claude Remote Sessions...' -ForegroundColor Cyan
if (-not (Find-Claude)) {
    Write-Host ''
    Write-Host '  Claude Code is not installed yet. Install it first:' -ForegroundColor Yellow
    Write-Host '    https://claude.com/claude-code'
    Write-Host '  Then run `claude` once in a terminal and log in, and run this installer again.'
    exit 1
}
Initialize-UserFiles

# Autostart: at login + a watchdog every 15 min. Replaces the old Startup-folder shortcut if there is one.
Register-Watchdog
Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath('Startup')) 'Claude Remote Sessions.lnk') -ErrorAction SilentlyContinue

# Start Menu shortcut to the menu.
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) 'Claude Remote Sessions.lnk'))
$sc.TargetPath = 'powershell.exe'
$sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Root\menu.ps1`""
$sc.WorkingDirectory = $Root
$sc.Description = 'Start, stop and manage your Claude remote sessions'
$sc.Save()

$ErrorActionPreference = 'Continue'
Write-Host '  Starting your sessions (folders you trust in Claude Code are added automatically)...'
& (Join-Path $Root 'start-remote-sessions.ps1')

if (-not @(Get-Folders)) {
    Write-Host ''
    Write-Host '  No folders yet. Pick the first folder you want a remote session for.' -ForegroundColor Yellow
    & (Join-Path $Root 'add-folder.ps1')
}

& (Join-Path $Root 'menu.ps1') -Status
Write-Host '  Done! Open "Claude Remote Sessions" from the Start Menu to manage it.' -ForegroundColor Green
Write-Host '  Your sessions appear at claude.ai/code and in the Claude app.'
Write-Host ''
