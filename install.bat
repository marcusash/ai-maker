@echo off
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
echo          - 2 AI agents (AI Maker + AI Workbench), 22 skills
echo          - WorkIQ: reads your M365 email, calendar, Teams
echo          - Private GitHub repo backs up your workspace
echo          - Restore on any machine in minutes
echo          - ~5 minutes to install (requires GitHub account)
echo.
echo   ___________________________________________________________________________
echo.
echo.

where pwsh >nul 2>nul || (
    echo   Installing PowerShell 7...
    winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
    set "PATH=%PATH%;%ProgramFiles%\PowerShell\7"
)

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
pwsh -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\%S%"
pause
