#requires -Version 3
# ============================================================================
# terminal-config.ps1 — Fundray Windows Terminal configuration module
# https://github.com/gefrus112/fundray
#
# Adds a separate "Fundray" profile to the user's existing Windows Terminal
# settings.json. The user's configuration is NEVER overwritten:
#   * a timestamped backup (settings.backup-fundray-*.json) is made first,
#   * only additive changes are applied,
#   * -Restore puts the previous file back exactly.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File terminal-config.ps1 -Apply
#   powershell -NoProfile -ExecutionPolicy Bypass -File terminal-config.ps1 -Restore
# ============================================================================

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'

$LogDir = Join-Path $env:ProgramData 'Fundray\logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log {
    param([string]$Message)
    $line = '{0:HH:mm:ss} {1}' -f (Get-Date), $Message
    Write-Host $line
    Add-Content -Path (Join-Path $LogDir 'terminal.log') -Value $line -Encoding UTF8
}

# ----------------------------------------------------------------------------
# Locate Windows Terminal (stable / preview / canary) — never download anything
# ----------------------------------------------------------------------------
$terminalPackages = @('Microsoft.WindowsTerminal_8wekyb3d8bbwe',
                      'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe',
                      'Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe')

$settingsFile = $null
foreach ($pkg in $terminalPackages) {
    $candidate = Join-Path $env:LOCALAPPDATA ("Packages\" + $pkg + "\LocalState\settings.json")
    if (Test-Path $candidate) { $settingsFile = $candidate; break }
}

if (-not $settingsFile) {
    # Terminal may exist without a settings.json yet — check for the package folder.
    foreach ($pkg in $terminalPackages) {
        $dir = Join-Path $env:LOCALAPPDATA ("Packages\" + $pkg + "\LocalState")
        if (Test-Path $dir) { $settingsFile = Join-Path $dir 'settings.json'; break }
    }
}

if (-not $settingsFile) {
    Write-Log 'Windows Terminal was not found on this machine.'
    Write-Log 'Install it from the Microsoft Store, start it once, then re-run this script.'
    Write-Log '(Fundray never downloads executables by itself.)'
    exit 1
}

Write-Log ('Found Windows Terminal settings: ' + $settingsFile)
$settingsDir = Split-Path $settingsFile -Parent

# ----------------------------------------------------------------------------
# Restore mode: put the newest pre-Fundray backup back
# ----------------------------------------------------------------------------
if ($Restore) {
    $backup = Get-ChildItem -Path $settingsDir -Filter 'settings.backup-fundray-*.json' -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($backup) {
        Copy-Item -Path $backup.FullName -Destination $settingsFile -Force
        Write-Log ('Restored your previous settings from: ' + $backup.Name)
        Write-Log 'The Fundray profile is gone; your original configuration is back.'
    } else {
        Write-Log 'No Fundray backup found - your Terminal settings were never modified by Fundray.'
    }
    exit 0
}

if (-not $Apply) {
    Write-Log 'Nothing to do. Use -Apply or -Restore.'
    exit 0
}

# ----------------------------------------------------------------------------
# JSON-with-comments handling (Windows Terminal ships a commented template)
# ----------------------------------------------------------------------------
function ConvertFrom-JsonC {
    param([string]$Text)
    # Protect "://" inside strings before stripping comments.
    $protected = $Text -replace '://', '__FUNDRAY_PROT__'
    $protected = $protected -replace '(?m)^\s*//.*$', ''
    $protected = $protected -replace '(?s)/\*.*?\*/', ''
    $protected = $protected -replace '__FUNDRAY_PROT__', '://'
    return $protected | ConvertFrom-Json
}

# ----------------------------------------------------------------------------
# Backup first — this is the "restore default Terminal settings" safety net
# ----------------------------------------------------------------------------
$backupPath = Join-Path $settingsDir ('settings.backup-fundray-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
if (Test-Path $settingsFile) {
    Copy-Item -Path $settingsFile -Destination $backupPath -Force
    Write-Log ('Backup written: ' + $backupPath)
}

$raw = Get-Content -Path $settingsFile -Raw -ErrorAction SilentlyContinue
if ([string]::IsNullOrWhiteSpace($raw)) {
    # Fresh Terminal install without a settings file — start from an empty object.
    $json = New-Object PSObject
    $json | Add-Member -NotePropertyName profiles -NotePropertyValue (New-Object PSObject)
} else {
    $json = ConvertFrom-JsonC $raw
}

# Fundray requires the modern profiles schema: { "profiles": { "list": [...] } }
if (-not ($json.PSObject.Properties['profiles'])) {
    $json | Add-Member -NotePropertyName profiles -NotePropertyValue (New-Object PSObject)
}
if ($json.profiles -is [System.Array]) {
    Write-Log 'Your settings.json uses the legacy profiles schema. Please update Windows'
    Write-Log 'Terminal once, open it, and re-run this script. Nothing was changed.'
    exit 1
}
if (-not ($json.profiles.PSObject.Properties['list'])) {
    $json.profiles | Add-Member -NotePropertyName list -NotePropertyValue @()
}

# ----------------------------------------------------------------------------
# Color scheme: "Fundray Dark" (added once, reused if already present)
# ----------------------------------------------------------------------------
$fundrayScheme = [pscustomobject]@{
    name               = 'Fundray Dark'
    background         = '#101318'
    foreground         = '#D8DEE9'
    cursorColor        = '#4CC2FF'
    selectionBackground= '#0078D4'
    black              = '#1B1F27'
    red                = '#E06C75'
    green              = '#98C379'
    yellow             = '#E5C07B'
    blue               = '#61AFEF'
    purple             = '#C678DD'
    cyan               = '#56B6C2'
    white              = '#ABB2BF'
    brightBlack        = '#5C6370'
    brightRed          = '#E06C75'
    brightGreen        = '#98C379'
    brightYellow       = '#E5C07B'
    brightBlue         = '#61AFEF'
    brightPurple       = '#C678DD'
    brightCyan         = '#56B6C2'
    brightWhite        = '#FFFFFF'
}

$schemes = @()
if ($json.PSObject.Properties['schemes']) { $schemes = @($json.schemes) }
$hasScheme = $false
foreach ($s in $schemes) { if ($s.name -eq 'Fundray Dark') { $hasScheme = $true } }
if (-not $hasScheme) {
    $json | Add-Member -NotePropertyName schemes -NotePropertyValue ($schemes + $fundrayScheme) -Force
    Write-Log 'Added color scheme: Fundray Dark'
} else {
    Write-Log 'Color scheme already present: Fundray Dark'
}

# ----------------------------------------------------------------------------
# The separate "Fundray" profile (Cascadia Code, dark scheme, PowerShell)
# ----------------------------------------------------------------------------
$fundrayGuid = '{F2A3C91D-8E4B-4C6A-9B7E-2D5A1F0B3E4C}'
$commandline = 'powershell.exe'
$pwsh = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue
if ($pwsh) { $commandline = 'pwsh.exe' }

$fundrayProfile = [pscustomobject]@{
    name              = 'Fundray'
    guid              = $fundrayGuid
    commandline       = $commandline
    startingDirectory = '%USERPROFILE%'
    colorScheme       = 'Fundray Dark'
    font              = @{ face = 'Cascadia Code'; size = 11 }
    padding           = '12'
    cursorShape       = 'bar'
    useAcrylic        = $false
    hidden            = $false
}

$list = @($json.profiles.list)
$already = $false
foreach ($p in $list) { if ($p.guid -eq $fundrayGuid) { $already = $true } }

if (-not $already) {
    $json.profiles.list = $list + $fundrayProfile
    Write-Log ('Added profile: Fundray (' + $commandline + ', Cascadia Code 11, Fundray Dark)')
} else {
    Write-Log 'The Fundray profile already exists - nothing to add.'
}

# ----------------------------------------------------------------------------
# App-level defaults — only applied when the user has not set them themselves
# ----------------------------------------------------------------------------
if (-not ($json.PSObject.Properties['defaultProfile'])) {
    $json | Add-Member -NotePropertyName defaultProfile -NotePropertyValue $fundrayGuid
    Write-Log 'Startup profile set to Fundray (PowerShell). Your own choice is restored by -Restore.'
}
if (-not ($json.PSObject.Properties['initialCols'])) {
    $json | Add-Member -NotePropertyName initialCols -NotePropertyValue 120
}
if (-not ($json.PSObject.Properties['initialRows'])) {
    $json | Add-Member -NotePropertyName initialRows -NotePropertyValue 32
}
if (-not ($json.PSObject.Properties['copyOnSelect'])) {
    $json | Add-Member -NotePropertyName copyOnSelect -NotePropertyValue $true
}

# ----------------------------------------------------------------------------
# Write back (keep it readable, like Terminal's own template)
# ----------------------------------------------------------------------------
ConvertTo-Json -InputObject $json -Depth 32 | Set-Content -Path $settingsFile -Encoding UTF8
Write-Log ('Saved: ' + $settingsFile)
Write-Log 'Open Windows Terminal to see the Fundray profile. Undo anytime with: '
Write-Log '  powershell -NoProfile -ExecutionPolicy Bypass -File terminal-config.ps1 -Restore'
