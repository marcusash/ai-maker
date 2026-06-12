@echo off
echo.
echo   AI Maker v3 - Reset
echo   ====================
echo.

:: Remove skills
if exist "%USERPROFILE%\.copilot\skills\ai-maker-*" (
    for /d %%i in ("%USERPROFILE%\.copilot\skills\ai-maker-*") do rmdir /s /q "%%i"
    echo   Removed AI Maker skills
)
if exist "%USERPROFILE%\.copilot\skills\ai-workbench-*" (
    for /d %%i in ("%USERPROFILE%\.copilot\skills\ai-workbench-*") do rmdir /s /q "%%i"
    echo   Removed AI Workbench skills
)

:: Remove workspace
if exist "C:\GitHub\ai-workspace" (
    rmdir /s /q "C:\GitHub\ai-workspace"
    echo   Removed C:\GitHub\ai-workspace
)

:: Remove transaction log
if exist "%USERPROFILE%\.copilot\ai-maker" (
    rmdir /s /q "%USERPROFILE%\.copilot\ai-maker"
    echo   Removed transaction log
)

echo.
echo   Done. Run install.bat for a clean install.
echo.
pause
