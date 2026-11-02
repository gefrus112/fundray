#requires -Version 3
# ============================================================================
# revert.ps1 — Fundray one-click restore
# https://github.com/gefrus112/fundray
#
# Replays Fundray's CSV change logs (changes-*.csv in %ProgramData%\Fundray\logs)
# backwards, restoring the previous value of every logged change:
#   Registry  -> restore or remove the value
#   Service   -> restore the previous start mode (and restart if it was running)
#   Startup   -> recreate the removed Run-key entry
#   PowerPlan -> re-activate the previous power scheme
#   File      -> restore a backed-up file (e.g. the login background)
#   Cleanup   -> skipped (deleted temp files are not restorable by design)
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File revert.ps1            # newest log
#   powershell ... -File revert.ps1 -AllFiles                                 # every log
#   powershell ... -File revert.ps1 -Terminal                                 # + restore settings.json
# ============================================================================

[CmdletBinding()]
param(
    [switch]$AllFiles,
    [switch]$Terminal
)

$ErrorActionPreference = 'Continue'

$LogDir = Join-Path $env:ProgramData 'Fundray\logs'
$RevertLog = Join-Path $LogDir ("revert-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".log")
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log {
    param([string]$Message)
    $line = '{0:HH:mm:ss} {1}' -f (Get-Date), $Message
    Write-Host $line
    Add-Content -Path $RevertLog -Value $line -Encoding UTF8
}

# --- Preconditions -----------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'ERROR: reverting system tweaks requires administrator rights.'
    exit 1
}

# --- Locate change logs -------------------------------------------------------
$logFiles = Get-ChildItem -Path $LogDir -Filter 'changes-*.csv' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime
if (-not $logFiles) {
    Write-Log 'No Fundray change logs found - there is nothing to revert.'
    exit 0
}
if (-not $AllFiles) {
    $logFiles = @($logFiles | Select-Object -Last 1)
}

Write-Log ('Reverting from {0} change log(s): {1}' -f $logFiles.Count, (($logFiles | ForEach-Object Name) -join ', '))

# Revert newest log first, rows in reverse order (last change wins backwards).
$undone = 0; $skipped = 0
foreach ($file in ($logFiles | Sort-Object LastWriteTime -Descending)) {
    $rows = @()
    try { $rows = @(Import-Csv -Path $file.FullName) } catch { Write-Log ('WARN: cannot read ' + $file.Name); continue }

    for ($i = $rows.Count - 1; $i -ge 0; $i--) {
        $row = $rows[$i]
        switch ($row.Type) {

            'Registry' {
                try {
                    if ($row.OldValue -eq '<ABSENT>') {
                        Remove-ItemProperty -Path $row.Path -Name $row.Name -ErrorAction Stop
                    } else {
                        Set-ItemProperty -Path $row.Path -Name $row.Name -Value $row.OldValue -ErrorAction Stop
                    }
                    Write-Log ('[OK] Registry ' + $row.Path + ' :: ' + $row.Name + ' -> ' + $row.OldValue)
                    $undone++
                } catch {
                    Write-Log ('[SKIP] Registry ' + $row.Path + ' :: ' + $row.Name + ' (' + $_.Exception.Message + ')')
                    $skipped++
                }
            }

            'Service' {
                try {
                    $mode = switch ($row.OldValue) {
                        'Auto'     { 'Automatic' }
                        'Manual'   { 'Manual' }
                        'Disabled' { 'Disabled' }
                        default    { 'Manual' }
                    }
                    Set-Service -Name $row.Path -StartupType $mode -ErrorAction Stop
                    if ($row.UndoHint -eq 'WasRunning:True') {
                        Start-Service -Name $row.Path -ErrorAction SilentlyContinue
                    }
                    Write-Log ('[OK] Service ' + $row.Path + ' start mode -> ' + $mode)
                    $undone++
                } catch {
                    Write-Log ('[SKIP] Service ' + $row.Path + ' (' + $_.Exception.Message + ')')
                    $skipped++
                }
            }

            'Startup' {
                try {
                    if ($row.OldValue -eq '<DELETED>') {
                        # Nothing to recreate.
                    } else {
                        if (-not (Test-Path $row.Path)) { New-Item -Path $row.Path -Force | Out-Null }
                        New-ItemProperty -Path $row.Path -Name $row.Name -Value $row.OldValue `
                            -PropertyType String -Force -ErrorAction Stop | Out-Null
                    }
                    Write-Log ('[OK] Startup entry restored: ' + $row.Name)
                    $undone++
                } catch {
                    Write-Log ('[SKIP] Startup ' + $row.Name + ' (' + $_.Exception.Message + ')')
                    $skipped++
                }
            }

            'PowerPlan' {
                if ($row.UndoHint -like 'SetActive:*') {
                    $guid = $row.UndoHint.Substring('SetActive:'.Length)
                    powercfg /setactive $guid | Out-Null
                    Write-Log ('[OK] Power plan re-activated: ' + $guid)
                    $undone++
                }
            }

            'RegKey' {
                # Key-level undo used by win11.ps1 (classic right-click menu).
                try {
                    if ($row.OldValue -eq '<ABSENT>') {
                        # The key did not exist before Fundray - remove it again.
                        if (Test-Path $row.Path) {
                            Remove-Item -Path $row.Path -Recurse -Force -ErrorAction Stop
                            Write-Log ('[OK] Registry key removed: ' + $row.Path)
                            $undone++
                        } else {
                            Write-Log ('[SKIP] Registry key already absent: ' + $row.Path)
                            $skipped++
                        }
                    } else {
                        # The key existed before Fundray - recreate it with its old default.
                        New-Item -Path $row.Path -Force -ErrorAction Stop | Out-Null
                        if ($row.Name -and $row.Name -ne '-') {
                            Set-ItemProperty -Path $row.Path -Name $row.Name -Value $row.OldValue -ErrorAction Stop
                        }
                        Write-Log ('[OK] Registry key restored: ' + $row.Path)
                        $undone++
                    }
                } catch {
                    Write-Log ('[SKIP] RegKey ' + $row.Path + ' (' + $_.Exception.Message + ')')
                    $skipped++
                }
            }

            'File' {
                if ($row.UndoHint -like 'RestoreBackup:*') {
                    $backup = $row.UndoHint.Substring('RestoreBackup:'.Length)
                    if (Test-Path $backup) {
                        Copy-Item -Path $backup -Destination $row.Path -Force
                        Remove-Item -Path $backup -Force
                        Write-Log ('[OK] File restored from backup: ' + $row.Path)
                        $undone++
                    } else {
                        Write-Log ('[SKIP] Backup missing for ' + $row.Path)
                        $skipped++
                    }
                }
            }

            'Cleanup' {
                Write-Log '[SKIP] Cleanup entries (deleted temp files are not restorable - and not needed).'
                $skipped++
            }

            default {
                Write-Log ('[SKIP] Unknown change type: ' + $row.Type)
                $skipped++
            }
        }
    }
}

Write-Log ('=== Revert finished. {0} change(s) undone, {1} skipped. ===' -f $undone, $skipped)

# --- Optional: Terminal settings as well ---------------------------------------
if ($Terminal) {
    $tc = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'terminal-config.ps1'
    if (Test-Path $tc) {
        Write-Log 'Restoring Windows Terminal settings...'
        & $tc -Restore
    }
}

Write-Log 'Deeper rollback available through Windows System Restore: press Win+R, type rstrui.exe'
