<#
.SYNOPSIS
    Fixes Windows 10 Start search showing only files (no apps) by fully resetting
    the Windows Search app's per-user data.

.DESCRIPTION
    The Windows Search app (SearchApp.exe) keeps its own index of installed apps
    under %LOCALAPPDATA%\Packages\Microsoft.Windows.Search_cw5n1h2txyewy. When that
    data gets stuck, search keeps showing a stale app list (or none), so typing an
    app name returns files like "app.exe" instead of the app.

    This script moves (does not delete) the package's data into a backup folder so
    SearchApp rebuilds it from scratch the next time you open search. No admin
    rights needed. Nothing outside the Search app's own data folder is touched.

    Undo with Restore-SearchApps.ps1 -BackupPath <folder printed at the end>.

.PARAMETER DryRun
    Show what would be moved without changing anything.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Fix-SearchApps.ps1
#>
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

$os = [Environment]::OSVersion.Version
if ($os.Major -ne 10 -or $os.Build -ge 22000) {
    Write-Warning "This script targets Windows 10 (build < 22000). Detected build $($os.Build). Exiting."
    exit 1
}

$pkg = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.Windows.Search_cw5n1h2txyewy'
if (-not (Test-Path $pkg)) {
    Write-Warning "Search app data folder not found: $pkg"
    exit 1
}

# Folders that hold SearchApp state. Settings\settings.dat is the important one:
# resetting the other folders without it does not force a rebuild.
$subfolders = 'LocalState', 'Settings', 'AC', 'TempState', 'LocalCache'

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $env:LOCALAPPDATA "SearchAppsFix-Backup-$stamp"

Write-Host "Search app data: $pkg"
Write-Host "Backup folder:   $backup"
if ($DryRun) { Write-Host "`nDRY RUN - nothing will be moved.`n" -ForegroundColor Yellow }

$locked = @()
foreach ($sub in $subfolders) {
    $src = Join-Path $pkg $sub
    if (-not (Test-Path $src)) { continue }
    $dst = Join-Path $backup $sub
    foreach ($item in Get-ChildItem $src -Force) {
        if ($DryRun) { Write-Host "would move $sub\$($item.Name)"; continue }
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        # SearchApp respawns quickly and re-locks its files, so stop it before every move.
        Stop-Process -Name SearchApp -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        try {
            Move-Item $item.FullName $dst -Force
            Write-Host "moved $sub\$($item.Name)"
        } catch {
            $locked += "$sub\$($item.Name)"
            Write-Warning "locked, skipped: $sub\$($item.Name)"
        }
    }
}

if ($DryRun) { exit 0 }

Stop-Process -Name SearchApp -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($locked -contains 'Settings\settings.dat') {
    Write-Warning "settings.dat was locked, so the reset is incomplete. Sign out and back in, then run this script again."
} else {
    Write-Host "Done. Press Win, type the name of an app (e.g. 'camera'), and wait 10-15 seconds while search rebuilds." -ForegroundColor Green
}
Write-Host "To undo: .\Restore-SearchApps.ps1 -BackupPath `"$backup`""
