@echo off
setlocal
echo.
echo   AI Maker v3 - Install
echo   =====================
echo.

:: Verify curl.exe is available
where curl.exe >nul 2>nul
if errorlevel 1 (
    echo   ERROR: curl.exe not found. Requires Windows 10 1803 or later.
    pause
    exit /b 1
)

:: Determine if running co-located or standalone (downloaded to TEMP)
set "BASE_URL=https://github.com/marcusash/ai-maker/releases/download/v3.0.6"
set "SCRIPT_SELF_DIR=%~dp0"
if exist "%SCRIPT_SELF_DIR%install-blue.ps1" if exist "%SCRIPT_SELF_DIR%install-red.ps1" if exist "%SCRIPT_SELF_DIR%migrate.ps1" if exist "%SCRIPT_SELF_DIR%ai-maker-lib.ps1" (
    set "SCRIPTDIR=%SCRIPT_SELF_DIR%"
    goto :ps_select
)

:: Standalone mode: create unique work dir to avoid stale files and concurrent runs
set "WORKDIR=%TEMP%\ai-maker-install-%RANDOM%%RANDOM%"
mkdir "%WORKDIR%" 2>nul
if not exist "%WORKDIR%" (
    echo   ERROR: Failed to create work directory: %WORKDIR%
    pause
    exit /b 1
)

echo   Downloading installer files...
call :download install-blue.ps1   || goto :download_failed
call :download install-red.ps1    || goto :download_failed
call :download migrate.ps1        || goto :download_failed
call :download ai-maker-lib.ps1   || goto :download_failed
set "SCRIPTDIR=%WORKDIR%\"
echo   [OK] Files downloaded
goto :ps_select

:download
curl.exe -fsSL --retry 3 -o "%WORKDIR%\%~1" "%BASE_URL%/%~1"
if errorlevel 1 exit /b 1
:: Verify file is non-empty (catches 0-byte downloads)
for %%F in ("%WORKDIR%\%~1") do if %%~zF LSS 100 exit /b 1
exit /b 0

:download_failed
echo   ERROR: Failed to download installer files. Check internet connection.
pause
exit /b 1

:ps_select
:: PS 7 is required. If pwsh is not installed, install it via winget first.
where pwsh >nul 2>nul
if not errorlevel 1 (
    set "PS=pwsh"
    echo   [OK] PowerShell 7 found
    goto :run_installer
)

echo   [INFO] PowerShell 7 not found - installing via winget...
where winget >nul 2>nul
if errorlevel 1 (
    echo.
    echo   ERROR: winget is not available. Install App Installer from the
    echo          Microsoft Store, or install PowerShell 7 manually from:
    echo          https://aka.ms/powershell-release?tag=stable
    echo.
    pause
    exit /b 1
)

winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent
if errorlevel 1 (
    echo.
    echo   ERROR: winget install of Microsoft.PowerShell failed.
    echo          Install PowerShell 7 manually from:
    echo          https://aka.ms/powershell-release?tag=stable
    echo.
    pause
    exit /b 1
)

:: Resolve pwsh.exe directly (PATH is not refreshed in current cmd session)
set "PS="
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PS=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PS if exist "%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe" set "PS=%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe"
if not defined PS (
    echo.
    echo   ERROR: PowerShell 7 installed but pwsh.exe could not be located.
    echo          Close this window, open a new one, and run install.bat again.
    echo.
    pause
    exit /b 1
)
echo   [OK] PowerShell 7 installed at %PS%

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
%PS% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTDIR%install-blue.ps1"
goto :done

:red
echo.
echo   Running Red Pill installer...
echo.
%PS% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTDIR%install-red.ps1"
goto :done

:migrate
echo.
echo   Running Migration tool...
echo.
%PS% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTDIR%migrate.ps1"
goto :done

:done
set "INSTALL_EXIT=%ERRORLEVEL%"
if not "%INSTALL_EXIT%"=="0" (
    echo.
    echo   Install failed. See errors above.
    pause
    exit /b %INSTALL_EXIT%
)
pause
exit /b 0
