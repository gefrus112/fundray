@echo off
setlocal EnableExtensions
title Fundray build
rem ============================================================================
rem build.bat — compiles the Fundray GUI without Visual Studio.
rem
rem Uses the C# compiler that ships with the .NET Framework 4.x (present on
rem Windows 7 SP1 with .NET 4.8, and on Windows 10/11 out of the box), so this
rem is the zero-dependency build path. The language level is C# 5 on purpose.
rem
rem Output: build\Fundray.exe (+ SHA256 printed for release transparency).
rem
rem Alternative: open src\Fundray.csproj with Visual Studio / MSBuild (.NET 4.8).
rem ============================================================================

set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
    echo [ERROR] No .NET Framework C# compiler was found on this machine.
    echo         Install .NET Framework 4.8 and run this script again.
    exit /b 1
)

if not exist build mkdir build

echo [1/2] Compiling src\FundrayMain.cs -^> build\Fundray.exe  (.NET Framework 4.8, WinForms)
"%CSC%" /nologo /target:winexe /out:build\Fundray.exe /optimize+ ^
    /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Core.dll ^
    src\FundrayMain.cs
if errorlevel 1 (
    echo [ERROR] Compilation failed.
    exit /b 1
)

echo [2/2] Build succeeded.
echo.
echo Transparency: SHA256 of build\Fundray.exe
certutil -hashfile build\Fundray.exe SHA256 | findstr /v "hash certutil"
echo.
echo Next steps:
echo   install.bat    (run as administrator) - copies files and creates shortcuts
echo   Fundray.exe    - run it and create a restore point before optimizing
endlocal
