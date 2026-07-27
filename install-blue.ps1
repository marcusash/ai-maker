#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 — Blue Pill Installer
.DESCRIPTION
    Installs AI Maker skills, workspace, WorkIQ plugin, and launches the Copilot App.
    Fastest setup — no GitHub account required.
.NOTES
    SIDE-BY-SIDE INSTALL: This installer creates a fresh environment at C:\GitHub\ai-workspace.
    It does NOT touch, modify, or merge anything from previous CLI-based installs (C:\AIMaker,
    C:\AIWorkbench). Your existing CLI setup continues to work as-is. A migration tool to move
    old vault/state into this new environment is planned for a future release.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Load shared library — download from release if running via irm | iex ($PSScriptRoot is empty)
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "ai-maker-lib.ps1"))) {
    . (Join-Path $PSScriptRoot "ai-maker-lib.ps1")
} else {
    $libTemp = Join-Path $env:TEMP "ai-maker-lib.ps1"
    Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/ai-maker-lib.ps1" -OutFile $libTemp
    . $libTemp
}

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Blue
Write-Host "  |       AI Maker v3 - Blue Pill            |" -ForegroundColor Blue
Write-Host "  |   Your AI assistant in 5 minutes         |" -ForegroundColor Blue
Write-Host "  +------------------------------------------+" -ForegroundColor Blue
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# PHASE 1: FOUNDATION
# ═══════════════════════════════════════════════════════════════

# Step 1: Prerequisites
Write-Host "Step 1: Checking prerequisites..." -ForegroundColor White
$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 10) { throw "Windows 10 or later required." }
Write-Host "  ✓ Windows $($osVersion.Major).$($osVersion.Build)" -ForegroundColor Green
if (-not (Get-Command winget -EA Silent)) { throw "winget not found. Install from https://aka.ms/getwinget" }
Write-Host "  ✓ winget available" -ForegroundColor Green
$diskCheck = Get-DiskSpaceCheck
if (-not $diskCheck.ok) { throw $diskCheck.message }
Write-Host "  ✓ Disk space OK" -ForegroundColor Green

# Step 2: Install Git
Write-Host "`nStep 2: Installing Git..." -ForegroundColor White
if (Get-Command git -EA Silent) {
    Write-Host "  ✓ Git already installed" -ForegroundColor Green
}
else {
    winget install Git.Git --source winget --accept-source-agreements --accept-package-agreements --silent
    if ($LASTEXITCODE -ne 0) { throw "Failed to install Git" }
    $env:PATH += ";${env:ProgramFiles}\Git\cmd"
    Write-Host "  ✓ Git installed" -ForegroundColor Green
}

# Set SHELL env var
$gitSh = Join-Path $env:ProgramFiles "Git\usr\bin\sh.exe"
if (Test-Path $gitSh) {
    [Environment]::SetEnvironmentVariable("SHELL", $gitSh, "User")
    $env:SHELL = $gitSh
}

# Step 3: GitHub Copilot App
Write-Host "`nStep 3: Installing GitHub Copilot App..." -ForegroundColor White
$copilotExe = Join-Path $env:LOCALAPPDATA "Programs\GitHub Copilot\github.exe"
if (Test-Path $copilotExe) {
    Write-Host "  ✓ GitHub Copilot App already installed" -ForegroundColor Green
} else {
    winget install GitHub.CopilotApp --source winget --accept-source-agreements --accept-package-agreements --silent
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ GitHub Copilot App installed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Could not auto-install. Get it from: https://aka.ms/githubcopilotapp" -ForegroundColor Yellow
    }
}

