@echo off
setlocal enabledelayedexpansion
echo.
echo   AI Maker v3 - Install
echo   =====================
echo.

set "RELEASE_BASE=https://github.com/marcusash/ai-maker/releases/download/v3.0.12"

:: Unblock files (only relevant when running from extracted zip)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem '%~dp0' -Recurse -Filter *.ps1 | Unblock-File" 2>nul

:: Check if pwsh exists
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    echo   [OK] PowerShell 7 found
    goto :check_deps
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

:check_deps
:: If companion scripts are missing, download them (one-liner install path)
if not exist "%~dp0install-blue.ps1" goto :download_deps
if not exist "%~dp0install-red.ps1" goto :download_deps
if not exist "%~dp0ai-maker-lib.ps1" goto :download_deps
if not exist "%~dp0migrate.ps1" goto :download_deps
goto :check_agents

:download_deps
echo   Downloading installer files...
curl.exe --fail --show-error --location --retry 3 -o "%~dp0install-blue.ps1.tmp" "%RELEASE_BASE%/install-blue.ps1"
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Failed to download install-blue.ps1 (check your internet connection)
    del "%~dp0install-blue.ps1.tmp" 2>nul
    pause
    exit /b 1
)
move /y "%~dp0install-blue.ps1.tmp" "%~dp0install-blue.ps1" >nul

curl.exe --fail --show-error --location --retry 3 -o "%~dp0install-red.ps1.tmp" "%RELEASE_BASE%/install-red.ps1"
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Failed to download install-red.ps1
    del "%~dp0install-red.ps1.tmp" 2>nul
    pause
    exit /b 1
)
move /y "%~dp0install-red.ps1.tmp" "%~dp0install-red.ps1" >nul

curl.exe --fail --show-error --location --retry 3 -o "%~dp0ai-maker-lib.ps1.tmp" "%RELEASE_BASE%/ai-maker-lib.ps1"
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Failed to download ai-maker-lib.ps1
    del "%~dp0ai-maker-lib.ps1.tmp" 2>nul
    pause
    exit /b 1
)
move /y "%~dp0ai-maker-lib.ps1.tmp" "%~dp0ai-maker-lib.ps1" >nul

curl.exe --fail --show-error --location --retry 3 -o "%~dp0migrate.ps1.tmp" "%RELEASE_BASE%/migrate.ps1"
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Failed to download migrate.ps1
    del "%~dp0migrate.ps1.tmp" 2>nul
    pause
    exit /b 1
)
move /y "%~dp0migrate.ps1.tmp" "%~dp0migrate.ps1" >nul

echo   [OK] Installer files ready

:check_agents
:: If agents directory is missing, download it (one-liner install path)
if exist "%~dp0agents" goto :run_installer
echo   Downloading agent files...
curl.exe --fail --show-error --location --retry 3 -o "%~dp0agents.zip.tmp" "%RELEASE_BASE%/agents.zip"
if %ERRORLEVEL% neq 0 (
    echo   WARNING: Could not download agents.zip (agent identity files will be skipped)
    del "%~dp0agents.zip.tmp" 2>nul
    goto :run_installer
)
move /y "%~dp0agents.zip.tmp" "%~dp0agents.zip" >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%~dp0agents.zip' -DestinationPath '%~dp0' -Force"
del "%~dp0agents.zip" 2>nul
echo   [OK] Agent files ready

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
if exist "%~dp0skills" (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-blue.ps1" -SkillsSource "%~dp0skills"
) else (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-blue.ps1"
)
goto :done

:red
echo.
echo   Running Red Pill installer...
echo.
if exist "%~dp0skills" (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-red.ps1" -SkillsSource "%~dp0skills"
) else (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-red.ps1"
)
goto :done

:migrate
echo.
echo   Running Migration tool...
echo.
if exist "%~dp0skills" (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0migrate.ps1" -SkillsSource "%~dp0skills"
) else (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0migrate.ps1"
)
goto :done

:done
if %ERRORLEVEL% neq 0 (
    echo.
    echo   Install failed. See errors above.
)
pause
