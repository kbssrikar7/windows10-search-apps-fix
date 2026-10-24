<#
.SYNOPSIS
    Undoes Fix-SearchApps.ps1 by putting the backed-up Windows Search app data back.

.PARAMETER BackupPath
    The backup folder printed by Fix-SearchApps.ps1
    (%LOCALAPPDATA%\SearchAppsFix-Backup-<timestamp>).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Restore-SearchApps.ps1 -BackupPath "$env:LOCALAPPDATA\SearchAppsFix-Backup-20261024-101500"
#>
param([Parameter(Mandatory)][string]$BackupPath)

$ErrorActionPreference = 'Stop'

$pkg = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.Windows.Search_cw5n1h2txyewy'
if (-not (Test-Path $BackupPath)) { Write-Warning "Backup not found: $BackupPath"; exit 1 }

foreach ($subDir in Get-ChildItem $BackupPath -Directory) {
    $dst = Join-Path $pkg $subDir.Name
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    foreach ($item in Get-ChildItem $subDir.FullName -Force) {
        Stop-Process -Name SearchApp -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        $target = Join-Path $dst $item.Name
        # Data rebuilt since the fix ran is replaced by the backed-up copy.
        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        Move-Item $item.FullName $dst -Force
        Write-Host "restored $($subDir.Name)\$($item.Name)"
    }
}

Stop-Process -Name SearchApp -Force -ErrorAction SilentlyContinue
Write-Host "Restored. Open search again to load the previous data." -ForegroundColor Green
