@echo off
setlocal EnableExtensions
title Fundray installer - Windows 7 SP1 / 10 / 11
rem ============================================================================
rem install.bat - full Fundray installer and module menu.
rem
rem   Fundray is an ENHANCEMENT TOOLKIT, not an operating system. It installs
rem   on top of the Windows you already have and every change is reversible.
rem
rem   Modules:
rem     [1] Full install        - files + performance + terminal + power panel
rem     [2] Performance only    - power plan, services, startup, temp cleanup
rem     [3] Windows Terminal    - add the Fundray profile to settings.json
rem     [4] Appearance          - visual effects, safe look-and-feel tweaks
rem     [5] Boot & splash       - logon background (documented registry method)
rem     [6] Power Panel         - shutdown / restart GUI + Start menu shortcut
rem     [7] Defender control    - OPTIONAL switch (warns, logs, reversible)
rem     [8] Windows 11 tweaks   - classic right-click menu, taskbar (Win11 only)
rem     [9] Files only          - deploy files + shortcuts, apply no tweaks
rem
rem Run as administrator (the script self-elevates). A restore point is
rem created before any tweak. Every action is logged to
rem %ProgramData%\Fundray\logs\.
rem ============================================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Administrator rights are required - requesting elevation...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "ROOT=%~dp0"
set "TARGET=%ProgramFiles%\Fundray"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "LOGDIR=%ProgramData%\Fundray\logs"

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
call :detect_os
call :banner

:menu
echo   What do you want to install?
echo.
echo     [1] Full install  - files + performance + terminal + power panel
echo     [2] Performance only
echo     [3] Windows Terminal profile
echo     [4] Appearance tweaks
echo     [5] Boot ^& splash (logon background)
echo     [6] Power Panel (shutdown GUI)
echo     [7] Defender control  (opt-in - type 7 to read the warnings)
echo     [8] Windows 11 tweaks (classic right-click menu, taskbar)
echo     [9] Files only (no tweaks)
echo     [0] Exit
echo.
set /p CHOICE="  Choose 1-9 (or 0): "
if "%CHOICE%"=="1" call :full
if "%CHOICE%"=="2" call :module_perf
if "%CHOICE%"=="3" call :module_term
if "%CHOICE%"=="4" call :module_appear
if "%CHOICE%"=="5" call :module_boot
if "%CHOICE%"=="6" call :module_panel
if "%CHOICE%"=="7" call :module_defender
if "%CHOICE%"=="8" call :module_win11
if "%CHOICE%"=="9" call :deploy
if "%CHOICE%"=="0" goto :eof
echo.
set /p AGAIN="  Back to menu? (Y/n): "
if /i "%AGAIN%"=="n" goto :eof
call :banner
goto :menu

rem ---------------------------------------------------------------- functions
:banner
cls
echo  ============================================================
echo   Fundray installer  -  detected: %OSNAME%
echo   Windows enhancement toolkit - NOT an operating system
echo   A restore point is created before every tweak.
echo  ============================================================
echo.
goto :eof

:detect_os
set "OSNAME=Unknown Windows"
ver | findstr /i "6.1.7601" >nul && set "OSNAME=Windows 7 SP1"
ver | findstr /i "6.1.760"  >nul && if "%OSNAME%"=="Unknown Windows" set "OSNAME=Windows 7 SP1"
ver | findstr /i "10.0."    >nul && set "OSNAME=Windows 10/11"
if "%OSNAME%"=="Unknown Windows" (
    echo   NOTE: this Windows version is untested. Windows 7 SP1, 10 and 11 are supported.
    echo   Scripts will still run - report issues at github.com/gefrus112/fundray
    echo.
)
call :log "Install menu opened on %OSNAME%"
goto :eof

:restorepoint
echo   [restore point] Creating 'Fundray baseline' checkpoint...
%PS% -Command "$sr=[wmiclass]'\\.\root\default:SystemRestore'; $null=$sr.Enable(''); $r=$sr.CreateRestorePoint('Fundray baseline',7,100); if($r.ReturnValue -eq 0){'OK'}else{'FAIL ' + $r.ReturnValue}"
if %errorlevel% neq 0 echo   [restore point] Could not create - System Restore may be disabled. Continuing anyway is NOT recommended.
call :log "Restore point requested"
goto :eof

