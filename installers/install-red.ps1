#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 — Red Pill Installer
.DESCRIPTION
    Implements PRD §6.2 exactly: Agency + Dev Tools → AI Maker Layer → Launch
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ai-maker-lib.ps1")

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Red
Write-Host "  |       AI Maker v3 - Red Pill             |" -ForegroundColor Red
Write-Host "  |   Full experience with GitHub backup     |" -ForegroundColor Red
Write-Host "  +------------------------------------------+" -ForegroundColor Red
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# PHASE 1: AGENCY + DEVELOPER TOOLS (PRD §6.2 steps 1-9)
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

# Step 5: Install Agency CLI
Write-Host "`nStep 3: Installing Agency..." -ForegroundColor White
Invoke-RestMethod -Uri "https://aka.ms/InstallTool.ps1" | Invoke-Expression

# Step 6: Probe for agency.exe
$agencyPaths = @(
    (Get-Command agency -EA SilentlyContinue | Select-Object -Expand Source),
    (Join-Path $env:LOCALAPPDATA "Programs\Agency\agency.exe"),
    (Join-Path $env:ProgramFiles "Agency\agency.exe")
) + @(Get-ChildItem "$env:LOCALAPPDATA\Agency\app-*\agency.exe" -EA SilentlyContinue | Select-Object -Expand FullName)
$agency = $agencyPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $agency) { throw "Agency installed but agency.exe not found in PATH or known locations" }
Write-Host "  ✓ Agency found at $agency" -ForegroundColor Green

# Step 7: Register MCP servers
Write-Host "`nStep 4: Registering MCP servers..." -ForegroundColor White
& $agency mcp add workiq
& $agency mcp add bluebird
Write-Host "  ✓ workiq + bluebird registered" -ForegroundColor Green

# Step 8: Verify MCP registration
$mcpConfig = Join-Path $env:APPDATA "GitHub Copilot\m-mcp-servers.json"
if (Test-Path $mcpConfig) {
    $mcpJson = Get-Content $mcpConfig -Raw | ConvertFrom-Json
    $hasWorkiq = $mcpJson.PSObject.Properties.Name -contains "workiq"
    $hasBluebird = $mcpJson.PSObject.Properties.Name -contains "bluebird"
    if (-not $hasWorkiq -or -not $hasBluebird) { throw "MCP registration failed — workiq or bluebird missing from $mcpConfig" }
    Write-Host "  ✓ MCP config verified" -ForegroundColor Green
}

# Step 9: Enable M365 MCPs
& $agency config set --global --mcp teams/outlook/planner
Write-Host "  ✓ M365 MCPs enabled (teams/outlook/planner)" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# PHASE 2: AI MAKER LAYER (PRD §6.2 steps 10-17)
# ═══════════════════════════════════════════════════════════════

# Step 10: Download + install 22 skills
Write-Host "`nStep 5: Installing all skills (22)..." -ForegroundColor White
$zipPath = Join-Path $env:TEMP "ai-maker-skills.zip"
$extractPath = Join-Path $env:TEMP "ai-maker-skills"
Remove-Item $extractPath -Recurse -Force -EA SilentlyContinue
Write-Host "  Downloading skills..." -ForegroundColor Gray
Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/skills.zip" -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
$installedSkills = Install-Skills -Pill "red" -SourcePath (Join-Path $extractPath "skills") -Manifest (Read-AIMakerManifest)
$makerCount = ($installedSkills | Where-Object { $_.id -like "ai-maker-*" }).Count
$workbenchCount = ($installedSkills | Where-Object { $_.id -like "ai-workbench-*" }).Count
Write-Host "  ✓ $makerCount AI Maker + $workbenchCount AI Workbench skills ($($installedSkills.Count) total)" -ForegroundColor Green
Remove-Item $zipPath -EA SilentlyContinue
Remove-Item $extractPath -Recurse -EA SilentlyContinue

