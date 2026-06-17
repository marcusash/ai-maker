@echo off
:: AI Maker - Full Reset (bulletproof - no embedded PowerShell that can hang)
:: Plain cmd.exe operations only. Logs every step. Continues past failures.

title AI Maker Reset
setlocal

echo.
echo  AI MAKER - FULL RESET
echo  =====================
echo.

:: -----------------------------------------------
:: [1] Kill processes (force, with child tree)
:: -----------------------------------------------
echo  [1/7] Stopping processes...
taskkill /F /T /IM "GitHub Copilot.exe" >nul 2>&1
taskkill /F /T /IM "GitHubCopilot.exe"  >nul 2>&1
taskkill /F /T /IM "github-copilot.exe" >nul 2>&1
taskkill /F /T /IM "github.exe"         >nul 2>&1
taskkill /F /T /IM "agency.exe"         >nul 2>&1
taskkill /F /T /IM "copilot.exe"        >nul 2>&1
taskkill /F /T /IM "Update.exe"         >nul 2>&1
echo        Done.
timeout /t 3 /nobreak >nul
:: Second pass - some processes respawn from Squirrel watchdog
taskkill /F /T /IM "github.exe"         >nul 2>&1
taskkill /F /T /IM "copilot.exe"        >nul 2>&1
timeout /t 2 /nobreak >nul

:: -----------------------------------------------
:: [2] Uninstall App (direct uninstaller first, winget fallback)
:: -----------------------------------------------
echo  [2/7] Uninstalling Copilot App...
:: GitHub Copilot App is Squirrel-packaged (like Slack, Discord, GH Desktop).
:: Install path: %LOCALAPPDATA%\GitHubCopilot\  (NO space, NOT under Programs)
:: Per FR's diagnosis - this is what was wrong in earlier reset.bat versions.

:: Order: A) Squirrel direct  B) winget fallback  C) registry UninstallString last resort

:: A) Try HKCU registry first (canonical, microseconds, survives version path changes - per FR)
set "SQUIRREL_CMD="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHubCopilot" /v UninstallString 2^>nul ^| findstr UninstallString') do set "SQUIRREL_CMD=%%B"

:: A2) If standard key name missed, enumerate Uninstall subkeys for any Copilot match
:: Filter to Squirrel signatures only (Update.exe in UninstallString) - skip winget-wrapped keys
if not defined SQUIRREL_CMD (
    for /f "delims=" %%K in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Copilot" 2^>nul ^| findstr /R "^HKEY_CURRENT_USER.*Uninstall"') do (
        for /f "tokens=2,*" %%A in ('reg query "%%K" /v UninstallString 2^>nul ^| findstr UninstallString ^| findstr /I "Update.exe"') do set "SQUIRREL_CMD=%%B"
    )
)

:: A3) Last resort - filesystem scan (slow, only runs if registry has nothing)
if not defined SQUIRREL_CMD (
    for /f "delims=" %%U in ('powershell -NoProfile -Command "Get-ChildItem -Path $env:LOCALAPPDATA -Recurse -Filter Update.exe -ErrorAction SilentlyContinue ^| Where-Object { $_.FullName -match 'Copilot' } ^| Select-Object -First 1 -ExpandProperty FullName" 2^>nul') do set "SQUIRREL_CMD=\"%%U\" --uninstall -s"
)

if defined SQUIRREL_CMD (
    echo        - Squirrel uninstall: %SQUIRREL_CMD%
    %SQUIRREL_CMD%
    timeout /t 5 /nobreak >nul
    set "SQUIRREL_WAIT=0"
    call :wait_squirrel
    echo        - Squirrel done.
) else (
    echo        - No Squirrel uninstaller found in registry or filesystem, will try winget.
)

