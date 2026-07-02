@echo off
setlocal
title New User PC Setup - Bootstrap
echo.
echo   =============================================
echo     new-user-pc-setup - Bootstrap
echo   =============================================
echo.
echo   This will set up your PC for AI-powered work.
echo   It takes about 5 minutes.
echo.
pause

REM === Find or install PowerShell 7 ===
set "PWSH="
where pwsh >nul 2>&1 && set "PWSH=pwsh" && goto :havepwsh
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe" && goto :havepwsh
if exist "%LOCALAPPDATA%\Microsoft\PowerShell\pwsh.exe" set "PWSH=%LOCALAPPDATA%\Microsoft\PowerShell\pwsh.exe" && goto :havepwsh

echo   Installing PowerShell 7...
winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe" && goto :havepwsh
echo   ERROR: Could not install PowerShell 7.
echo   Please install it manually: winget install Microsoft.PowerShell
pause
exit /b 1

:havepwsh
echo   [OK] PowerShell 7: %PWSH%
echo.

REM === Find or install Git ===
where git >nul 2>&1 && goto :havegit
if exist "%ProgramFiles%\Git\cmd\git.exe" goto :havegit
echo   Installing Git...
winget install --id Git.Git --source winget --accept-source-agreements --accept-package-agreements

:havegit

REM === Find or install GitHub CLI ===
where gh >nul 2>&1 && goto :havegh
if exist "%ProgramFiles%\GitHub CLI\gh.exe" goto :havegh
echo   Installing GitHub CLI...
winget install --id GitHub.cli --source winget --accept-source-agreements --accept-package-agreements

:havegh

REM === Refresh PATH ===
set "PATH=%ProgramFiles%\Git\cmd;%ProgramFiles%\GitHub CLI;%PATH%"

REM === Authenticate with GitHub ===
echo.
echo   Signing in to GitHub...
echo   A browser window will open. Sign in with your Microsoft GitHub account.
echo.
gh auth login --web --git-protocol https
if errorlevel 1 (
    echo.
    echo   If the browser method didn't work, try this instead:
    gh auth login
)

REM === Clone the setup repo ===
echo.
if exist "%USERPROFILE%\GitHub\new-user-pc-setup\install.ps1" (
    echo   Setup repo already exists. Updating...
    cd /d "%USERPROFILE%\GitHub\new-user-pc-setup"
    git pull
) else (
    echo   Downloading setup files...
    if not exist "%USERPROFILE%\GitHub" mkdir "%USERPROFILE%\GitHub"
    gh repo clone marcusash_microsoft/new-user-pc-setup "%USERPROFILE%\GitHub\new-user-pc-setup"
)

REM === Run the full installer ===
echo.
if exist "%USERPROFILE%\GitHub\new-user-pc-setup\install.ps1" (
    cd /d "%USERPROFILE%\GitHub\new-user-pc-setup"
    "%PWSH%" -ExecutionPolicy Bypass -File install.ps1 -Tier Red
) else (
    echo   ERROR: Could not download setup files.
    echo   Make sure you completed the GitHub sign-in step.
    pause
    exit /b 1
)
