#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 — Red Pill Installer
.DESCRIPTION
    Full experience: Dev Tools + all skills + GitHub backup + WorkIQ
    Installs Git, GitHub CLI, creates private repo, 22 skills, WorkIQ plugin.
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
Write-Host "  +------------------------------------------+" -ForegroundColor Red
Write-Host "  |       AI Maker v3 - Red Pill             |" -ForegroundColor Red
Write-Host "  |   Full experience with GitHub backup     |" -ForegroundColor Red
Write-Host "  +------------------------------------------+" -ForegroundColor Red
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# PHASE 1: DEVELOPER TOOLS
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
    winget install Git.Git --accept-source-agreements --accept-package-agreements --silent
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
    winget install GitHub.CopilotApp --accept-source-agreements --accept-package-agreements --silent
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

# Step 5: Install all 22 skills
Write-Host "`nStep 5: Installing all skills (22)..." -ForegroundColor White
$zipPath = Join-Path $env:TEMP "ai-maker-skills.zip"
$extractPath = Join-Path $env:TEMP "ai-maker-skills"
Remove-Item $extractPath -Recurse -Force -EA SilentlyContinue
Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/skills.zip" -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
$installedSkills = Install-Skills -Pill "red" -SourcePath $extractPath -Manifest (Read-AIMakerManifest)
$makerCount = ($installedSkills | Where-Object { $_.id -like "ai-maker-*" }).Count
$workbenchCount = ($installedSkills | Where-Object { $_.id -like "ai-workbench-*" }).Count
Write-Host "  ✓ $makerCount AI Maker + $workbenchCount AI Workbench skills ($($installedSkills.Count) total)" -ForegroundColor Green
Remove-Item $zipPath -EA SilentlyContinue
Remove-Item $extractPath -Recurse -EA SilentlyContinue

# Step 6: Create workspace + agents
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
    New-WorkspaceScaffold -Pill "red" -AgentSourcePath $agentsDir
    Remove-Item $agentsDir -Recurse -EA SilentlyContinue
    Write-Host "  ✓ Workspace created at $wsPath" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# PHASE 3: GITHUB BACKUP (git + private repo)
# ═══════════════════════════════════════════════════════════════

# Step 7: Git init
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

# Step 8: GitHub CLI + authentication
Write-Host "`nStep 8: GitHub authentication..." -ForegroundColor White
if (-not (Get-Command gh -EA SilentlyContinue)) {
    Write-Host "  Installing GitHub CLI..." -ForegroundColor Yellow
    winget install GitHub.cli --accept-source-agreements --accept-package-agreements --silent
    if ($LASTEXITCODE -ne 0) { throw "Failed to install GitHub CLI" }
    $env:PATH += ";${env:ProgramFiles}\GitHub CLI"
    Write-Host "  ✓ GitHub CLI installed" -ForegroundColor Green
}
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

# Step 9: Create private repo + push
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

# Step 10: Write manifest
Write-Host "`nStep 10: Writing manifest..." -ForegroundColor White
$manifest = New-AIMakerManifest -Pill "red" -Skills $installedSkills
Write-AIMakerManifest -Manifest $manifest
Write-Host "  ✓ Manifest written" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# PHASE 4: LAUNCH
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |       ✓ Red Pill installed!              |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  What you got:" -ForegroundColor White
Write-Host "    • 22 skills (11 AI Maker + 11 AI Workbench)" -ForegroundColor Gray
Write-Host "    • WorkIQ plugin (M365 data via natural language)" -ForegroundColor Gray
Write-Host "    • Git-backed workspace: $wsPath" -ForegroundColor Gray
Write-Host "    • Private repo: https://github.com/$ghUser/$repoName" -ForegroundColor Gray
Write-Host ""

# Launch Copilot App
Write-Host "  Opening the Copilot App..." -ForegroundColor White
$copilotExe = Join-Path $env:LOCALAPPDATA "Programs\GitHub Copilot\github.exe"
if (Test-Path $copilotExe) {
    Start-Process $copilotExe -ArgumentList $wsPath
} else {
    Write-Host "  ⚠ Could not find the app. Launch 'GitHub Copilot' from the Start menu." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Next: Connect WorkIQ to Microsoft 365" -ForegroundColor Yellow
Write-Host "    Settings > MCP servers > Plugins tab > click Sign in next to workiq" -ForegroundColor Cyan
Write-Host "    Sign in with your alias@microsoft.com account." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Your workspace is at: $wsPath" -ForegroundColor Cyan
Write-Host ""
