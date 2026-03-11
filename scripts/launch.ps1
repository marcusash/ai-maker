# AI Maker Launcher - runs from the desktop shortcut

$WORKSPACE  = "C:\AIMaker"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Refresh PATH so WinGet-installed binaries (copilot, pwsh) are visible
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

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
Write-Host "  Press Ctrl+C to exit." -ForegroundColor DarkGray
Write-Host ""

# Open getting-started guide
$guide = @("$WORKSPACE\canvas\getting-started.html", "$SCRIPT_DIR\..\docs\getting-started.html") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($guide) { Start-Process $guide }

# Auto-accept Copilot CLI binary setup if needed (one-time)
if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-Host "  Setting up Copilot CLI (one-time)..." -ForegroundColor DarkGray
    "Y" | gh copilot suggest "test" 2>&1 | Out-Null
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Launch Copilot interactive session
Write-Host "  Starting AI Maker..." -ForegroundColor DarkGray
Write-Host ""
try {
    copilot
} catch {
    Write-Host "`n  AI Maker exited: $_" -ForegroundColor Red
}
Write-Host ""
Read-Host "  Session ended. Press Enter to close"
