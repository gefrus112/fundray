#requires -Version 3
# ============================================================================
# win11.ps1 - Fundray Windows 11 experience module
# https://github.com/gefrus112/fundray
#
# Fundray is NOT an operating system - this script tunes an existing
# Windows 11 install with documented, logged, reversible changes only.
#
# Usage (from any PowerShell window; no admin required for HKCU edits):
#   powershell -NoProfile -ExecutionPolicy Bypass -File win11.ps1 -Menu
#   powershell ... -File win11.ps1 -Menu -TaskbarAlign left -RestartExplorer
#   powershell ... -File win11.ps1 -NoMenu -TaskbarAlign center
#
# What it does:
#   * -Menu          classic full right-click menu (documented CLSID key)
#   * -NoMenu        back to the Windows 11 condensed context menu
#   * -TaskbarAlign  'left' or 'center' (TaskbarAl value)
#   * -RestartExplorer  restarts explorer.exe so changes show immediately
#
# Safety rules:
#   * Refuses to run on anything older than Windows 11 (build 22000).
#   * Only documented HKCU values are touched - no system files, no services.
#   * Every change is appended to a CSV change log that revert.ps1 replays.
# ============================================================================

[CmdletBinding()]
param(
    [switch]$Menu,
    [switch]$NoMenu,
    [ValidateSet('left', 'center')]
    [string]$TaskbarAlign,
    [switch]$RestartExplorer
)

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------------------
# Logging setup (same layout as the other Fundray modules)
# ----------------------------------------------------------------------------
$LogDir    = Join-Path $env:ProgramData 'Fundray\logs'
$TimeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile   = Join-Path $LogDir "win11-$TimeStamp.log"
$ChangeCsv = Join-Path $LogDir "changes-$TimeStamp.csv"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log {
    param([string]$Message)
    $line = '{0:HH:mm:ss} {1}' -f (Get-Date), $Message
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Write-Change {
    param(
        [string]$Type,      # Registry | RegKey
        [string]$Path,      # Target registry path
        [string]$Name,      # Value name ('(default)' for key default)
        [string]$OldValue,  # Previous value, or '<ABSENT>' when it did not exist
        [string]$NewValue,  # New value, or '<CREATED>' / '<REMOVED>'
        [string]$UndoHint   # Extra hint consumed by revert.ps1
    )
    $row = [pscustomobject]@{
        Time     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Type     = $Type
        Path     = $Path
        Name     = $Name
        OldValue = $OldValue
        NewValue = $NewValue
        UndoHint = $UndoHint
    }
    $row | Export-Csv -Path $ChangeCsv -Append -NoTypeInformation -Encoding UTF8
}

# ----------------------------------------------------------------------------
# Help
# ----------------------------------------------------------------------------
if (-not ($Menu -or $NoMenu -or $TaskbarAlign)) {
    Write-Host 'Fundray Windows 11 tweaks'
    Write-Host 'Usage:'
    Write-Host '  win11.ps1 -Menu                          classic right-click menu ON'
    Write-Host '  win11.ps1 -NoMenu                        back to the Win11 condensed menu'
    Write-Host '  win11.ps1 -TaskbarAlign left|center      taskbar alignment'
    Write-Host '  win11.ps1 -Menu -TaskbarAlign left -RestartExplorer'
    Write-Host ''
    Write-Host 'Nothing was changed. Pass at least one option.'
    exit 0
}

# ----------------------------------------------------------------------------
# Windows 11 self-check (the tweaks below make no sense elsewhere)
# ----------------------------------------------------------------------------
$cv    = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
$build = 0
if (-not [int]::TryParse([string]$cv.CurrentBuildNumber, [ref]$build)) { $build = 0 }

Write-Log '=== Fundray Windows 11 tweaks started ==='
Write-Log ('OS: ' + $cv.ProductName + ' (build ' + $build + ')')

if ($build -lt 22000) {
    Write-Log 'ERROR: Windows 11 (build 22000+) is required for this module.'
    Write-Log '       On Windows 7 SP1 / 10 the classic menu and taskbar options do not exist.'
    Write-Log '       Nothing was changed. Use optimize.ps1 for performance tweaks instead.'
    exit 1
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log 'NOTE: running without administrator rights - fine for these HKCU-only tweaks.'
}

$changed = 0

# ----------------------------------------------------------------------------
# [1] Classic full right-click menu
#     Documented mechanism: the CLSID key {86ca1aa0-34aa-4e8b-a509-50c905bae2a2}
#     (the Win11 condensed-menu COM host). If the key exists with an empty
#     default in InprocServer32, Explorer falls back to the full legacy menu.
# ----------------------------------------------------------------------------
$MenuKey = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'

if ($Menu) {
    Write-Log '[1/2] Classic right-click menu: enabling...'
    if (Test-Path $MenuKey) {
        Write-Log '      Already enabled - nothing to do.'
    } else {
        New-Item -Path $MenuKey -Force -ErrorAction Stop | Out-Null
        Set-ItemProperty -Path $MenuKey -Name '(default)' -Value '' -ErrorAction Stop
        Write-Change -Type 'RegKey' -Path $MenuKey -Name '(default)' `
            -OldValue '<ABSENT>' -NewValue '<CREATED>' -UndoHint 'ClassicMenu'
        Write-Log '      [OK] Classic right-click menu enabled.'
        $changed++
    }
}

if ($NoMenu) {
    Write-Log '[1/2] Classic right-click menu: disabling (Windows 11 default)...'
    if (Test-Path $MenuKey) {
        $oldDefault = (Get-Item -Path $MenuKey -ErrorAction SilentlyContinue).GetValue('')
        if ($null -eq $oldDefault) { $oldDefault = '' }
        Remove-Item -Path (Split-Path $MenuKey -Parent) -Recurse -Force -ErrorAction Stop
        Write-Change -Type 'RegKey' -Path $MenuKey -Name '(default)' `
            -OldValue ([string]$oldDefault) -NewValue '<REMOVED>' -UndoHint 'ClassicMenu'
        Write-Log '      [OK] Windows 11 condensed menu restored.'
        $changed++
    } else {
        Write-Log '      Already the Windows 11 default - nothing to do.'
    }
}

# ----------------------------------------------------------------------------
# [2] Taskbar alignment  (TaskbarAl: 0 = left, 1 = center)
# ----------------------------------------------------------------------------
if ($TaskbarAlign) {
    $adv    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $target = if ($TaskbarAlign -eq 'left') { 0 } else { 1 }

    Write-Log ('[2/2] Taskbar alignment: setting to ''' + $TaskbarAlign + '''...')
    $old = (Get-ItemProperty -Path $adv -Name 'TaskbarAl' -ErrorAction SilentlyContinue).TaskbarAl

    if ($null -ne $old -and [int]$old -eq $target) {
        Write-Log '      Already set - nothing to do.'
    } else {
        if ($null -eq $old) { $oldValue = '<ABSENT>' } else { $oldValue = [string]$old }
        Set-ItemProperty -Path $adv -Name 'TaskbarAl' -Value $target -Type DWord -ErrorAction Stop
        Write-Change -Type 'Registry' -Path $adv -Name 'TaskbarAl' `
            -OldValue $oldValue -NewValue ([string]$target) -UndoHint 'TaskbarAlign'
        Write-Log ('      [OK] Taskbar alignment set to: ' + $TaskbarAlign + '.')
        $changed++
    }
}

# ----------------------------------------------------------------------------
# Explorer restart (both tweaks only show after explorer.exe restarts)
# ----------------------------------------------------------------------------
if ($RestartExplorer) {
    Write-Log 'Restarting explorer.exe...'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
    Write-Log '      [OK] Explorer restarted.'
} else {
    Write-Log 'Hint: restart explorer.exe (or sign out/in) to see the changes.'
}

Write-Log ('=== Fundray Windows 11 tweaks finished. ' + $changed + ' change(s) applied. ===')
Write-Log 'Undo: powershell -File scripts\revert.ps1  (replays this change log backwards)'
if ($changed -eq 0) { exit 0 } else { exit 0 }