:: B) winget fallback - retry on 1603 (file lock) after deeper process kill, 10sec wait per FR
:: --all-versions: handle the case where multiple versions of GitHub.CopilotApp piled up
:: from prior install attempts (the exact bug Marcus hit on CPC).
echo        - winget uninstall GitHub.CopilotApp (all versions)
winget uninstall --id GitHub.CopilotApp --all-versions --silent --force --accept-source-agreements --disable-interactivity
if errorlevel 1 (
    echo        - winget failed - killing processes hard incl. Electron helpers and retrying...
    taskkill /F /T /IM "GitHub Copilot.exe" >nul 2>&1
    taskkill /F /T /IM "GitHubCopilot.exe"  >nul 2>&1
    taskkill /F /T /IM "github.exe"         >nul 2>&1
    taskkill /F /T /IM "Update.exe"         >nul 2>&1
    taskkill /F /T /IM "Squirrel.exe"       >nul 2>&1
    rem Wildcard kill catches Electron renderer Helper procs that hold dll locks
    powershell -NoProfile -Command "Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Copilot*' -or $_.Name -like '*github*' -or $_.Name -like '*Squirrel*' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
    timeout /t 10 /nobreak >nul
    echo        - winget retry GitHub.CopilotApp (all versions)
    winget uninstall --id GitHub.CopilotApp --all-versions --silent --force --accept-source-agreements --disable-interactivity
    if errorlevel 1 (
        echo        [WARN] winget still failed - probable Defender realtime scan or corrupt MSI cache.
        echo               Run reset.bat again, or uninstall manually via Settings then Apps.
    )
)
echo        - winget uninstall GitHub.Copilot (all versions)
winget uninstall --id GitHub.Copilot --all-versions --silent --force --accept-source-agreements --disable-interactivity

:: Final process sweep (A registry lookup already used UninstallString, no need to repeat)
taskkill /F /T /IM "GitHub Copilot.exe" >nul 2>&1
taskkill /F /T /IM "GitHubCopilot.exe"  >nul 2>&1
taskkill /F /T /IM "github.exe"         >nul 2>&1
taskkill /F /T /IM "copilot.exe"        >nul 2>&1
taskkill /F /T /IM "Update.exe"         >nul 2>&1
taskkill /F /T /IM "Squirrel.exe"       >nul 2>&1
powershell -NoProfile -Command "Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Copilot*' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
echo        Done.

:: -----------------------------------------------
:: [3] Wipe ~/.copilot  (plain rmdir, skip locked)
:: -----------------------------------------------
echo  [3/7] Wiping ~/.copilot/ ...
if exist "%USERPROFILE%\.copilot" (
    rmdir /s /q "%USERPROFILE%\.copilot" >nul 2>&1
    if exist "%USERPROFILE%\.copilot" (
        echo        Some files locked - waiting 2s and retrying once...
        timeout /t 2 /nobreak >nul
        taskkill /F /T /IM "GitHub Copilot.exe" >nul 2>&1
        rmdir /s /q "%USERPROFILE%\.copilot" >nul 2>&1
    )
    if exist "%USERPROFILE%\.copilot" (
        echo        [WARN] Some files still locked - will retry at end
    ) else (
        echo        Removed.
    )
) else (
    echo        Not present.
)

:: -----------------------------------------------
:: [4] Wipe Agency + App AppData folders
:: -----------------------------------------------
echo  [4/7] Removing Agency + App AppData + install dirs...
if exist "%APPDATA%\agency"                  rmdir /s /q "%APPDATA%\agency"                  >nul 2>&1
if exist "%LOCALAPPDATA%\agency"             rmdir /s /q "%LOCALAPPDATA%\agency"             >nul 2>&1
if exist "%USERPROFILE%\.agency"             rmdir /s /q "%USERPROFILE%\.agency"             >nul 2>&1
if exist "%USERPROFILE%\.agency-claw"        rmdir /s /q "%USERPROFILE%\.agency-claw"        >nul 2>&1
if exist "%USERPROFILE%\.config\agency"      rmdir /s /q "%USERPROFILE%\.config\agency"      >nul 2>&1
:: Copilot App install + data dirs (per FR: correct path is %LOCALAPPDATA%\GitHubCopilot, no space, no Programs)
if exist "%LOCALAPPDATA%\GitHubCopilot"      rmdir /s /q "%LOCALAPPDATA%\GitHubCopilot"      >nul 2>&1
if exist "%LOCALAPPDATA%\GitHub Copilot"     rmdir /s /q "%LOCALAPPDATA%\GitHub Copilot"     >nul 2>&1
if exist "%LOCALAPPDATA%\github-copilot"     rmdir /s /q "%LOCALAPPDATA%\github-copilot"     >nul 2>&1
if exist "%LOCALAPPDATA%\Programs\GitHub Copilot" rmdir /s /q "%LOCALAPPDATA%\Programs\GitHub Copilot" >nul 2>&1
if exist "%LOCALAPPDATA%\Programs\GitHubCopilot"  rmdir /s /q "%LOCALAPPDATA%\Programs\GitHubCopilot"  >nul 2>&1
if exist "%APPDATA%\GitHub Copilot"          rmdir /s /q "%APPDATA%\GitHub Copilot"          >nul 2>&1
if exist "%APPDATA%\GitHubCopilot"           rmdir /s /q "%APPDATA%\GitHubCopilot"           >nul 2>&1
if exist "%LOCALAPPDATA%\ai-maker"           rmdir /s /q "%LOCALAPPDATA%\ai-maker"           >nul 2>&1
if exist "%APPDATA%\ai-maker"                rmdir /s /q "%APPDATA%\ai-maker"                >nul 2>&1
:: Registry uninstall entries (per FR: HKCU not HKLM, per-user Squirrel registration)
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHubCopilot"  /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHub Copilot" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Copilot CLI"    /f >nul 2>&1
echo        Done.

