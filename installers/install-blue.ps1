#Requires -Version 5.1
<#
.SYNOPSIS
    AI Maker v3 — Blue Pill Installer
.DESCRIPTION
    Installs the GitHub Copilot App + 11 AI Maker skills. No git required.
    Downloads skills from GitHub release, copies to ~/.copilot/skills/.
#>
[CmdletBinding()]
param(
    [switch]$Doctor
)

$ErrorActionPreference = "Stop"

# ═══════════════════════════════════════════════════════════════
# LOAD LIBRARY
# ═══════════════════════════════════════════════════════════════

. (Join-Path $PSScriptRoot "ai-maker-lib.ps1")

# ═══════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Blue
Write-Host "  |       AI Maker v3 - Blue Pill            |" -ForegroundColor Blue
Write-Host "  |   Your AI assistant in 5 minutes         |" -ForegroundColor Blue
Write-Host "  +------------------------------------------+" -ForegroundColor Blue
Write-Host ""

if ($Doctor) { Invoke-HealthCheck; return }

# ═══════════════════════════════════════════════════════════════
# STEP 1: PREREQUISITES
# ═══════════════════════════════════════════════════════════════

Write-Host "Step 1: Checking prerequisites..." -ForegroundColor White

$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 10) { throw "Windows 10 or later required." }
Write-Host "  ✓ Windows $($osVersion.Major).$($osVersion.Build)" -ForegroundColor Green

if (-not (Get-Command winget -EA Silent)) { throw "winget not found. Install from https://aka.ms/getwinget" }
Write-Host "  ✓ winget available" -ForegroundColor Green

$diskCheck = Get-DiskSpaceCheck
if (-not $diskCheck.ok) { throw $diskCheck.message }
Write-Host "  ✓ Disk space OK" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# STEP 2: INSTALL COPILOT APP
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 2: Installing GitHub Copilot App..." -ForegroundColor White

$appInstalled = (winget list --id GitHub.CopilotApp --accept-source-agreements 2>$null) -match "GitHub.CopilotApp"
if ($appInstalled) {
    Write-Host "  ✓ Already installed" -ForegroundColor Green
}
else {
    winget install GitHub.CopilotApp --accept-source-agreements --accept-package-agreements --silent
    if ($LASTEXITCODE -ne 0) { throw "winget install failed for GitHub.CopilotApp (exit: $LASTEXITCODE)" }
    Write-Host "  ✓ Copilot App installed" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# STEP 3: DOWNLOAD + INSTALL SKILLS
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 3: Installing AI Maker skills (11)..." -ForegroundColor White

$zipPath     = Join-Path $env:TEMP "ai-maker-skills.zip"
$extractPath = Join-Path $env:TEMP "ai-maker-skills"

Write-Host "  Downloading skills..." -ForegroundColor Gray
Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/skills.zip" -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

$existingManifest = Read-AIMakerManifest
$installedSkills  = Install-Skills -Pill "blue" -SourcePath (Join-Path $extractPath "skills") -Manifest $existingManifest
Write-Host "  ✓ $($installedSkills.Count) skills installed" -ForegroundColor Green

Remove-Item $zipPath -EA SilentlyContinue
Remove-Item $extractPath -Recurse -EA SilentlyContinue

# ═══════════════════════════════════════════════════════════════
# STEP 4: CREATE WORKSPACE
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 4: Creating workspace..." -ForegroundColor White

$wsManifest = Join-Path $script:AIMakerConfig.WorkspacePath $script:AIMakerConfig.ManifestFile
if (Test-Path $wsManifest) {
    Write-Host "  ✓ Workspace already exists" -ForegroundColor Green
}
else {
    New-WorkspaceScaffold -Pill "blue"
    Write-Host "  ✓ Workspace created at $($script:AIMakerConfig.WorkspacePath)" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# STEP 5: WRITE MANIFEST
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 5: Writing manifest..." -ForegroundColor White

$manifest = New-AIMakerManifest -Pill "blue" -Skills $installedSkills
Write-AIMakerManifest -Manifest $manifest
Write-Host "  ✓ Manifest written" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |       Installation complete!             |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  Open the Copilot App and add this folder as a project:" -ForegroundColor White
Write-Host "  $($script:AIMakerConfig.WorkspacePath)" -ForegroundColor Cyan
Write-Host ""

# Launch the Copilot App
$appExe = Join-Path $env:LOCALAPPDATA "Programs\GitHub Copilot\GitHub Copilot.exe"
if (Test-Path $appExe) { Start-Process $appExe }
Write-Host ""

