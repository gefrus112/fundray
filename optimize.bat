@echo off
setlocal EnableExtensions
title Fundray performance optimizer (command line)
rem ============================================================================
rem optimize.bat — command-line entry point into scripts\optimize.ps1.
rem
rem Examples:
rem   optimize.bat -All
rem   optimize.bat -PowerPlan -Temp -KeepEffects
rem   optimize.bat -Services -Startup
rem
rem The same tweaks are available with per-item checkboxes in the Fundray GUI.
rem ============================================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Administrator rights are required - requesting elevation...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\optimize.ps1" %*
echo.
pause
