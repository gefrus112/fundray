#requires -Version 3
# ============================================================================
# optimize.ps1 — Fundray performance optimization module
# https://github.com/gefrus112/fundray
#
# Fundray is NOT an operating system — this script tunes an existing Windows
# install with whitelist-based, logged, reversible changes only.
#
# Usage (from an elevated prompt, or via optimize.bat / the Fundray GUI):
#   powershell -NoProfile -ExecutionPolicy Bypass -File optimize.ps1 -All
#   powershell ... -File optimize.ps1 -PowerPlan -Temp -KeepEffects
#
# Safety rules:
#   * Attempts a system restore point before touching anything.
#   * Services/startup entries are disabled ONLY if they match the whitelist.
#   * Critical services are protected by $ServicesNeverTouch.
#   * Every reversible change is appended to a CSV change log that
#     revert.ps1 replays backwards.
# ============================================================================

[CmdletBinding()]
param(
    [switch]$All,
    [switch]$PowerPlan,
    [switch]$Startup,
    [switch]$Services,
    [switch]$Temp,
    [switch]$Visuals,
    # Keep most visual effects: instead of "best performance" we only make
    # sure Windows is left on "let Windows choose" (its default).
    [switch]$KeepEffects
)

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------------------
# Logging setup
# ----------------------------------------------------------------------------
$LogDir    = Join-Path $env:ProgramData 'Fundray\logs'
$TimeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogFile   = Join-Path $LogDir "optimize-$TimeStamp.log"
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
        [string]$Type,      # Registry | Service | Startup | PowerPlan | File | Cleanup
        [string]$Path,      # Target path / service name
        [string]$Name,      # Value or setting name
        [string]$OldValue,  # Previous value, or '<ABSENT>' when it did not exist
        [string]$NewValue,  # New value, or '<DELETED>' / '<CLEARED>'
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
    # Export-Csv -Append requires PowerShell 3.0+ (enforced by #requires).
    $row | Export-Csv -Path $ChangeCsv -Append -NoTypeInformation -Encoding UTF8
}

# ----------------------------------------------------------------------------
# Preconditions
# ----------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'ERROR: Fundray optimization requires administrator rights.'
    Write-Host 'Right-click the shortcut / batch file and choose "Run as administrator".'
    exit 1
}

if (-not ($All -or $PowerPlan -or $Startup -or $Services -or $Temp -or $Visuals)) {
    Write-Host 'Nothing selected. Pass -All or one of: -PowerPlan -Startup -Services -Temp -Visuals'
    exit 0
}

Write-Log '=== Fundray performance optimization started ==='
Write-Log ('OS: ' + (Get-CimInstance Win32_OperatingSystem).Caption)

# ----------------------------------------------------------------------------
# Restore point (safety rule: before every optimization run)
# ----------------------------------------------------------------------------
Write-Log '[1/5] Ensuring a system restore point exists...'
try {
    Checkpoint-Computer -Description 'Fundray baseline' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Log '      Restore point created (or Windows reused one from the last 24 hours).'
} catch {
    Write-Log ('      WARN: restore point was not created: ' + $_.Exception.Message)
    Write-Log '      Continuing - you can still revert via the change log and rstrui.exe.'
}

# ----------------------------------------------------------------------------
# Whitelists — the heart of Fundray's safety model
# ----------------------------------------------------------------------------
# Services we may disable. Everything NOT listed here is never touched.
$ServicesMayDisable = @(
    'DiagTrack',         # Connected User Experiences and Telemetry
    'dmwappushservice',  # WAP Push message routing service
    'MapsBroker',        # Downloaded Maps Manager
    'RetailDemo',        # Retail Demo Service
    'Fax',               # Fax
    'RemoteRegistry',    # Remote Registry
    'WalletService',     # Wallet Service
    'PhoneSvc'           # Phone Service
)

# Hard protection list — kept for documentation and double-checking.
$ServicesNeverTouch = @(
    'WinDefend', 'wuauserv', 'BITS', 'RpcSs', 'DcomLaunch', 'LanmanServer',
    'LanmanWorkstation', 'EventLog', 'Schedule', 'Themes', 'Audiosrv',
    'Netman', 'nsi', 'Dhcp', 'Dnscache', 'CryptSvc', 'msiserver',
    'Winmgmt', 'ProfSvc', 'UserManager'
)

# Startup entries (registry Run values) we may disable, matched by -like.
$StartupWhitelist = @(
    'OneDrive*', 'MicrosoftEdgeAutoLaunch*', '*Teams*',
    '*Skype*', '*Spotify*', '*Discord*', '*Cortana*'
)

