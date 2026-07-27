@echo off
:: AI Maker v3.0.11 post-install verify
:: Double-click after install.bat completes successfully.
:: Writes a single log file to C:\Temp\ai-maker-smoke\ and prints PASS/FAIL.

setlocal
echo.
echo   AI Maker v3.0.11 - Verify Install
echo   ==================================
echo.

where pwsh >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo   ERROR: PowerShell 7 not found. Run install.bat first.
    pause
    exit /b 1
)

pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify.ps1"
set EX=%ERRORLEVEL%

echo.
if %EX%==0 (
    echo   PASS - reply "Done"
) else (
    echo   FAIL - upload the log file shown above
)
echo.
pause
exit /b %EX%
