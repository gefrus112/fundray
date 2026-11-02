# =====================================================================
# Fundray Boot & Splash - logon background via the DOCUMENTED method
# Part of the Fundray enhancement toolkit (not an operating system).
#
# What this CAN do:
#   - Set your own JPG as the Windows logon (sign-in) background using
#     the documented OEMBackground registry method. Works on Win7 SP1
#     and most Windows 10 installations.
#   - Undo it completely (removes key + image, restores any backup).
#
# What this CANNOT do (and will not pretend to do):
#   - Remove or replace the BIOS / American Megatrends splash. That
#     screen is drawn by your motherboard firmware BEFORE Windows loads.
#     See docs/bootsplash.md for the legitimate BIOS quiet-boot guide.
#   - Replace the boot animation (bootres.dll). Fundray never patches
#     system files.
#
# Compatible with Windows PowerShell 2.0+.
# Usage:
#   bootsplash.ps1 -Action Set   -ImagePath "C:\mine\wall.jpg"
#   bootsplash.ps1 -Action Remove
#   bootsplash.ps1 -Action Status
# =====================================================================

param(
    [ValidateSet("Set", "Remove", "Status")]
    [string]$Action = "Status",
    [string]$ImagePath = ""
)

$ErrorActionPreference = "Stop"

$RegKey    = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\Background"
$BgDir     = Join-Path $env:SystemRoot "System32\oobe\info\backgrounds"
$BgFile    = Join-Path $BgDir "backgroundDefault.jpg"
$Backup    = Join-Path $BgDir "fundray-backup-backgroundDefault.jpg"
$MaxSizeKB = 256   # Win7 rejects backgrounds larger than ~256 KB

function Write-UndoEntry {
    param([string]$Message)
    try {
        $dir = Join-Path $env:ProgramData "Fundray\logs"
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $line = "{0}  BootSplash  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
        Add-Content -Path (Join-Path $dir "bootsplash.log") -Value $line
    } catch { }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------- status
if ($Action -eq "Status") {
    $set = Test-Path $BgFile
    Write-Host ""
    Write-Host "  Fundray Boot & Splash - status" -ForegroundColor Cyan
    Write-Host "  ------------------------------" -ForegroundColor DarkGray
    if ($set) { Write-Host "  Custom logon background: INSTALLED ($BgFile)" -ForegroundColor Green }
    else      { Write-Host "  Custom logon background: not installed" }
    Write-Host "  Firmware splash (AMI / OEM logo): firmware-level - see BIOS settings."
    Write-Host ""
    exit 0
}

if (-not (Test-Admin)) {
    Write-Host "ERROR: run as administrator." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------- set
if ($Action -eq "Set") {
    if ($ImagePath -eq "" -or -not (Test-Path $ImagePath)) {
        Write-Host "ERROR: pass a valid JPG with -ImagePath, e.g." -ForegroundColor Red
        Write-Host '  bootsplash.ps1 -Action Set -ImagePath "C:\Users\you\Pictures\bg.jpg"'
        exit 1
    }
    $ext = [System.IO.Path]::GetExtension($ImagePath).ToLower()
    if ($ext -ne ".jpg") {
        Write-Host "ERROR: the logon background must be a .jpg file (got '$ext')." -ForegroundColor Red
        exit 1
    }
    $sizeKB = [int]((Get-Item $ImagePath).Length / 1KB)
    if ($sizeKB -gt $MaxSizeKB) {
        Write-Host ("WARNING: image is {0} KB. Windows 7 rejects backgrounds over ~{1} KB;" -f $sizeKB, $MaxSizeKB) -ForegroundColor Yellow
        Write-Host  "         resave as JPEG quality ~80 if the background does not appear." -ForegroundColor Yellow
    }

    if (-not (Test-Path $BgDir)) { New-Item -ItemType Directory -Path $BgDir -Force | Out-Null }

    # Keep a one-time backup of any original background
    if ((Test-Path $BgFile) -and -not (Test-Path $Backup)) {
        Copy-Item $BgFile $Backup -Force
        Write-UndoEntry "Original logon background backed up to fundray-backup-backgroundDefault.jpg"
    }

    Copy-Item $ImagePath $BgFile -Force
    if (-not (Test-Path $RegKey)) { New-Item -Path $RegKey -Force | Out-Null }
    Set-ItemProperty -Path $RegKey -Name "OEMBackground" -Value 1 -Type DWord

    Write-UndoEntry "Logon background SET from $ImagePath"
    Write-Host ""
    Write-Host "  Done. Sign out (Win+L) to see the new logon background." -ForegroundColor Green
    Write-Host "  Reminder: the BIOS / AMI splash is firmware and is NOT changed by" -ForegroundColor DarkGray
    Write-Host "  this tweak - see docs/bootsplash.md for the BIOS quiet-boot guide." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# ---------------------------------------------------------------- remove
if ($Action -eq "Remove") {
    if (Test-Path $Backup) {
        Copy-Item $Backup $BgFile -Force
        Remove-Item $Backup -Force
        Write-UndoEntry "Original logon background restored from backup"
    } elseif (Test-Path $BgFile) {
        Remove-Item $BgFile -Force
        Write-UndoEntry "Custom logon background removed"
    }
    try {
        Remove-ItemProperty -Path $RegKey -Name "OEMBackground" -ErrorAction SilentlyContinue
    } catch { }

    Write-Host ""
    Write-Host "  Done. The logon background tweak is fully reverted." -ForegroundColor Green
    Write-Host ""
    exit 0
}
