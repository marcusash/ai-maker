@echo off
where pwsh >nul 2>nul || (
    echo   Installing PowerShell 7...
    winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent
    set "PATH=%PATH%;%ProgramFiles%\PowerShell\7"
)

pwsh -NoProfile -ExecutionPolicy Bypass -Command ^
 $e=[char]27;^
 $g="$e[92m";$gb="$e[92;1m";$b="$e[94m";$bb="$e[94;1m";$r="$e[91m";$rb="$e[91;1m";$d="$e[90m";$w="$e[97m";$n="$e[0m";^
 Write-Host '';^
 Write-Host "  $gb  ╔══════════════════════════════════════════════════════════════════╗$n";^
 Write-Host "  $gb  ║$n                                                                  $gb║$n";^
 Write-Host "  $gb  ║$n    $g   _    ___   __  __    _    _  __ ___  ___  $n               $gb║$n";^
 Write-Host "  $gb  ║$n    $g  / \  |_ _| |  \/  |  / \  | |/ /| __|| _ \ $n              $gb║$n";^
 Write-Host "  $gb  ║$n    $g / _ \  | |  | |\/| | / _ \ | ' < | _| |   / $n             $gb║$n";^
 Write-Host "  $gb  ║$n    $g/_/ \_\|___| |_|  |_|/_/ \_\|_|\_\|___|_|_\ $n              $gb║$n";^
 Write-Host "  $gb  ║$n                                                                  $gb║$n";^
 Write-Host "  $gb  ║$n           $g C H O O S E   Y O U R   R E A L I T Y$n               $gb║$n";^
 Write-Host "  $gb  ║$n                                                                  $gb║$n";^
 Write-Host "  $gb  ║$n   $d The story you tell yourself about what you are capable of.$n    $gb║$n";^
 Write-Host "  $gb  ║$n                                                                  $gb║$n";^
 Write-Host "  $gb  ╚══════════════════════════════════════════════════════════════════╝$n";^
 Write-Host '';^
 Write-Host "  $bb  ┌─────────────────────────────────────────────────────────────────┐$n";^
 Write-Host "  $bb  │$n  $bb[1]  B L U E   P I L L$n                                          $bb│$n";^
 Write-Host "  $bb  │$n                                                                 $bb│$n";^
 Write-Host "  $bb  │$n       ${w}Stay comfortable. Fastest path to your AI assistant.$n      $bb│$n";^
 Write-Host "  $bb  │$n                                                                 $bb│$n";^
 Write-Host "  $bb  │$n       $d· 1 agent (AI Maker), 11 skills$n                           $bb│$n";^
 Write-Host "  $bb  │$n       $d· WorkIQ: reads your M365 email, calendar, Teams$n          $bb│$n";^
 Write-Host "  $bb  │$n       $d· No GitHub account needed$n                                $bb│$n";^
 Write-Host "  $bb  │$n       $d· ~2 minutes to install$n                                   $bb│$n";^
 Write-Host "  $bb  │$n                                                                 $bb│$n";^
 Write-Host "  $bb  └─────────────────────────────────────────────────────────────────┘$n";^
 Write-Host '';^
 Write-Host "  $rb  ┌─────────────────────────────────────────────────────────────────┐$n";^
 Write-Host "  $rb  │$n  $rb[2]  R E D   P I L L$n                                            $rb│$n";^
 Write-Host "  $rb  │$n                                                                 $rb│$n";^
 Write-Host "  $rb  │$n       ${w}See the truth. Two agents, full technical power.$n          $rb│$n";^
 Write-Host "  $rb  │$n                                                                 $rb│$n";^
 Write-Host "  $rb  │$n       $d· Everything in Blue, plus:$n                               $rb│$n";^
 Write-Host "  $rb  │$n       $r· AI Workbench (11 more skills: code, security, CI/CD)$n    $rb│$n";^
 Write-Host "  $rb  │$n       $r· Private GitHub repo backs up your workspace$n             $rb│$n";^
 Write-Host "  $rb  │$n       $r· Restore on any machine in minutes$n                       $rb│$n";^
 Write-Host "  $rb  │$n       $d· ~5 minutes to install (requires GitHub account)$n         $rb│$n";^
 Write-Host "  $rb  │$n                                                                 $rb│$n";^
 Write-Host "  $rb  └─────────────────────────────────────────────────────────────────┘$n";^
 Write-Host '';^
 Write-Host "  $d  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐$n";^
 Write-Host "  $d    [3]  MIGRATION                                      coming soon$n";^
 Write-Host "  $d         Installs side by side. Your existing CLI setup is untouched.$n";^
 Write-Host "  $d  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘$n";^
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