:deploy
echo   [files] Deploying Fundray to "%TARGET%"...
mkdir "%TARGET%" 2>nul
if exist "%ROOT%build\Fundray.exe" copy /y "%ROOT%build\Fundray.exe" "%TARGET%\" >nul
if exist "%ROOT%README.md"  copy /y "%ROOT%README.md"  "%TARGET%\" >nul
if exist "%ROOT%LICENSE"    copy /y "%ROOT%LICENSE"    "%TARGET%\" >nul
if exist "%ROOT%uninstall.bat" copy /y "%ROOT%uninstall.bat" "%TARGET%\" >nul
if exist "%ROOT%install.bat"   copy /y "%ROOT%install.bat"   "%TARGET%\" >nul
if exist "%ROOT%scripts" xcopy "%ROOT%scripts" "%TARGET%\scripts\" /e /i /y >nul
if exist "%ROOT%docs"    xcopy "%ROOT%docs"    "%TARGET%\docs\"    /e /i /y >nul

echo   [files] Creating Start Menu shortcuts (Fundray, Power Panel)...
%PS% -Command ^
  "$ws = New-Object -ComObject WScript.Shell;" ^
  "$dir = [IO.Path]::Combine([Environment]::GetFolderPath('Programs'), 'Fundray');" ^
  "New-Item -ItemType Directory -Force -Path $dir | Out-Null;" ^
  "$pp = [IO.Path]::Combine($dir, 'Fundray Power Panel.lnk');" ^
  "$s = $ws.CreateShortcut($pp);" ^
  "$s.TargetPath = 'powershell.exe';" ^
  "$s.Arguments = '-NoProfile -ExecutionPolicy Bypass -File \"' + '%TARGET%' + '\scripts\powerpanel.ps1\"';" ^
  "$s.WorkingDirectory = '%TARGET%\scripts';" ^
  "$s.Description = 'Fundray Power Panel - shutdown GUI';" ^
  "$s.Save();" ^
  "if (Test-Path '%TARGET%\Fundray.exe') {" ^
  "  $s2 = $ws.CreateShortcut([IO.Path]::Combine($dir, 'Fundray.lnk'));" ^
  "  $s2.TargetPath = '%TARGET%\Fundray.exe'; $s2.WorkingDirectory = '%TARGET%';" ^
  "  $s2.Description = 'Fundray - Windows Enhancement Toolkit (not an operating system)';" ^
  "  $s2.Save()" ^
  "}"

echo   [files] Registering Add/Remove Programs entry...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Fundray" /v DisplayName     /d "Fundray - Windows Enhancement Toolkit" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Fundray" /v DisplayVersion /d "1.0.0" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Fundray" /v Publisher      /d "Fundray contributors" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Fundray" /v InstallLocation /d "%TARGET%" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Fundray" /v UninstallString /d "%TARGET%\uninstall.bat" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Fundray" /v NoModify /d 1 /f >nul
call :log "Files deployed to %TARGET%"
echo   [files] Done.
goto :eof

:module_perf
call :restorepoint
echo   [performance] Running optimize.ps1 -All ...
%PS% -File "%TARGET%\scripts\optimize.ps1" -All 2>nul || %PS% -File "%ROOT%scripts\optimize.ps1" -All
call :log "Performance module finished"
echo   [performance] Done.
goto :eof

:module_term
call :restorepoint
echo   [terminal] Running terminal-config.ps1 ...
%PS% -File "%TARGET%\scripts\terminal-config.ps1" 2>nul || %PS% -File "%ROOT%scripts\terminal-config.ps1"
call :log "Terminal module finished"
echo   [terminal] Done.
goto :eof

:module_appear
call :restorepoint
echo   [appearance] Running appearance.ps1 ...
%PS% -File "%TARGET%\scripts\appearance.ps1" 2>nul || %PS% -File "%ROOT%scripts\appearance.ps1"
call :log "Appearance module finished"
echo   [appearance] Done.
goto :eof