# Steps 11-13: Create workspace + write agents
Write-Host "`nStep 6: Creating workspace..." -ForegroundColor White
$wsPath = $script:AIMakerConfig.WorkspacePath
$wsManifest = Join-Path $wsPath $script:AIMakerConfig.ManifestFile
if (Test-Path $wsManifest) {
    Write-Host "  ✓ Workspace already exists" -ForegroundColor Green
}
else {
    Write-Host "  Downloading agent identities..." -ForegroundColor Gray
    $agentsZip = Join-Path $env:TEMP "ai-maker-agents.zip"
    $agentsDir = Join-Path $PSScriptRoot "agents"
    Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/agents.zip" -OutFile $agentsZip
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
    Expand-Archive -Path $agentsZip -DestinationPath $agentsDir -Force
    Remove-Item $agentsZip -EA SilentlyContinue
    New-WorkspaceScaffold -Pill "red"
    Write-Host "  ✓ Workspace created at $wsPath" -ForegroundColor Green
}

# Step 14: Git init + config
Write-Host "`nStep 7: Setting up git..." -ForegroundColor White
$gitDir = Join-Path $wsPath ".git"
if (-not (Test-Path $gitDir)) {
    Push-Location $wsPath
    git init --initial-branch=main 2>$null
    Pop-Location
    Write-Host "  ✓ Git initialized" -ForegroundColor Green
}
else {
    Write-Host "  ✓ Git already initialized" -ForegroundColor Green
}

# Step 15: GitHub authentication
Write-Host "`nStep 8: GitHub authentication..." -ForegroundColor White
$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Launching GitHub login..." -ForegroundColor Yellow
    gh auth login --web --git-protocol https
    if ($LASTEXITCODE -ne 0) { throw "GitHub authentication failed" }
}
$ghUser = (gh api user --jq .login 2>$null)
if (-not $ghUser) { throw "Could not determine GitHub username" }
Write-Host "  ✓ Authenticated as: $ghUser" -ForegroundColor Green

# Configure git user
Push-Location $wsPath
git config user.name $ghUser
git config user.email "$ghUser@users.noreply.github.com"
Pop-Location

# Step 16: Create private repo + push
Write-Host "`nStep 9: Creating GitHub repo..." -ForegroundColor White
$repoName = "ai-workspace"
$repoExists = $null -ne (gh repo view "$ghUser/$repoName" --json name 2>$null)
if (-not $repoExists) {
    gh repo create $repoName --private --description "AI Maker v3 workspace"
    if ($LASTEXITCODE -ne 0) { throw "gh repo create failed" }
    Write-Host "  ✓ Created private repo: $ghUser/$repoName" -ForegroundColor Green
}
else {
    Write-Host "  ✓ Repo already exists" -ForegroundColor Green
}

Push-Location $wsPath
$existingRemote = git remote get-url origin 2>$null
if (-not $existingRemote) {
    git remote add origin "https://github.com/$ghUser/$repoName.git"
}
git add -A 2>$null
$status = git status --porcelain 2>$null
if ($status) {
    git commit -m "AI Maker v3 — initial setup (Red Pill)" 2>$null
    git push -u origin main 2>$null
    Write-Host "  ✓ Pushed to GitHub" -ForegroundColor Green
}
else {
    Write-Host "  ✓ Already up to date" -ForegroundColor Green
}
Pop-Location

# Step 17: Write manifest
Write-Host "`nStep 10: Writing manifest..." -ForegroundColor White
$manifest = New-AIMakerManifest -Pill "red" -Skills $installedSkills
Write-AIMakerManifest -Manifest $manifest
Write-Host "  ✓ Manifest written" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# PHASE 3: LAUNCH (PRD §6.2 steps 18-19)
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |       ✓ Red Pill installed!              |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  What you got:" -ForegroundColor White
Write-Host "    • 22 skills (11 AI Maker + 11 AI Workbench)" -ForegroundColor Gray
Write-Host "    • Git-backed workspace: $wsPath" -ForegroundColor Gray
Write-Host "    • Private repo: https://github.com/$ghUser/$repoName" -ForegroundColor Gray
Write-Host ""
Write-Host "  Opening the Copilot App..." -ForegroundColor White

# Step 18: Launch via Agency
& $agency gh-app

Write-Host ""
Write-Host "  Add $wsPath as a project in the App." -ForegroundColor Cyan
Write-Host ""


