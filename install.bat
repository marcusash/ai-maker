@echo off
:: Find pwsh — check PATH, then common install locations
set "PWSH="
where pwsh >nul 2>nul && set "PWSH=pwsh" && goto :found_pwsh
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe" && goto :found_pwsh
if exist "%LOCALAPPDATA%\Microsoft\PowerShell\pwsh.exe" set "PWSH=%LOCALAPPDATA%\Microsoft\PowerShell\pwsh.exe" && goto :found_pwsh

:: Not found — install per-user (no admin needed)
echo.
echo   PowerShell 7 not found. Installing (no admin required)...
echo.
winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --scope user
echo.

:: Re-check after install
where pwsh >nul 2>nul && set "PWSH=pwsh" && goto :found_pwsh
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe" && goto :found_pwsh
if exist "%LOCALAPPDATA%\Microsoft\PowerShell\pwsh.exe" set "PWSH=%LOCALAPPDATA%\Microsoft\PowerShell\pwsh.exe" && goto :found_pwsh

echo.
echo   ERROR: Could not install PowerShell 7.
echo   Try running this in an admin terminal:
echo     winget install Microsoft.PowerShell
echo.
pause
exit /b 1

:found_pwsh

echo.
echo.
echo                       A I   M A K E R   v 3
echo.
echo              C H O O S E   Y O U R   R E A L I T Y
echo.
echo       The story you tell yourself about what you are capable of.
echo.
echo.
echo   ___________________________________________________________________________
echo.
echo     [1]  BLUE PILL
echo.
echo          Stay comfortable. Fastest path to your AI assistant.
echo.
echo          - 1 AI agent (AI Maker), 11 skills
echo          - WorkIQ: reads your M365 email, calendar, Teams
echo          - No GitHub account needed
echo          - ~2 minutes to install
echo.
echo   ___________________________________________________________________________
echo.
echo     [2]  RED PILL
echo.
echo          See the truth. Two agents, full technical power.
echo.
echo          - Everything in Blue, plus:
echo          - AI Workbench (11 more skills: code, security, CI/CD)
echo          - Private GitHub repo backs up your workspace
echo          - Restore on any machine in minutes
echo          - ~5 minutes to install (requires GitHub account)
echo.
echo   ___________________________________________________________________________
echo.
echo.

set /p "C=  Enter 1 or 2: "
if "%C%"=="1" set "S=install-blue.ps1"
if "%C%"=="2" set "S=install-red.ps1"
if not defined S (
    echo   Invalid choice. Run again.
    pause
    exit /b 1
)

curl.exe --silent -L -o "%TEMP%\ai-maker-lib.ps1" "https://github.com/marcusash/ai-maker/releases/latest/download/ai-maker-lib.ps1"
curl.exe --silent -L -o "%TEMP%\%S%" "https://github.com/marcusash/ai-maker/releases/latest/download/%S%"
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\%S%"
pause
