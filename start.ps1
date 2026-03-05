<#
.SYNOPSIS
    Launch AI Maker and AI Workbench in Windows Terminal.
.DESCRIPTION
    Opens Windows Terminal with two tabs:
      Tab 1: AI Maker (yellow)    — C:\AIMaker
      Tab 2: AI Workbench (red)   — C:\AIWorkbench
    Both tabs start the agency copilot agent automatically.
#>

# Prerequisite check
if (-not (Get-Command wt -ErrorAction SilentlyContinue)) {
    Write-Host "  Error: Windows Terminal (wt) not found on PATH." -ForegroundColor Red
    Write-Host "  Install Windows Terminal from the Microsoft Store, then re-run." -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command agency -ErrorAction SilentlyContinue)) {
    Write-Host "  Error: agency CLI not found on PATH." -ForegroundColor Red
    Write-Host "  Run install.ps1 to install Agency, then re-run." -ForegroundColor Yellow
    exit 1
}

Write-Host "  Launching AI Maker and AI Workbench..." -ForegroundColor Cyan

# Build wt command: two tabs with locked tab colors
# Tab 1: AI Maker (yellow #FFCB05)
# Tab 2: AI Workbench (red #CE1126)
$aiMakerCmd    = "pwsh -NoProfile -WorkingDirectory C:\AIMaker -Command `"agency copilot`""
$aiWorkbenchCmd = "pwsh -NoProfile -WorkingDirectory C:\AIWorkbench -Command `"agency copilot`""

$wtArgs = "new-tab --title `"AI Maker`" --tabColor `"#FFCB05`" --startingDirectory `"C:\AIMaker`" -- $aiMakerCmd ; new-tab --title `"AI Workbench`" --tabColor `"#CE1126`" --startingDirectory `"C:\AIWorkbench`" -- $aiWorkbenchCmd"

Start-Process "wt.exe" -ArgumentList $wtArgs

Write-Host "  Done. Both agent tabs are starting." -ForegroundColor Green
