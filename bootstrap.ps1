# Bootstrap: downloads installer and runs it properly with -File
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
$ProgressPreference = 'SilentlyContinue'  # suppress PS5.1 blue progress bar during download
$tmp = "$env:TEMP\ai-maker-install.ps1"
Write-Host "`n[AI Maker] Downloading installer..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/marcusash/ai-maker/main/scripts/install.ps1" -OutFile $tmp -UseBasicParsing
if (-not (Test-Path $tmp)) { Write-Host "Download failed. Check your internet connection." -ForegroundColor Red; return }
Write-Host "[AI Maker] Starting installer..." -ForegroundColor Cyan
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $shell -NoProfile -ExecutionPolicy Bypass -File $tmp
