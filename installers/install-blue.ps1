#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 — Blue Pill Installer
.DESCRIPTION
    Implements PRD §6.1 exactly: Agency Foundation → AI Maker Layer → Launch
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ai-maker-lib.ps1")

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Blue
Write-Host "  |       AI Maker v3 - Blue Pill            |" -ForegroundColor Blue
Write-Host "  |   Your AI assistant in 5 minutes         |" -ForegroundColor Blue
Write-Host "  +------------------------------------------+" -ForegroundColor Blue
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# PHASE 1: AGENCY FOUNDATION (PRD §6.1 steps 1-9)
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

# Step 3: Install Git
Write-Host "`nStep 2: Installing Git..." -ForegroundColor White
if (Get-Command git -EA Silent) {
    Write-Host "  ✓ Git already installed" -ForegroundColor Green
}
else {
    winget install Git.Git --accept-source-agreements --accept-package-agreements --silent
    if ($LASTEXITCODE -ne 0) { throw "Failed to install Git" }
    $env:PATH += ";${env:ProgramFiles}\Git\cmd"
    Write-Host "  ✓ Git installed" -ForegroundColor Green
}

# Step 4: Set SHELL env var
$gitSh = Join-Path $env:ProgramFiles "Git\usr\bin\sh.exe"
if (Test-Path $gitSh) {
    [Environment]::SetEnvironmentVariable("SHELL", $gitSh, "User")
    $env:SHELL = $gitSh
}

# Step 5: Install Agency CLI (PRD §8.2 — save script, invoke with -ToolName)
Write-Host "`nStep 3: Installing Agency..." -ForegroundColor White
$installScript = Join-Path $env:TEMP "InstallTool.ps1"
Invoke-RestMethod -Uri "https://aka.ms/InstallTool.ps1" -OutFile $installScript
& $installScript -ToolName "agency"
Remove-Item $installScript -EA SilentlyContinue

# Step 6: Probe for agency.exe (PATH → Velopack glob → error)
$agency = (Get-Command agency -EA SilentlyContinue | Select-Object -Expand Source)
if (-not $agency) {
    $agency = Get-ChildItem "$env:APPDATA\agency\*\agency.exe" -EA SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1 -Expand FullName
}
if (-not $agency) { throw "agency.exe not found after install" }
Write-Host "  ✓ Agency: $agency" -ForegroundColor Green

# Step 7: Register MCP servers (direct JSON write per PRD §8.2)
Write-Host "`nStep 4: Registering MCP servers..." -ForegroundColor White
Register-AgencyMcpServers -AgencyExePath $agency

# Step 8: Verify MCP registration (THROW if missing)
$mcpFile = $script:AIMakerConfig.McpServersPath
$mcpJson = Get-Content $mcpFile -Raw | ConvertFrom-Json
if (-not $mcpJson.workiq) { throw "MCP registration failed: workiq missing from $mcpFile" }
if (-not $mcpJson.bluebird) { throw "MCP registration failed: bluebird missing from $mcpFile" }
Write-Host "  ✓ workiq + bluebird registered and verified" -ForegroundColor Green

# Step 9: Enable M365 MCPs (mail + calendar replace "outlook" per agency CLI)
foreach ($mcp in @('teams', 'mail', 'calendar', 'planner')) {
    & $agency config set --global --mcp $mcp
}
Write-Host "  ✓ M365 MCPs enabled (teams, mail, calendar, planner)" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# PHASE 2: AI MAKER LAYER (PRD §6.1 steps 10-14)
# ═══════════════════════════════════════════════════════════════

# Step 10: Download + install skills
Write-Host "`nStep 5: Installing AI Maker skills (11)..." -ForegroundColor White
$zipPath = Join-Path $env:TEMP "ai-maker-skills.zip"
$extractPath = Join-Path $env:TEMP "ai-maker-skills"
Remove-Item $extractPath -Recurse -Force -EA SilentlyContinue
Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/skills.zip" -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
$installedSkills = Install-Skills -Pill "blue" -SourcePath (Join-Path $extractPath "skills") -Manifest (Read-AIMakerManifest)
Write-Host "  ✓ $($installedSkills.Count) skills installed" -ForegroundColor Green
Remove-Item $zipPath -EA SilentlyContinue
Remove-Item $extractPath -Recurse -EA SilentlyContinue

# Steps 11-13: Create workspace + copilot-instructions + agents
Write-Host "`nStep 6: Creating workspace..." -ForegroundColor White
$wsManifest = Join-Path $script:AIMakerConfig.WorkspacePath $script:AIMakerConfig.ManifestFile
if (Test-Path $wsManifest) {
    Write-Host "  ✓ Workspace already exists" -ForegroundColor Green
}
else {
    $agentsZip = Join-Path $env:TEMP "ai-maker-agents.zip"
    $agentsDir = Join-Path $PSScriptRoot "agents"
    Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/agents.zip" -OutFile $agentsZip
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
    Expand-Archive -Path $agentsZip -DestinationPath $agentsDir -Force
    Remove-Item $agentsZip -EA SilentlyContinue
    New-WorkspaceScaffold -Pill "blue"
    Write-Host "  ✓ Workspace created at $($script:AIMakerConfig.WorkspacePath)" -ForegroundColor Green
}

# Step 14: Write manifest
Write-Host "`nStep 7: Writing manifest..." -ForegroundColor White
$manifest = New-AIMakerManifest -Pill "blue" -Skills $installedSkills
Write-AIMakerManifest -Manifest $manifest
Write-Host "  ✓ Manifest written" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# PHASE 3: LAUNCH (PRD §6.1 steps 15-16)
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |       ✓ Installation complete!           |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  Opening the Copilot App..." -ForegroundColor White

# Step 15: Launch via Agency
& $agency gh-app

Write-Host ""
Write-Host "  Add this folder as a project in the App:" -ForegroundColor White
Write-Host "  $($script:AIMakerConfig.WorkspacePath)" -ForegroundColor Cyan
Write-Host ""
