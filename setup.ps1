# AI Maker Setup Launcher
# Supports two modes:
#   1. irm https://raw.githubusercontent.com/marcusash/ai-maker/main/setup.ps1 | iex
#   2. Double-click setup.bat (local clone)

$scriptPath = $MyInvocation.MyCommand.Path

if (-not $scriptPath) {
    # Running via irm | iex: download repo and run installer
    $dest = "C:\AIMaker"
    Write-Host "`n[AI Maker] Downloading setup files..." -ForegroundColor Cyan

    if (Get-Command git -ErrorAction SilentlyContinue) {
        git clone https://github.com/marcusash/ai-maker.git $dest 2>$null
        if (-not (Test-Path "$dest\scripts\install.ps1")) {
            Write-Host "[AI Maker] Clone failed. Check your internet connection." -ForegroundColor Red
            return
        }
    } else {
        # No git: download zip
        $zip = "$env:TEMP\ai-maker.zip"
        Invoke-WebRequest -Uri "https://github.com/marcusash/ai-maker/archive/refs/heads/main.zip" -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $env:TEMP -Force
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Move-Item "$env:TEMP\ai-maker-main" $dest
        Remove-Item $zip -Force
    }

    $script = Join-Path $dest "scripts\install.ps1"
    Write-Host "[AI Maker] Starting installer..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -Verb RunAs -Wait
} else {
    # Running from local file (setup.bat)
    $dir    = Split-Path -Parent $scriptPath
    $script = Join-Path $dir "scripts\install.ps1"
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -Verb RunAs -Wait
}
