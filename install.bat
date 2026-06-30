@echo off
where pwsh >nul 2>nul || (
    echo   Installing PowerShell 7...
    winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
    set "PATH=%PATH%;%ProgramFiles%\PowerShell\7"
)

:: Write colored menu to temp script
set "MENU=%TEMP%\ai-maker-menu.ps1"
(
echo $e=[char]27
echo $g="$e[92m";$gb="$e[92;1m";$bb="$e[94;1m";$rb="$e[91;1m";$r="$e[91m";$d="$e[90m";$w="$e[97m";$n="$e[0m"
echo Write-Host ''
echo Write-Host "  $d ア ァ カ サ タ ナ ハ マ ヤ ャ ラ ワ ガ ザ ダ バ パ イ ィ キ シ チ$n"
echo Write-Host ''
echo Write-Host "  $gb      ▄▀▄  █   █▀▄▀█ ▄▀▄ █▄▀ █▀▀ █▀▄$n"
echo Write-Host "  $gb      █▀█  █   █ ▀ █ █▀█ █▀▄ █▀▀ █▀▄$n"
echo Write-Host "  $gb      █ █  █   █   █ █ █ █ █ █▄▄ █ █$n"
echo Write-Host ''
echo Write-Host "  $g       C H O O S E   Y O U R   R E A L I T Y$n"
echo Write-Host "  $w  The story you tell yourself about what you are capable of.$n"
echo Write-Host ''
echo Write-Host "  $d ア ァ カ サ タ ナ ハ マ ヤ ャ ラ ワ ガ ザ ダ バ パ イ ィ キ シ チ$n"
echo Write-Host ''
echo Write-Host "  $bb ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$n"
echo Write-Host "  $bb [1]  B L U E   P I L L$n"
echo Write-Host "  $bb ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$n"
echo Write-Host "       $w Stay comfortable. Fastest path to your AI assistant.$n"
echo Write-Host "       $w · 1 agent, 11 skills · WorkIQ · No GitHub · ~2 min$n"
echo Write-Host ''
echo Write-Host "  $rb ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$n"
echo Write-Host "  $rb [2]  R E D   P I L L$n"
echo Write-Host "  $rb ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$n"
echo Write-Host "       $w See the truth. Two agents, full technical power.$n"
echo Write-Host "       $w · Everything in Blue, plus:$n"
echo Write-Host "       $r · AI Workbench (+11 skills) · GitHub backup · Restore anywhere$n"
echo Write-Host "       $w · ~5 min (requires GitHub account)$n"
echo Write-Host ''
echo $choice = Read-Host "  Enter 1 or 2"
echo Set-Content -Path "$env:TEMP\pill-choice.txt" -Value $choice -NoNewline
) > "%MENU%"

pwsh -NoProfile -ExecutionPolicy Bypass -File "%MENU%"
del "%MENU%" >nul 2>nul

set /p C=<"%TEMP%\pill-choice.txt"
del "%TEMP%\pill-choice.txt" >nul 2>nul

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