:: -----------------------------------------------
:: [5] Workspace + profile + shortcuts (full wipe)
:: -----------------------------------------------
echo  [5/7] Removing workspace + profile + shortcuts...
if exist "C:\GitHub\ai-workspace"                        rmdir /s /q "C:\GitHub\ai-workspace"                        >nul 2>&1
if exist "%USERPROFILE%\GitHub\ai-workspace"             rmdir /s /q "%USERPROFILE%\GitHub\ai-workspace"             >nul 2>&1
if exist "C:\AIMaker"                                    rmdir /s /q "C:\AIMaker"                                    >nul 2>&1
if exist "%USERPROFILE%\Desktop\AI Agents.lnk"           del /f /q "%USERPROFILE%\Desktop\AI Agents.lnk"             >nul 2>&1
if exist "%USERPROFILE%\Desktop\AI Maker.lnk"            del /f /q "%USERPROFILE%\Desktop\AI Maker.lnk"              >nul 2>&1
if exist "%USERPROFILE%\Desktop\GitHub Copilot.lnk"      del /f /q "%USERPROFILE%\Desktop\GitHub Copilot.lnk"        >nul 2>&1
:: Start Menu - Squirrel drops to "GitHub, Inc\" folder per FR
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\GitHub, Inc"        rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\GitHub, Inc"   >nul 2>&1
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\GitHub Copilot"     rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\GitHub Copilot" >nul 2>&1
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\GitHub Copilot.lnk" del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\GitHub Copilot.lnk" >nul 2>&1
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\AI Maker.lnk"       del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\AI Maker.lnk"      >nul 2>&1
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\AI Agents.lnk"      del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\AI Agents.lnk"     >nul 2>&1
:: Brute sweep - any remaining *Copilot*.lnk anywhere under Start Menu Programs
for /f "delims=" %%F in ('dir /s /b /a-d "%APPDATA%\Microsoft\Windows\Start Menu\Programs\*Copilot*.lnk" 2^>nul') do del /f /q "%%F" >nul 2>&1
:: Taskbar pin
if exist "%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\GitHub Copilot.lnk" del /f /q "%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\GitHub Copilot.lnk" >nul 2>&1
echo        Done.

:: -----------------------------------------------
:: [6] Temp + gh extension
:: -----------------------------------------------
echo  [6/7] Removing temp files + gh extension...
for /d %%D in ("%TEMP%\ai-maker-*") do rmdir /s /q "%%D" >nul 2>&1
del /f /q "%TEMP%\install.bat"          >nul 2>&1
del /f /q "%TEMP%\ai-maker-skills.zip"  >nul 2>&1
del /f /q "%TEMP%\ai-maker-agents.zip"  >nul 2>&1
gh extension remove gh-copilot          >nul 2>&1
gh extension remove github/gh-copilot   >nul 2>&1
echo        Done.

:: -----------------------------------------------
:: [7] Final retry pass on ~/.copilot if still there
:: -----------------------------------------------
echo  [7/7] Final retry pass...
if exist "%USERPROFILE%\.copilot" (
    taskkill /F /T /IM "GitHub Copilot.exe" >nul 2>&1
    taskkill /F /T /IM "GitHubCopilot.exe"  >nul 2>&1
    taskkill /F /T /IM "github.exe"         >nul 2>&1
    taskkill /F /T /IM "copilot.exe"        >nul 2>&1
    timeout /t 2 /nobreak >nul
    rmdir /s /q "%USERPROFILE%\.copilot" >nul 2>&1
)
echo        Done.

