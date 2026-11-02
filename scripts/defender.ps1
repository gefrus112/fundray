# =====================================================================
# Fundray Defender Control - OPTIONAL, opt-in module
# Part of the Fundray enhancement toolkit (not an operating system).
#
# Pause or restore Windows Defender real-time protection using the
# DOCUMENTED Group Policy registry keys. This module:
#   - is never run automatically by the optimizer
#   - always asks for confirmation before changing anything
#   - writes every action to the Fundray undo log
#   - is reversed by uninstall.bat automatically
#
# Compatible with Windows PowerShell 2.0+ on Windows 7 SP1 / Windows 10.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File defender.ps1 -Action Status
#   powershell -NoProfile -ExecutionPolicy Bypass -File defender.ps1 -Action Disable
#   powershell -NoProfile -ExecutionPolicy Bypass -File defender.ps1 -Action Enable
# =====================================================================

param(
    [ValidateSet("Status", "Disable", "Enable")]
    [string]$Action = "Status"
)

$ErrorActionPreference = "Continue"

$PolKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$PolSub = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"

function Write-UndoEntry {
    param([string]$Message)
    try {
        $dir = Join-Path $env:ProgramData "Fundray\logs"
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $line = "{0}  Defender   {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
        Add-Content -Path (Join-Path $dir "defender.log") -Value $line
    } catch { }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DefenderStatus {
    $disabled = $false
    try {
        $v = Get-ItemProperty -Path $PolKey -Name "DisableAntiSpyware" -ErrorAction SilentlyContinue
        if ($v -ne $null -and $v.DisableAntiSpyware -eq 1) { $disabled = $true }
    } catch { }
    # Also ask Defender itself where the cmdlet exists (Windows 8+ / Win10)
    $cmdletAvailable = (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) -ne $null
    $realtime = "unknown"
    if ($cmdletAvailable) {
        try {
            $pref = Get-MpPreference -ErrorAction SilentlyContinue
            if ($pref -ne $null) {
                if ($pref.DisableRealtimeMonitoring) { $realtime = "disabled" } else { $realtime = "enabled" }
            }
        } catch { }
    }
    return @{
        PolicyDisabled  = $disabled
        RealtimeState   = $realtime
        CmdletAvailable = $cmdletAvailable
    }
}

# ---------------------------------------------------------------- status
if ($Action -eq "Status") {
    $s = Get-DefenderStatus
    Write-Host ""
    Write-Host "  Fundray Defender Control - status" -ForegroundColor Cyan
    Write-Host "  ---------------------------------" -ForegroundColor DarkGray
    if ($s.PolicyDisabled -or ($s.RealtimeState -eq "disabled")) {
        Write-Host "  Real-time protection: " -NoNewline
        Write-Host "DISABLED (via Fundray or policy)" -ForegroundColor Yellow
    } else {
        Write-Host "  Real-time protection: " -NoNewline
        Write-Host "ENABLED" -ForegroundColor Green
    }
    Write-Host "  Tamper Protection note: on recent Windows 10 builds, Windows may" -ForegroundColor DarkGray
    Write-Host "  re-enable protection on its own. That is Microsoft's safeguard, not" -ForegroundColor DarkGray
    Write-Host "  a Fundray failure - run 'Enable' or Windows Security to restore it." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

if (-not (Test-Admin)) {
    Write-Host "ERROR: run as administrator (right-click install.bat -> Run as administrator)." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------- disable
if ($Action -eq "Disable") {
    Write-Host ""
    Write-Host "  WARNING - you are about to pause Windows Defender real-time protection." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  * Only do this if you run another antivirus, or for one specific task." -ForegroundColor Yellow
    Write-Host "  * A paused Defender is a real security trade-off. Fundray never does" -ForegroundColor Yellow
    Write-Host "    this silently and never includes it in the one-click optimizer." -ForegroundColor Yellow
    Write-Host "  * On newer Windows 10 builds, Tamper Protection may block or undo this." -ForegroundColor Yellow
    Write-Host ""
    $answer = Read-Host "  Type YES (uppercase) to continue, anything else to cancel"
    if ($answer -cne "YES") {
        Write-Host "  Cancelled - nothing was changed." -ForegroundColor Green
        exit 0
    }

    try {
        if (-not (Test-Path $PolKey)) { New-Item -Path $PolKey -Force | Out-Null }
        Set-ItemProperty -Path $PolKey -Name "DisableAntiSpyware" -Value 1 -Type DWord
        if (-not (Test-Path $PolSub)) { New-Item -Path $PolSub -Force | Out-Null }
        Set-ItemProperty -Path $PolSub -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord
    } catch {
        Write-Host "  Registry policy failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    $s = Get-DefenderStatus
    if ($s.CmdletAvailable) {
        try { Set-MpPreference -DisableRealtimeMonitoring $true } catch {
            Write-Host "  Set-MpPreference failed (Tamper Protection?): $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }

    Write-UndoEntry "Real-time protection DISABLED by user request"
    Write-Host ""
    Write-Host "  Done. Real-time protection is now OFF (where Windows allowed it)." -ForegroundColor Yellow
    Write-Host "  Undo anytime:  defender.ps1 -Action Enable   or run uninstall.bat" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# ---------------------------------------------------------------- enable
if ($Action -eq "Enable") {
    try {
        if (Test-Path $PolSub) { Remove-ItemProperty -Path $PolSub -Name "DisableRealtimeMonitoring" -ErrorAction SilentlyContinue }
        if (Test-Path $PolKey) { Remove-ItemProperty -Path $PolKey -Name "DisableAntiSpyware" -ErrorAction SilentlyContinue }
    } catch {
        Write-Host "  Registry cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    $s = Get-DefenderStatus
    if ($s.CmdletAvailable) {
        try { Set-MpPreference -DisableRealtimeMonitoring $false } catch {
            Write-Host "  Set-MpPreference failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }

    Write-UndoEntry "Real-time protection ENABLED (restored)"
    Write-Host ""
    Write-Host "  Done. Windows Defender is back to protecting your system." -ForegroundColor Green
    Write-Host ""
    exit 0
}
