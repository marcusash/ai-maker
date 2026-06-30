@echo off
where pwsh >nul 2>nul || (
    echo   Installing PowerShell 7...
    winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
    set "PATH=%PATH%;%ProgramFiles%\PowerShell\7"
)

pwsh -NoProfile -ExecutionPolicy Bypass -Command ^
 $e=[char]27;^
 $g="$e[92m";$b="$e[94m";$r="$e[91m";$d="$e[90m";$w="$e[97m";$n="$e[0m";^
 Write-Host '';^
 Write-Host '';^
 Write-Host "        $g   _    ___   __  __    _    _  __ ___  ___ $n";^
 Write-Host "        $g  / \  |_ _| |  \/  |  / \  | |/ /| __|| _ \$n";^
 Write-Host "        $g / _ \  | |  | |\/| | / _ \ | ' < | _| |   /$n";^
 Write-Host "        $g/_/ \_\|___| |_|  |_|/_/ \_\|_|\_\|___|_|_\$n";^
 Write-Host '';^
 Write-Host "        $g     C H O O S E   Y O U R   R E A L I T Y$n";^
 Write-Host '';^
 Write-Host "  $d The story you tell yourself about what you are capable of.$n";^
 Write-Host '';^
 Write-Host "  $d$('_' * 72)$n";^
 Write-Host '';^
 Write-Host "    $b[1]  B L U E   P I L L$n";^
 Write-Host '';^
 Write-Host "         ${w}Stay comfortable. Fastest path to your AI assistant.$n";^
 Write-Host '';^
 Write-Host "         $d- 1 agent (AI Maker), 11 skills$n";^
 Write-Host "         $d- WorkIQ: reads your M365 email, calendar, Teams$n";^
 Write-Host "         $d- No GitHub account needed$n";^
 Write-Host "         $d- ~2 minutes to install$n";^
 Write-Host '';^
 Write-Host "  $d$('_' * 72)$n";^
 Write-Host '';^
 Write-Host "    $r[2]  R E D   P I L L$n";^
 Write-Host '';^
 Write-Host "         ${w}See the truth. Two agents, full technical power.$n";^
 Write-Host '';^
 Write-Host "         $d- Everything in Blue, plus:$n";^
 Write-Host "         $r- AI Workbench (11 more skills: code, security, CI/CD)$n";^
 Write-Host "         $r- Private GitHub repo backs up your workspace$n";^
 Write-Host "         $r- Restore on any machine in minutes$n";^
 Write-Host "         $d- ~5 minutes to install (requires GitHub account)$n";^
 Write-Host '';^
 Write-Host "  $d$('_' * 72)$n";^
 Write-Host '';^
 Write-Host "    $d[3]  M I G R A T I O N$n";^
 Write-Host '';^
 Write-Host "         ${d}Coming soon. Move skills and settings from CLI-based AI Maker.$n";^
 Write-Host "         ${d}This install runs side by side with previous versions.$n";^
 Write-Host "         ${d}Nothing changes with your existing GitHub CLI setup.$n";^
 Write-Host '';^
 Write-Host "  $d$('_' * 72)$n";^
 Write-Host ''

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
