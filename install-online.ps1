# One-line install / update:
#   irm https://raw.githubusercontent.com/Filipeno/claude-remote-sessions/main/install-online.ps1 | iex
# Downloads the latest version into %LOCALAPPDATA%\ClaudeRemoteSessions and runs install.ps1.
# Your folder list, settings and log are not in the download, so updating keeps them.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$dest = Join-Path $env:LOCALAPPDATA 'ClaudeRemoteSessions'
$zip = Join-Path $env:TEMP 'claude-remote-sessions.zip'
$tmp = Join-Path $env:TEMP ('claude-remote-sessions-' + [guid]::NewGuid())

Write-Host 'Downloading Claude Remote Sessions...'
Invoke-WebRequest 'https://github.com/Filipeno/claude-remote-sessions/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
Expand-Archive -LiteralPath $zip -DestinationPath $tmp
$src = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Path (Join-Path $src.FullName '*') -Destination $dest -Recurse -Force
Remove-Item -LiteralPath $zip, $tmp -Recurse -Force

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dest 'install.ps1')
