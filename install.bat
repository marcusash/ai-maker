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
set "BASE_URL=https://github.com/marcusash/ai-maker/releases/download/v3.0.7"
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
echo.
echo   ============================================================
echo   ERROR — DOWNLOAD FAILED
echo   ============================================================
echo.
echo   Couldn't download installer files from GitHub.
echo.
echo   How to fix:
echo     1. Check your internet connection.
echo     2. If on corp network, verify github.com is reachable:
echo        curl.exe -I https://github.com
echo     3. Retry: close this window, open a new one, run install.bat again.
echo   ============================================================
echo.
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
echo.
echo   ============================================================
echo   HEADS UP — TWO-STEP INSTALL
echo   ============================================================
echo   Windows needs a fresh terminal session to recognize newly
echo   installed PowerShell 7. After install completes, you may need
echo   to close this window and run install.bat ONE MORE TIME.
echo   This is normal — install resumes from where it left off.
echo   ============================================================
echo.
where winget >nul 2>nul
if errorlevel 1 (
    echo.
    echo   ============================================================
    echo   ERROR — winget IS NOT AVAILABLE
    echo   ============================================================
    echo.
    echo   What this means:
    echo     winget is Windows' built-in app installer. It ships with
    echo     "App Installer" from the Microsoft Store.
    echo.
    echo   How to fix:
    echo     1. Open Microsoft Store.
    echo     2. Search for "App Installer" and install it.
    echo        OR install PowerShell 7 directly from:
    echo        https://aka.ms/powershell-release?tag=stable
    echo     3. Close this window, open a new one, run install.bat again.
    echo   ============================================================
    echo.
    pause
    exit /b 1
)

winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent
if errorlevel 1 (
    echo.
    echo   ============================================================
    echo   ERROR — POWERSHELL 7 INSTALL FAILED
    echo   ============================================================
    echo.
    echo   winget couldn't install Microsoft.PowerShell.
    echo.
    echo   How to fix:
    echo     1. Install PowerShell 7 manually:
    echo        https://aka.ms/powershell-release?tag=stable
    echo     2. Close this window, open a new one, run install.bat again.
    echo   ============================================================
    echo.
    pause
    exit /b 1
)

:: Resolve pwsh.exe directly (PATH is not refreshed in current cmd session)
set "PS="
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PS=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PS if exist "%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe" set "PS=%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe"
if not defined PS if exist "%LocalAppData%\Microsoft\WindowsApps\pwsh.exe" set "PS=%LocalAppData%\Microsoft\WindowsApps\pwsh.exe"
if not defined PS (
    for /f "delims=" %%P in ('dir /b /s "%ProgramFiles%\WindowsApps\Microsoft.PowerShell_*\pwsh.exe" 2^>nul') do (
        set "PS=%%P"
        goto :ps_found
    )
)
:ps_found
if not defined PS (
    echo.
    echo   ============================================================
    echo   ACTION REQUIRED — RESTART YOUR TERMINAL
    echo   ============================================================
    echo.
    echo   PowerShell 7 was just installed, but Windows needs a fresh
    echo   terminal session to see the new pwsh.exe on PATH.
    echo.
    echo   To finish the install:
    echo.
    echo     1. Close this window.
    echo     2. Open a NEW PowerShell or Terminal window.
    echo     3. Paste the same command you used to start install:
    echo.
    echo        curl.exe -sSL -o %%TEMP%%\install.bat https://github.com/marcusash/ai-maker/releases/download/v3.0.7/install.bat ^&^& %%TEMP%%\install.bat
    echo.
    echo   This is normal — install resumes from where it left off.
    echo   ============================================================
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
    echo   ============================================================
    echo   ERROR — INSTALL FAILED ^(exit code %INSTALL_EXIT%^)
    echo   ============================================================
    echo.
    echo   See the error messages above this banner for details.
    echo.
    echo   Common fixes:
    echo     - If a script error: scroll up, find the red message,
    echo       paste it back to FP for help.
    echo     - If install hung: close this window, run install.bat again.
    echo     - If "access denied": run terminal as Administrator and retry.
    echo   ============================================================
    echo.
    pause
    exit /b %INSTALL_EXIT%
)
echo.
echo   ============================================================
echo   SUCCESS — INSTALL COMPLETE
echo   ============================================================
echo.
echo   What's next:
echo     The GitHub Copilot App should be launching ^(or already open^).
echo     Sign in with your @microsoft.com account if prompted.
echo.
echo     Open a new session in the App and try: "hello"
echo   ============================================================
echo.
pause
exit /b 0