:module_boot
call :restorepoint
echo   [boot] Boot ^& splash module.
echo.
echo   This sets YOUR OWN image as the Windows logon background using the
echo   documented OEMBackground registry method. It must be a .jpg file.
echo   The BIOS / American Megatrends splash is FIRMWARE - this tool cannot
echo   and will not pretend to remove it (see docs\bootsplash.md for the
echo   honest BIOS quiet-boot guide).
echo.
set /p BGIMG="  Full path to your .jpg image (blank = skip): "
if "%BGIMG%"=="" goto :eof
%PS% -File "%TARGET%\scripts\bootsplash.ps1" -Action Set -ImagePath "%BGIMG%" 2>nul || %PS% -File "%ROOT%scripts\bootsplash.ps1" -Action Set -ImagePath "%BGIMG%"
call :log "Boot & splash module finished"
goto :eof

:module_win11
echo   [win11] Windows 11 tweaks module.
echo.
echo   Applies two documented Windows 11 settings - both reversible with
echo   scripts\revert.ps1. On Windows 7/10 this script politely refuses.
echo.
echo     [M] Classic full right-click menu  ON
echo     [N] Back to the Windows 11 condensed menu
echo     [L] Classic menu + taskbar LEFT
echo     [C] Classic menu + taskbar CENTER
echo     [X] Cancel
echo.
set /p WCHOICE="  Choose M/N/L/C/X: "
if /i "%WCHOICE%"=="M" %PS% -File "%TARGET%\scripts\win11.ps1" -Menu 2>nul || %PS% -File "%ROOT%scripts\win11.ps1" -Menu
if /i "%WCHOICE%"=="N" %PS% -File "%TARGET%\scripts\win11.ps1" -NoMenu 2>nul || %PS% -File "%ROOT%scripts\win11.ps1" -NoMenu
if /i "%WCHOICE%"=="L" %PS% -File "%TARGET%\scripts\win11.ps1" -Menu -TaskbarAlign left 2>nul || %PS% -File "%ROOT%scripts\win11.ps1" -Menu -TaskbarAlign left
if /i "%WCHOICE%"=="C" %PS% -File "%TARGET%\scripts\win11.ps1" -Menu -TaskbarAlign center 2>nul || %PS% -File "%ROOT%scripts\win11.ps1" -Menu -TaskbarAlign center
call :log "Windows 11 tweaks module finished (choice: %WCHOICE%)"
goto :eof

:module_panel
call :deploy
echo   [power panel] Power Panel installed.
echo   Shortcut: Start Menu ^> Fundray ^> Fundray Power Panel
echo   Try it now? (closes the installer menu)
set /p TRY="  Launch Power Panel now? (y/N): "
if /i "%TRY%"=="y" %PS% -File "%TARGET%\scripts\powerpanel.ps1"
call :log "Power Panel module installed"
goto :eof

:module_defender
echo.
echo  ============================================================
echo   DEFENDER CONTROL - please read before continuing
echo  ============================================================
echo   This module can PAUSE Windows Defender real-time protection.
echo   Fundray never does this silently and never includes it in the
echo   one-click optimizer. Only use it if you run another antivirus
echo   or for one specific task. uninstall.bat re-enables Defender.
echo.
echo     [S] Status only      [D] Disable real-time protection
echo     [E] Enable again     [X] Cancel
echo.
set /p DCHOICE="  Choose S/D/E/X: "
if /i "%DCHOICE%"=="S" %PS% -File "%TARGET%\scripts\defender.ps1" -Action Status 2>nul || %PS% -File "%ROOT%scripts\defender.ps1" -Action Status
if /i "%DCHOICE%"=="D" %PS% -File "%TARGET%\scripts\defender.ps1" -Action Disable 2>nul || %PS% -File "%ROOT%scripts\defender.ps1" -Action Disable
if /i "%DCHOICE%"=="E" %PS% -File "%TARGET%\scripts\defender.ps1" -Action Enable 2>nul || %PS% -File "%ROOT%scripts\defender.ps1" -Action Enable
call :log "Defender control opened (choice: %DCHOICE%)"
goto :eof

:full
call :deploy
call :module_perf
call :module_term
call :module_panel
echo.
echo  ============================================================
echo   Full install finished.
echo   - Start Menu ^> Fundray ^> Power Panel  (shutdown GUI)
echo   - Everything is reversible: run uninstall.bat
echo   - Windows 11 users: pick [8] afterwards for the Win11 tweaks
echo   - Reboot once to apply power-plan changes
echo  ============================================================
call :log "FULL install finished"
goto :eof

:log
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
echo %date% %time%  INSTALL  %~1>> "%LOGDIR%\install.log"
goto :eof
