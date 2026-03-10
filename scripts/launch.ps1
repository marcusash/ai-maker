# AI Maker Launcher - runs from the desktop shortcut

$WORKSPACE  = "C:\AIMaker"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition

if (-not (Test-Path $WORKSPACE)) {
    Write-Host "AI Maker workspace not found at $WORKSPACE." -ForegroundColor Red
    Write-Host "Please re-run the installer." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Host "GitHub CLI not found. Please re-run the installer." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Set-Location $WORKSPACE
$host.UI.RawUI.WindowTitle = "AI Maker"
Clear-Host

$profileStatus = if (Test-Path "$WORKSPACE\profile.md") {
    "Profile found. AI Maker will greet you by name."
} else {
    "No profile yet. AI Maker will interview you first."
}

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor White
Write-Host "   AI Maker" -ForegroundColor Cyan
Write-Host "   Your AI partner. Powered by GitHub Copilot + WorkIQ." -ForegroundColor Gray
Write-Host "  ==========================================" -ForegroundColor White
Write-Host ""
Write-Host "  Workspace : $WORKSPACE" -ForegroundColor DarkGray
Write-Host "  Status    : $profileStatus" -ForegroundColor $(if (Test-Path "$WORKSPACE\profile.md") { "Green" } else { "Yellow" })
Write-Host ""
Write-Host "  Type your question or request. Press Ctrl+C to exit." -ForegroundColor DarkGray
Write-Host ""

# Open getting-started guide
$guide = @("$WORKSPACE\canvas\getting-started.html", "$SCRIPT_DIR\..\docs\getting-started.html") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($guide) { Start-Process $guide }

# Launch Copilot - loop using suggest/explain since bare 'gh copilot' requires old extension
Write-Host "  Commands: 'suggest <task>', 'explain <command>', or just describe what you need." -ForegroundColor DarkGray
Write-Host "  Type 'exit' to quit." -ForegroundColor DarkGray
Write-Host ""

while ($true) {
    $userInput = Read-Host "  You"
    if (-not $userInput) { continue }
    if ($userInput -eq "exit" -or $userInput -eq "quit") { break }

    Write-Host ""
    if ($userInput -match "^explain\s+(.+)") {
        gh copilot explain $Matches[1]
    } else {
        $query = $userInput -replace "^suggest\s+", ""
        gh copilot suggest $query
    }
    Write-Host ""
}

Write-Host ""
Read-Host "  Session ended. Press Enter to close"