#requires -Version 3
# ============================================================================
# appearance.ps1 — Fundray appearance module (login background)
# https://github.com/gefrus112/fundray
#
# Uses the DOCUMENTED registry method only:
#   HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\Background
#     OEMBackground (DWORD) = 1
#   C:\Windows\System32\oobe\info\backgrounds\backgroundDefault.jpg
#
# Honest compatibility note: this method is reliable on Windows 7. Windows
# 10/11 often ignore OEMBackground — the script still applies it where the OS
# allows, and says so instead of pretending. Fundray never patches system
# files (no .dll/.mui/.theme resource hacks) and never touches activation.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File appearance.ps1 -SetLoginBackground "C:\path\bg.jpg"
#   powershell -NoProfile -ExecutionPolicy Bypass -File appearance.ps1 -RemoveLoginBackground
# ============================================================================

[CmdletBinding()]
param(
    [string]$SetLoginBackground,
    [switch]$RemoveLoginBackground
)

$ErrorActionPreference = 'Stop'

$LogDir = Join-Path $env:ProgramData 'Fundray\logs'
$TimeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ChangeCsv = Join-Path $LogDir "changes-$TimeStamp.csv"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log {
    param([string]$Message)
    $line = '{0:HH:mm:ss} {1}' -f (Get-Date), $Message
    Write-Host $line
    Add-Content -Path (Join-Path $LogDir 'appearance.log') -Value $line -Encoding UTF8
}

function Write-Change {
    param([string]$Type, [string]$Path, [string]$Name, [string]$OldValue,
          [string]$NewValue, [string]$UndoHint)
    [pscustomobject]@{
        Time = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); Type = $Type; Path = $Path
        Name = $Name; OldValue = $OldValue; NewValue = $NewValue; UndoHint = $UndoHint
    } | Export-Csv -Path $ChangeCsv -Append -NoTypeInformation -Encoding UTF8
}

# --- Preconditions -----------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'ERROR: changing the login background requires administrator rights.'
    exit 1
}

if (-not ($SetLoginBackground -or $RemoveLoginBackground)) {
    Write-Host 'Nothing to do. Use -SetLoginBackground "image.jpg" or -RemoveLoginBackground.'
    exit 0
}

$RegKey      = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\Background'
$BgDir       = Join-Path $env:windir 'System32\oobe\info\backgrounds'
$BgFile      = Join-Path $BgDir 'backgroundDefault.jpg'
$BgBackup    = Join-Path $BgDir 'backgroundDefault.fundray-backup.jpg'

if (-not (Test-Path $RegKey)) { New-Item -Path $RegKey -Force | Out-Null }
if (-not (Test-Path $BgDir))  { New-Item -ItemType Directory -Force -Path $BgDir | Out-Null }

$existingOem = Get-ItemProperty -Path $RegKey -ErrorAction SilentlyContinue
$oldOem = if ($existingOem -and $null -ne $existingOem.OEMBackground) { [string]$existingOem.OEMBackground } else { '<ABSENT>' }

# --- Apply -------------------------------------------------------------------
if ($SetLoginBackground) {
    if (-not (Test-Path $SetLoginBackground)) {
        Write-Log ('ERROR: image not found: ' + $SetLoginBackground)
        exit 1
    }
    $ext = [IO.Path]::GetExtension($SetLoginBackground).ToLower()
    if ($ext -ne '.jpg' -and $ext -ne '.jpeg') {
        Write-Log 'ERROR: the login background must be a JPG image.'
        exit 1
    }
    $size = (Get-Item $SetLoginBackground).Length
    if ($size -gt 256KB) {
        Write-Log ('ERROR: image is {0:N0} KB - Windows 7 requires 256 KB or smaller. Please resize it.' -f ($size / 1KB))
        exit 1
    }

    # Keep the original login background exactly once.
    if ((Test-Path $BgFile) -and -not (Test-Path $BgBackup)) {
        Copy-Item -Path $BgFile -Destination $BgBackup -Force
        Write-Log ('Original login background backed up: ' + $BgBackup)
    }

    Set-ItemProperty -Path $RegKey -Name 'OEMBackground' -Value 1 -Type DWord
    Copy-Item -Path $SetLoginBackground -Destination $BgFile -Force
    Write-Log ('Login background applied: ' + $BgFile)
    Write-Log 'Sign out (or reboot) to see it. Note: reliable on Windows 7; some Windows 10/11 builds ignore this method.'
    Write-Change -Type 'Registry' -Path $RegKey -Name 'OEMBackground' -OldValue $oldOem -NewValue '1' -UndoHint 'Registry'
    Write-Change -Type 'File' -Path $BgFile -Name 'backgroundDefault.jpg' -OldValue '<ABSENT>' -NewValue $SetLoginBackground -UndoHint ('RestoreBackup:' + $BgBackup)
    exit 0
}

# --- Remove ------------------------------------------------------------------
if ($RemoveLoginBackground) {
    if (Test-Path $BgBackup) {
        Copy-Item -Path $BgBackup -Destination $BgFile -Force
        Remove-Item -Path $BgBackup -Force
        Write-Log 'Original login background restored.'
    } elseif (Test-Path $BgFile) {
        Remove-Item -Path $BgFile -Force
        Write-Log 'Custom login background removed (no backup existed).'
    } else {
        Write-Log 'No custom login background found.'
    }

    if ($oldOem -eq '<ABSENT>') {
        Remove-ItemProperty -Path $RegKey -Name 'OEMBackground' -ErrorAction SilentlyContinue
    } else {
        Set-ItemProperty -Path $RegKey -Name 'OEMBackground' -Value ([int]$oldOem) -Type DWord
    }
    Write-Log 'OEMBackground registry value restored.'
    exit 0
}
