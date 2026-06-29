@echo off
setlocal enabledelayedexpansion
echo.
echo   AI Maker v3 - Install
echo   =====================
echo.

:: Unblock files (if running from extracted zip)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem '%~dp0' -Recurse -Filter *.ps1 | Unblock-File" 2>nul

:: Check if pwsh exists
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    echo   [OK] PowerShell 7 found
    goto :run_installer
)

:: Install PowerShell 7
echo   PowerShell 7 not found. Installing...
where winget >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo   ERROR: winget not found. Install from https://aka.ms/getwinget
    pause
    exit /b 1
)

winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Failed to install PowerShell 7.
    pause
    exit /b 1
)

:: Refresh PATH
set "PATH=%PATH%;%ProgramFiles%\PowerShell\7"

:: Verify
where pwsh >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo.
    echo   PowerShell 7 installed but not in PATH yet.
    echo   Close this window, open a new one, and run install.bat again.
    echo.
    pause
    exit /b 0
)

echo   [OK] PowerShell 7 installed

:run_installer
echo.
echo   Which path do you want?
echo.
echo     [1] Blue Pill  - Simple setup, no git, AI Maker skills only
echo     [2] Red Pill   - Full setup, git backup, all 22 skills
echo     [3] Migration  - Move existing CLI install to the App
echo.
set /p "CHOICE=  Enter 1, 2, or 3: "

if "%CHOICE%"=="1" goto :blue
if "%CHOICE%"=="2" goto :red
if "%CHOICE%"=="3" goto :migrate
echo   Invalid choice.
goto :run_installer

:blue
echo.
echo   Running Blue Pill installer...
echo.
if exist "%~dp0installers\install-blue.ps1" (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-blue.ps1" -SkillsSource "%~dp0skills"
) else (
    echo   Downloading installer files...
    curl.exe --silent -L -o "%TEMP%\ai-maker-lib.ps1" "https://github.com/marcusash/ai-maker/releases/latest/download/ai-maker-lib.ps1"
    if %ERRORLEVEL% neq 0 ( echo   ERROR: Failed to download ai-maker-lib.ps1 & pause & exit /b 1 )
    echo   [OK] ai-maker-lib.ps1
    curl.exe --silent -L -o "%TEMP%\install-blue.ps1" "https://github.com/marcusash/ai-maker/releases/latest/download/install-blue.ps1"
    if %ERRORLEVEL% neq 0 ( echo   ERROR: Failed to download install-blue.ps1 & pause & exit /b 1 )
    echo   [OK] install-blue.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\install-blue.ps1"
)
goto :done

:red
echo.
echo   Running Red Pill installer...
echo.
if exist "%~dp0installers\install-red.ps1" (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\install-red.ps1" -SkillsSource "%~dp0skills"
) else (
    echo   Downloading installer files...
    curl.exe --silent -L -o "%TEMP%\ai-maker-lib.ps1" "https://github.com/marcusash/ai-maker/releases/latest/download/ai-maker-lib.ps1"
    if %ERRORLEVEL% neq 0 ( echo   ERROR: Failed to download ai-maker-lib.ps1 & pause & exit /b 1 )
    echo   [OK] ai-maker-lib.ps1
    curl.exe --silent -L -o "%TEMP%\install-red.ps1" "https://github.com/marcusash/ai-maker/releases/latest/download/install-red.ps1"
    if %ERRORLEVEL% neq 0 ( echo   ERROR: Failed to download install-red.ps1 & pause & exit /b 1 )
    echo   [OK] install-red.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\install-red.ps1"
)
goto :done

:migrate
echo.
echo   Running Migration tool...
echo.
if exist "%~dp0installers\migrate.ps1" (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0installers\migrate.ps1" -SkillsSource "%~dp0skills"
) else (
    echo   Downloading installer files...
    curl.exe --silent -L -o "%TEMP%\ai-maker-lib.ps1" "https://github.com/marcusash/ai-maker/releases/latest/download/ai-maker-lib.ps1"
    if %ERRORLEVEL% neq 0 ( echo   ERROR: Failed to download ai-maker-lib.ps1 & pause & exit /b 1 )
    echo   [OK] ai-maker-lib.ps1
    curl.exe --silent -L -o "%TEMP%\migrate.ps1" "https://github.com/marcusash/ai-maker/releases/latest/download/migrate.ps1"
    if %ERRORLEVEL% neq 0 ( echo   ERROR: Failed to download migrate.ps1 & pause & exit /b 1 )
    echo   [OK] migrate.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\migrate.ps1"
)
goto :done

:done
if %ERRORLEVEL% neq 0 (
    echo.
    echo   Install failed. See errors above.
)
pause
