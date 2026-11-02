# =====================================================================
# Fundray Power Panel - shutdown / restart / sleep / lock / restore GUI
# Part of the Fundray enhancement toolkit (not an operating system).
# Compatible with Windows PowerShell 2.0+ on Windows 7 SP1 and Windows 10.
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File powerpanel.ps1
# =====================================================================

param()

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------------ helpers
function Write-UndoEntry {
    param([string]$Message)
    try {
        $dir = Join-Path $env:ProgramData "Fundray\logs"
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $line = "{0}  PowerPanel  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
        Add-Content -Path (Join-Path $dir "powerpanel.log") -Value $line
    } catch { }
}

function New-RestorePoint {
    param([string]$Name = "Fundray Power Panel")
    try {
        $sr = [wmiclass]"\\.\root\default:SystemRestore"
        $null = $sr.Enable("")
        $result = $sr.CreateRestorePoint($Name, 7, 100)
        if ($result.ReturnValue -eq 0) {
            Write-UndoEntry "Restore point created: $Name"
            [System.Windows.Forms.MessageBox]::Show(
                "Restore point '$Name' was created successfully.",
                "Fundray Power Panel",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        } else {
            throw "SystemRestore returned $($result.ReturnValue)"
        }
    } catch {
        Write-UndoEntry "Restore point FAILED: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show(
            "Could not create a restore point. System Restore may be disabled.$([Environment]::NewLine)$($_.Exception.Message)",
            "Fundray Power Panel",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
}

function Confirm-Action {
    param([string]$Title, [string]$Text)
    $answer = [System.Windows.Forms.MessageBox]::Show(
        $Text, $Title,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    return ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
}

# ------------------------------------------------------------------ actions
function Invoke-Restart {
    if (Confirm-Action "Restart now?" "Restart this computer immediately?") {
        Write-UndoEntry "Restart requested"
        shutdown.exe /r /t 0
    }
}

function Invoke-Shutdown {
    if (Confirm-Action "Shut down now?" "Shut this computer down immediately?") {
        Write-UndoEntry "Shutdown requested"
        shutdown.exe /s /t 0
    }
}

function Invoke-Sleep {
    Write-UndoEntry "Sleep requested"
    rundll32.exe powrprof.dll,SetSuspendState 0,1,0
}

function Invoke-SignOut {
    Write-UndoEntry "Sign out requested"
    shutdown.exe /l
}

function Invoke-Lock {
    Write-UndoEntry "Lock requested"
    rundll32.exe user32.dll,LockWorkStation
}

# ------------------------------------------------------------------ form
$form                       = New-Object System.Windows.Forms.Form
$form.Text                  = "Fundray Power Panel"
$form.Size                  = New-Object System.Drawing.Size(560, 470)
$form.StartPosition         = "CenterScreen"
$form.FormBorderStyle       = "FixedDialog"
$form.MaximizeBox           = $false
$form.BackColor             = [System.Drawing.Color]::FromArgb(16, 19, 27)
$form.KeyPreview            = $true
$form.TopMost               = $true

$title                      = New-Object System.Windows.Forms.Label
$title.Text                 = "What do you want to do?"
$title.Font                 = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$title.ForeColor            = [System.Drawing.Color]::FromArgb(233, 236, 244)
$title.Location             = New-Object System.Drawing.Point(24, 16)
$title.Size                 = New-Object System.Drawing.Size(400, 30)
$form.Controls.Add($title)

$subtitle                   = New-Object System.Windows.Forms.Label
$subtitle.Text              = "One click. Everything Fundray does is safe by design."
$subtitle.Font              = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitle.ForeColor         = [System.Drawing.Color]::FromArgb(154, 163, 181)
$subtitle.Location          = New-Object System.Drawing.Point(26, 46)
$subtitle.Size              = New-Object System.Drawing.Size(480, 20)
$form.Controls.Add($subtitle)

# Button factory: dark tiles with an accent left bar
function New-PowerTile {
    param(
        [string]$Text, [string]$SubText, [int]$X, [int]$Y,
        [System.Drawing.Color]$Accent, [scriptblock]$Action
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = ""
    $btn.Size = New-Object System.Drawing.Size(240, 80)
    $btn.Location = New-Object System.Drawing.Point($X, $Y)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(39, 45, 61)
    $btn.FlatAppearance.BorderSize = 1
    $btn.BackColor = [System.Drawing.Color]::FromArgb(23, 27, 40)
    $btn.Cursor = "Hand"
    $btn.Tag = $Action

    # main label drawn on a child label so we get two-line tiles
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(233, 236, 244)
    $lbl.Location = New-Object System.Drawing.Point(16, 14)
    $lbl.Size = New-Object System.Drawing.Size(210, 24)
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $btn.Controls.Add($lbl)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = $SubText
    $sub.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $sub.ForeColor = [System.Drawing.Color]::FromArgb(107, 118, 137)
    $sub.Location = New-Object System.Drawing.Point(16, 44)
    $sub.Size = New-Object System.Drawing.Size(210, 18)
    $sub.BackColor = [System.Drawing.Color]::Transparent
    $btn.Controls.Add($sub)

    $btn.Add_Click({ & $this.Tag }.GetNewClosure())
    $form.Controls.Add($btn)
    return $btn
}

$accentBlue  = [System.Drawing.Color]::FromArgb(76, 194, 255)
$accentRed   = [System.Drawing.Color]::FromArgb(255, 107, 107)
$accentGreen = [System.Drawing.Color]::FromArgb(62, 207, 142)

$null = New-PowerTile "Restart"        "confirms first"      24  84 $accentBlue  { Invoke-Restart }
$null = New-PowerTile "Shut down"      "confirms first"     280  84 $accentRed   { Invoke-Shutdown }
$null = New-PowerTile "Sleep"          "instant"             24 174 $accentBlue  { Invoke-Sleep }
$null = New-PowerTile "Sign out"       "instant"            280 174 $accentBlue  { Invoke-SignOut }
$null = New-PowerTile "Lock"           "instant"             24 264 $accentBlue  { Invoke-Lock }
$null = New-PowerTile "Restore point"  "create checkpoint"  280 264 $accentGreen { New-RestorePoint }

$foot                       = New-Object System.Windows.Forms.Label
$foot.Text                  = "Fundray 1.0  -  not an operating system  -  every action is logged"
$foot.Font                  = New-Object System.Drawing.Font("Segoe UI", 8)
$foot.ForeColor             = [System.Drawing.Color]::FromArgb(107, 118, 137)
$foot.Location              = New-Object System.Drawing.Point(26, 380)
$foot.Size                  = New-Object System.Drawing.Size(500, 18)
$form.Controls.Add($foot)

# Escape closes the panel
$form.KeyDown.Add({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() }
})

Write-UndoEntry "Power Panel opened"
[void]$form.ShowDialog()
Write-UndoEntry "Power Panel closed"