# Step 4: WorkIQ plugin
Write-Host "`nStep 4: Installing WorkIQ plugin..." -ForegroundColor White
$pluginZip = Join-Path $env:TEMP "ai-maker-workiq-plugin.zip"
$pluginDir = Join-Path $env:TEMP "ai-maker-workiq-plugin"
Remove-Item $pluginDir -Recurse -Force -EA SilentlyContinue
Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/workiq-plugin.zip" -OutFile $pluginZip
Expand-Archive -Path $pluginZip -DestinationPath $pluginDir -Force
Install-WorkiqPlugin -SourcePath $pluginDir
$wiqDir = Join-Path $env:USERPROFILE ".copilot\installed-plugins\copilot-plugins\workiq"
if (-not (Test-Path (Join-Path $wiqDir ".mcp.json"))) { throw "WorkIQ plugin install failed: .mcp.json missing" }
Write-Host "  ✓ WorkIQ plugin installed and enabled" -ForegroundColor Green
Remove-Item $pluginZip -EA SilentlyContinue
Remove-Item $pluginDir -Recurse -EA SilentlyContinue

# ═══════════════════════════════════════════════════════════════
# PHASE 2: AI MAKER LAYER (skills + workspace)
# ═══════════════════════════════════════════════════════════════

# Step 5: Install skills
Write-Host "`nStep 5: Installing AI Maker skills (11)..." -ForegroundColor White
$zipPath = Join-Path $env:TEMP "ai-maker-skills.zip"
$extractPath = Join-Path $env:TEMP "ai-maker-skills"
Remove-Item $extractPath -Recurse -Force -EA SilentlyContinue
Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/skills.zip" -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
$installedSkills = Install-Skills -Pill "blue" -SourcePath $extractPath -Manifest (Read-AIMakerManifest)
Write-Host "  ✓ $($installedSkills.Count) skills installed" -ForegroundColor Green
Remove-Item $zipPath -EA SilentlyContinue
Remove-Item $extractPath -Recurse -EA SilentlyContinue

# Step 6: Create workspace
Write-Host "`nStep 6: Creating workspace..." -ForegroundColor White
$wsPath = $script:AIMakerConfig.WorkspacePath
$wsManifest = Join-Path $wsPath $script:AIMakerConfig.ManifestFile
if (Test-Path $wsManifest) {
    Write-Host "  ✓ Workspace already exists" -ForegroundColor Green
}
else {
    $agentsZip = Join-Path $env:TEMP "ai-maker-agents.zip"
    $agentsDir = Join-Path $env:TEMP "ai-maker-agents"
    Remove-Item $agentsDir -Recurse -Force -EA SilentlyContinue
    Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/agents.zip" -OutFile $agentsZip
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
    Expand-Archive -Path $agentsZip -DestinationPath $agentsDir -Force
    Remove-Item $agentsZip -EA SilentlyContinue
    New-WorkspaceScaffold -Pill "blue" -AgentSourcePath $agentsDir
    Remove-Item $agentsDir -Recurse -EA SilentlyContinue
    Write-Host "  ✓ Workspace created at $wsPath" -ForegroundColor Green
}

# Step 7: Write manifest
Write-Host "`nStep 7: Writing manifest..." -ForegroundColor White
$manifest = New-AIMakerManifest -Pill "blue" -Skills $installedSkills
Write-AIMakerManifest -Manifest $manifest
Write-Host "  ✓ Manifest written" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# PHASE 3: LAUNCH
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |       ✓ Installation complete!           |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  What you got:" -ForegroundColor White
Write-Host "    • 11 skills (AI Maker)" -ForegroundColor Gray
Write-Host "    • WorkIQ plugin (M365 data via natural language)" -ForegroundColor Gray
Write-Host "    • Workspace: $wsPath" -ForegroundColor Gray
Write-Host ""

# Launch Copilot App with workspace path
Write-Host "  Opening the Copilot App..." -ForegroundColor White
$copilotExe = Join-Path $env:LOCALAPPDATA "Programs\GitHub Copilot\github.exe"
if (Test-Path $copilotExe) {
    Start-Process $copilotExe -ArgumentList $wsPath
} else {
    Write-Host "  ⚠ Could not find the app. Launch 'GitHub Copilot' from the Start menu." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  To connect WorkIQ (M365 emails, meetings, Teams):" -ForegroundColor White
Write-Host "    Settings > MCP servers > Plugins tab > click Sign in next to workiq" -ForegroundColor Cyan
Write-Host "    Sign in with your Microsoft account when prompted." -ForegroundColor Cyan
Write-Host ""
