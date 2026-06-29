@echo off
echo.
echo   AI Maker v3 - Install
echo.

where pwsh >nul 2>nul || (
    echo   Installing PowerShell 7...
    winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
    set "PATH=%PATH%;%ProgramFiles%\PowerShell\7"
)

echo   [1] Blue Pill   [2] Red Pill   [3] Migration
set /p "C=  Choice: "
if "%C%"=="1" set "S=install-blue.ps1"
if "%C%"=="2" set "S=install-red.ps1"
if "%C%"=="3" set "S=migrate.ps1"

curl.exe --silent -L -o "%TEMP%\ai-maker-lib.ps1" "https://github.com/marcusash/ai-maker/releases/latest/download/ai-maker-lib.ps1"
curl.exe --silent -L -o "%TEMP%\%S%" "https://github.com/marcusash/ai-maker/releases/latest/download/%S%"
pwsh -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\%S%"
pause
