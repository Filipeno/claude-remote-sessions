# Adds a folder to sessions.txt (folder picker if no path is given), makes sure Claude trusts it, and starts it.
param([string]$Path)
. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-UserFiles

if (-not $Path) {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Pick a folder for a Claude remote session'
    if ($dlg.ShowDialog() -ne 'OK') { Write-Host 'Cancelled.'; return }
    $Path = $dlg.SelectedPath
}
$Path = $Path.TrimEnd('\')
if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Host "Not a folder: $Path"; return }
$key = ConvertTo-Key $Path

# Add it, or switch it back on if it was switched off with #.
$lines = [Collections.Generic.List[string]][IO.File]::ReadAllLines($ListFile, $Utf8)
$i = [array]::FindIndex($lines.ToArray(), [Predicate[string]] { param($l) $l.Trim() -and (ConvertTo-Key $l) -eq $key })
if ($i -ge 0) { $lines[$i] = $Path } else { $lines.Add($Path) }
[IO.File]::WriteAllLines($ListFile, $lines, $Utf8)
Write-Host "In the list: $Path"

# Remote Control only runs in folders Claude trusts. Let the user answer that question themselves.
if (-not (Get-TrustedFolders | Where-Object { (ConvertTo-Key $_) -eq $key })) {
    $claude = Find-Claude
    if (-not $claude) { Write-Host 'Claude Code is not installed.'; return }
    Write-Host ''
    Write-Host 'Claude has to trust this folder once. A Claude window opens now:'
    Write-Host '  1. Answer YES to "Do you trust the files in this folder?"'
    Write-Host '  2. Type /exit (or close the window).'
    Start-Process powershell.exe -Wait -WorkingDirectory $Path -ArgumentList '-NoProfile', '-Command', "& '$claude'"
    if (-not (Get-TrustedFolders | Where-Object { (ConvertTo-Key $_) -eq $key })) {
        Write-Host 'The folder is still not trusted, so its session cannot start yet. Run "Add a folder" again to retry.'
        return
    }
}
& (Join-Path $Root 'start-remote-sessions.ps1')