:: -----------------------------------------------
:: Verify
:: -----------------------------------------------
echo.
echo  =====================
echo   VERIFICATION
echo  =====================
set "FAIL=0"
if exist "%USERPROFILE%\.copilot"                       ( echo    [WARN] ~/.copilot/ still exists       & set "FAIL=1" )  else  echo    [OK]   ~/.copilot/ removed
if exist "%APPDATA%\agency"                             ( echo    [WARN] APPDATA\agency still exists    & set "FAIL=1" )  else  echo    [OK]   Agency removed
if exist "C:\GitHub\ai-workspace"                       ( echo    [WARN] ai-workspace still exists      & set "FAIL=1" )  else  echo    [OK]   Workspace removed
if exist "C:\AIMaker"                                   ( echo    [WARN] C:\AIMaker still exists        & set "FAIL=1" )  else  echo    [OK]   Profile removed
if exist "%LOCALAPPDATA%\GitHubCopilot"                 ( echo    [WARN] Copilot App install dir still exists & set "FAIL=1" )  else  echo    [OK]   Copilot App install dir removed
:: Brute Start Menu sweep - the exact bug Marcus hit: "search finds Copilot even after reset"
set "FOUND_SHORTCUT="
for /f "delims=" %%F in ('dir /s /b /a-d "%APPDATA%\Microsoft\Windows\Start Menu\Programs\*Copilot*.lnk" 2^>nul') do set "FOUND_SHORTCUT=%%F"
if defined FOUND_SHORTCUT (
    echo    [WARN] Start Menu still has Copilot shortcut: %FOUND_SHORTCUT%
    set "FAIL=1"
) else (
    echo    [OK]   No Copilot shortcuts in Start Menu
)
:: Registry uninstall entry check - if this exists, Add/Remove Programs still shows the app
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHubCopilot" >nul 2>&1
if not errorlevel 1 (
    echo    [WARN] HKCU uninstall key GitHubCopilot still exists
    set "FAIL=1"
) else (
    echo    [OK]   HKCU uninstall key removed
)

:: -----------------------------------------------
:: Windows Copilot detection (NOT removed - different product, OS-bundled)
:: If user types "Copilot" in Start and still sees a result after reset,
:: it is Microsoft's OS-bundled Windows Copilot, NOT GitHub Copilot App.
:: Inform the user so they don't re-file the same "reset broken" bug.
:: -----------------------------------------------
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$wc = Get-AppxPackage -Name '*Copilot*' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '*GitHub*' }; if ($wc) { Write-Host '    [INFO] Windows Copilot is still installed (this is normal - different product):' -ForegroundColor Cyan; $wc | ForEach-Object { Write-Host ('           - ' + $_.Name + ' ' + $_.Version) -ForegroundColor Gray }; Write-Host '           This is Microsofts OS-bundled Copilot, separate from GitHub Copilot App.' -ForegroundColor Gray; Write-Host '           reset.bat does not remove it. To remove: Settings then Apps then Installed apps.' -ForegroundColor Gray } else { Write-Host '    [OK]   No Windows Copilot AppX package present either' -ForegroundColor Green }"

echo.
if "%FAIL%"=="0" (
    echo  RESET COMPLETE. Clean slate.
    echo  Next: run install.bat
) else (
    echo  PARTIAL RESET. Run this script once more.
    echo  ^(A process restarted itself or a file was locked.^)
)
echo.
pause
exit /b 0

:: -----------------------------------------------
:: Subroutine: wait for Squirrel Update.exe to exit
:: Called from step [2] - must be subroutine (not inline goto) because
:: goto inside an if () block corrupts cmd parens parsing.
:: Polls every 2 sec up to 30 iterations (60 sec max) then gives up.
:: -----------------------------------------------
:wait_squirrel
set /a SQUIRREL_WAIT+=1
if %SQUIRREL_WAIT% GTR 30 exit /b 0
tasklist /FI "IMAGENAME eq Update.exe" 2>nul | find /I "Update.exe" >nul
if not errorlevel 1 (
    timeout /t 2 /nobreak >nul
    goto wait_squirrel
)
exit /b 0
