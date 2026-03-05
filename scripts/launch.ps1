# AI Maker Launcher
# This is what the desktop shortcut runs.
# Opens a terminal in C:\AIMaker and launches GitHub Copilot CLI.

$WORKSPACE = "C:\AIMaker"
$LOG_FILE  = "$WORKSPACE\logs\session-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure workspace exists
if (-not (Test-Path $WORKSPACE)) {
    Write-Host "AI Maker workspace not found at $WORKSPACE." -ForegroundColor Red
    Write-Host "Please re-run the installer: setup.bat" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Set-Location $WORKSPACE

# Set terminal title
$host.UI.RawUI.WindowTitle = "AI Maker"

# Check Copilot CLI is available
$copilotOk = Get-Command "gh" -ErrorAction SilentlyContinue
if (-not $copilotOk) {
    Write-Host "GitHub CLI not found. Please re-run the installer." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Welcome banner
Clear-Host
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor White
Write-Host "   AI Maker" -ForegroundColor Cyan
Write-Host "   Your AI partner. Powered by GitHub Copilot + WorkIQ." -ForegroundColor Gray
Write-Host "  ==========================================" -ForegroundColor White
Write-Host ""
Write-Host "  Workspace: $WORKSPACE" -ForegroundColor DarkGray
Write-Host "  Profile:   $WORKSPACE\profile.md" -ForegroundColor DarkGray
if (Test-Path "$WORKSPACE\profile.md") {
    Write-Host "  Status:    Profile found. AI Maker will greet you by name." -ForegroundColor Green
} else {
    Write-Host "  Status:    No profile yet. AI Maker will interview you first." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Type your question or request. Press Ctrl+C to exit." -ForegroundColor DarkGray
Write-Host ""

# Open the getting-started guide in the browser.
# Try the installed workspace copy first; fall back to the copy bundled with this script.
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$gettingStarted = "$WORKSPACE\canvas\getting-started.html"
if (-not (Test-Path $gettingStarted)) {
    $gettingStarted = "$SCRIPT_DIR\..\docs\getting-started.html"
}
if (Test-Path $gettingStarted) {
    Start-Process $gettingStarted
} else {
    Write-Host "  (User guide not found - re-run the installer to restore it)" -ForegroundColor DarkGray
}

# Drop into Copilot interactive mode.
# On first run this downloads the Copilot CLI binary -- that's expected and takes ~30 seconds.
Write-Host "  Starting AI Maker..." -ForegroundColor DarkGray
Write-Host ""
try {
    gh copilot
} catch {
    Write-Host ""
    Write-Host "  AI Maker exited with an error: $_" -ForegroundColor Red
}
Write-Host ""
Read-Host "  Session ended. Press Enter to close"