# ----------------------------------------------------------------------------
# 2/5  Power plan
# ----------------------------------------------------------------------------
if ($All -or $PowerPlan) {
    Write-Log '[2/5] Power plan...'
    try {
        $current = powercfg /getactivescheme | Out-String
        $oldGuid = [regex]::Match($current, '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}').Value

        # Ultimate Performance exists on Windows 10 1803+; fall back to High Performance.
        $highPerf = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        $ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $target = $highPerf
        $targetName = 'High performance'
        $duplicated = powercfg -duplicatescheme $ultimate 2>$null | Out-String
        $newGuid = [regex]::Match($duplicated, '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}').Value
        if ($newGuid) { $target = $newGuid; $targetName = 'Ultimate Performance' }

        if ($oldGuid -and $oldGuid -ne $target) {
            powercfg /setactive $target
            Write-Log ('      Active plan set to: ' + $targetName)
            Write-Change -Type 'PowerPlan' -Path 'powercfg' -Name 'ActiveScheme' `
                -OldValue $oldGuid -NewValue $target -UndoHint ('SetActive:' + $oldGuid)
        } else {
            Write-Log '      High/Ultimate performance is already active - nothing to do.'
        }
    } catch {
        Write-Log ('      WARN: power plan step failed: ' + $_.Exception.Message)
    }
}

# ----------------------------------------------------------------------------
# 3/5  Services (whitelist only)
# ----------------------------------------------------------------------------
if ($All -or $Services) {
    Write-Log '[3/5] Disabling whitelisted non-critical services...'
    foreach ($name in $ServicesMayDisable) {
        if ($ServicesNeverTouch -contains $name) { continue }   # belt and braces
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $svc) { continue }

        $wmi = Get-WmiObject Win32_Service -Filter ("Name='$name'") -ErrorAction SilentlyContinue
        $startMode = if ($wmi) { $wmi.StartMode } else { 'Unknown' }
        $wasRunning = ($svc.Status -eq 'Running')

        if ($startMode -eq 'Disabled') {
            Write-Log ('      Already disabled: ' + $name)
            continue
        }

        try {
            Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $name -StartupType Disabled -ErrorAction Stop
            Write-Log ('      Disabled service: ' + $name + ' (was ' + $startMode + ')')
            Write-Change -Type 'Service' -Path $name -Name 'StartMode' `
                -OldValue $startMode -NewValue 'Disabled' `
                -UndoHint ('WasRunning:' + $wasRunning)
        } catch {
            Write-Log ('      WARN: could not disable ' + $name + ': ' + $_.Exception.Message)
        }
    }
}

# ----------------------------------------------------------------------------
# 4/5  Startup entries (whitelist only, from documented Run keys)
# ----------------------------------------------------------------------------
if ($All -or $Startup) {
    Write-Log '[4/5] Disabling whitelisted startup entries...'
    $runKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
    )
    foreach ($key in $runKeys) {
        if (-not (Test-Path $key)) { continue }
        $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -in @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) { continue }
            if ($StartupWhitelist | Where-Object { $prop.Name -like $_ }) {
                Write-Log ('      Disabled startup entry: ' + $prop.Name)
                Write-Change -Type 'Startup' -Path $key -Name $prop.Name `
                    -OldValue $prop.Value -NewValue '<DELETED>' -UndoHint 'RunKey'
                Remove-ItemProperty -Path $key -Name $prop.Name -ErrorAction SilentlyContinue
            } else {
                Write-Log ('      Kept (not whitelisted): ' + $prop.Name)
            }
        }
    }
}

# ----------------------------------------------------------------------------
# 5/5  Temp files + Windows Update cache
# ----------------------------------------------------------------------------
if ($All -or $Temp) {
    Write-Log '[5/5] Cleaning temporary files and Windows Update cache...'
    $cutoff = (Get-Date).AddHours(-24)

    foreach ($dir in @($env:TEMP, (Join-Path $env:windir 'Temp'))) {
        if (-not (Test-Path $dir)) { continue }
        $before = (Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue |
                   Measure-Object Length -Sum).Sum
        Get-ChildItem $dir -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $after = (Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue |
                  Measure-Object Length -Sum).Sum
        Write-Log ('      Freed {0:N1} MB in {1}' -f (($before - $after) / 1MB), $dir)
    }
    # Deletions are not revertible; record them so revert.ps1 can skip politely.
    Write-Change -Type 'Cleanup' -Path 'Temp + SoftwareDistribution\Download' -Name 'Files' `
        -OldValue '<present>' -NewValue '<DELETED>' -UndoHint 'NotRevertible'

    # Windows Update cache: stop services briefly, always restart them afterwards.
    $wuStopped = $false
    try {
        Stop-Service -Name 'wuauserv' -Force -ErrorAction SilentlyContinue
        Stop-Service -Name 'bits' -Force -ErrorAction SilentlyContinue
        $wuStopped = $true
        $dl = Join-Path $env:windir 'SoftwareDistribution\Download'
        if (Test-Path $dl) {
            Remove-Item (Join-Path $dl '*') -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log '      Windows Update download cache cleared.'
        }
    } catch {
        Write-Log ('      WARN: update cache cleanup: ' + $_.Exception.Message)
    } finally {
        if ($wuStopped) {
            Start-Service -Name 'bits' -ErrorAction SilentlyContinue
            Start-Service -Name 'wuauserv' -ErrorAction SilentlyContinue
        }
    }
}

# ----------------------------------------------------------------------------
# Visual effects
# ----------------------------------------------------------------------------
if ($All -or $Visuals) {
    Write-Log '[+] Visual effects...'
    $veKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    if (-not (Test-Path $veKey)) { New-Item -Path $veKey -Force | Out-Null }
    $existing = Get-ItemProperty -Path $veKey -ErrorAction SilentlyContinue
    $old = if ($existing -and $null -ne $existing.VisualFXSetting) { [string]$existing.VisualFXSetting } else { '<ABSENT>' }

    # 2 = best performance, 0 = let Windows choose (its default, keeps effects).
    $new = if ($KeepEffects) { '0' } else { '2' }
    Set-ItemProperty -Path $veKey -Name 'VisualFXSetting' -Value ([int]$new)
    $fxNote = ' (best performance)'
    if ($KeepEffects) { $fxNote = ' (Windows default, effects kept)' }
    Write-Log ('      VisualFXSetting -> ' + $new + $fxNote)
    Write-Change -Type 'Registry' -Path $veKey -Name 'VisualFXSetting' `
        -OldValue $old -NewValue $new -UndoHint 'Registry'
}

Write-Log ('=== Done. Change log: ' + $ChangeCsv + ' ===')
Write-Log 'To undo everything: powershell -File scripts\revert.ps1 (or the GUI one-click restore).'
