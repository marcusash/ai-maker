#!/usr/bin/env pwsh
#
# E2E installer test. Downloads from the LIVE release and runs it.
# This is the only test that matters: does the installer work?
#
# Usage: pwsh tests/e2e-install.ps1
#

$ErrorActionPreference = "Stop"
$repo = "marcusash/ai-maker"

Write-Host "`n=== E2E INSTALLER TEST ===" -ForegroundColor Cyan
Write-Host "Downloads from live release, runs from TEMP.`n"

# Clean
Remove-Item "$env:TEMP\install-blue.ps1" -Force -EA SilentlyContinue
Remove-Item "$env:TEMP\ai-maker-lib.ps1" -Force -EA SilentlyContinue
Remove-Item "$env:TEMP\ai-maker-skills*" -Recurse -Force -EA SilentlyContinue
Remove-Item "$env:TEMP\ai-maker-agents*" -Recurse -Force -EA SilentlyContinue

# Download from live release
Write-Host "1. Downloading from release..." -ForegroundColor White
$base = "https://github.com/$repo/releases/latest/download"
Invoke-RestMethod -Uri "$base/ai-maker-lib.ps1" -OutFile "$env:TEMP\ai-maker-lib.ps1"
Invoke-RestMethod -Uri "$base/install-blue.ps1" -OutFile "$env:TEMP\install-blue.ps1"
Write-Host "   OK" -ForegroundColor Green

# Run
Write-Host "2. Running install-blue.ps1 from TEMP..." -ForegroundColor White
$output = pwsh -NoProfile -ExecutionPolicy Bypass -Command "& '$env:TEMP\install-blue.ps1'" 2>&1
$exit = $LASTEXITCODE

# Check
$text = $output -join "`n"
$errors = $output | Where-Object { $_ -match 'Exception|throw|Cannot find|FAILED' }

if ($exit -ne 0 -or $errors) {
    Write-Host "`n=== FAILED ===" -ForegroundColor Red
    Write-Host $text
    exit 1
}

if ($text -match "Installation complete") {
    Write-Host "   Installation complete!" -ForegroundColor Green
}
else {
    Write-Host "`n=== FAILED — no completion message ===" -ForegroundColor Red
    Write-Host $text
    exit 1
}

Write-Host "`n=== PASSED ===" -ForegroundColor Green
