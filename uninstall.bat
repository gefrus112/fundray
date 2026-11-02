@echo off
setlocal EnableExtensions
title Fundray uninstaller
rem ============================================================================
rem uninstall.bat - removes Fundray cleanly.
rem
rem   * re-enables Windows Defender if the opt-in switch was used
rem   * removes the logon background (boot & splash module)
rem   * offers to undo system tweaks first (scripts\revert.ps1)
rem   * offers to restore your Windows Terminal settings
rem   * removes Start Menu shortcut + Add/Remove Programs entry
rem   * deletes %ProgramFiles%\Fundray
rem
rem Run as administrator (self-elevates if needed).
rem ============================================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Administrator rights are required - requesting elevation...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "TARGET=%ProgramFiles%\Fundray"

if "%~1" neq "CLEANUP" (
    rem Relaunch from a temp copy so this folder can delete itself safely.
    copy /y "%~f0" "%TEMP%\fundray-uninstall.cmd" >nul
    "%TEMP%\fundray-uninstall.cmd" CLEANUP
    exit /b
)

echo ============================================
echo  Fundray uninstaller
echo ============================================
echo.
choice /c YN /m "Undo system tweaks now (runs scripts\revert.ps1)"
if errorlevel 2 goto skipTweaks
    powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%\scripts\revert.ps1"
:skipTweaks

choice /c YN /m "Restore your previous Windows Terminal settings"
if errorlevel 2 goto skipTerminal
    powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%\scripts\terminal-config.ps1" -Restore
:skipTerminal

echo.
echo Re-enabling Windows Defender real-time protection (opt-in module undo)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%\scripts\defender.ps1" -Action Enable 2>nul

echo Removing the Fundray logon background (boot & splash undo)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%\scripts\bootsplash.ps1" -Action Remove 2>nul

echo.
echo Removing shortcuts and registry entry...
powershell -NoProfile -Command ^
  "$dir = [IO.Path]::Combine([Environment]::GetFolderPath('Programs'), 'Fundray');" ^
  "if (Test-Path $dir) { Remove-Item -Path $dir -Recurse -Force }"
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Fundray" /f >nul 2>nul

echo Removing "%TARGET%"...
rd /s /q "%TARGET%" 2>nul

echo.
echo Fundray was removed. Any tweak you chose not to revert is still logged in
echo %%ProgramData%%\Fundray\logs - and Windows System Restore (rstrui.exe)
echo can always roll the machine back further.
del "%TEMP%\fundray-uninstall.cmd" >nul 2>nul
pause
