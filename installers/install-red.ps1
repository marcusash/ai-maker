#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 — Red Pill Installer
.DESCRIPTION
    Full experience: Copilot App + 22 skills + git-backed workspace.
    Downloads skills from GitHub release, installs git, creates private repo.
#>
[CmdletBinding()]
param(
    [switch]$Doctor,
    [string]$RepoName = "ai-workspace"
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
Write-Host "  +------------------------------------------+" -ForegroundColor Red
Write-Host "  |       AI Maker v3 - Red Pill             |" -ForegroundColor Red
Write-Host "  |   Full experience with GitHub backup     |" -ForegroundColor Red
Write-Host "  +------------------------------------------+" -ForegroundColor Red
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
Write-Host "  ✓ Disk space OK ($($diskCheck.available) GB free)" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# STEP 2: INSTALL GIT
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 2: Installing developer tools..." -ForegroundColor White

if (Get-Command git -EA Silent) {
    $gitVer = (git --version 2>$null) -replace "git version ", ""
    Write-Host "  ✓ Git $gitVer already installed" -ForegroundColor Green
}
else {
    winget install Git.Git --accept-source-agreements --accept-package-agreements --silent
    if ($LASTEXITCODE -ne 0) { throw "winget install failed for Git.Git (exit: $LASTEXITCODE)" }
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Host "  ✓ Git installed" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# STEP 3: GITHUB AUTHENTICATION
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 3: Checking GitHub authentication..." -ForegroundColor White

$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Not authenticated. Running: gh auth login" -ForegroundColor Yellow
    gh auth login --web --git-protocol https
    if ($LASTEXITCODE -ne 0) { throw "GitHub authentication failed. Run 'gh auth login' manually and retry." }
}

$ghUser = (gh api user --jq .login 2>$null)
if (-not $ghUser) { throw "Could not determine GitHub username. Run 'gh auth login' and retry." }
Write-Host "  ✓ Authenticated as: $ghUser" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# STEP 4: DOWNLOAD + INSTALL SKILLS (22)
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 4: Installing all skills (22)..." -ForegroundColor White

$zipPath     = Join-Path $env:TEMP "ai-maker-skills.zip"
$extractPath = Join-Path $env:TEMP "ai-maker-skills"

Write-Host "  Downloading skills..." -ForegroundColor Gray
Invoke-RestMethod -Uri "https://github.com/marcusash/ai-maker/releases/latest/download/skills.zip" -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

$existingManifest = Read-AIMakerManifest
$installedSkills  = Install-Skills -Pill "red" -SourcePath (Join-Path $extractPath "skills") -Manifest $existingManifest

$makerCount     = ($installedSkills | Where-Object { $_.id -like "ai-maker-*" }).Count
$workbenchCount = ($installedSkills | Where-Object { $_.id -like "ai-workbench-*" }).Count
Write-Host "  ✓ $makerCount AI Maker + $workbenchCount AI Workbench skills installed ($($installedSkills.Count) total)" -ForegroundColor Green

Remove-Item $zipPath -EA SilentlyContinue
Remove-Item $extractPath -Recurse -EA SilentlyContinue

# ═══════════════════════════════════════════════════════════════
# STEP 5: CREATE WORKSPACE
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 5: Creating workspace..." -ForegroundColor White

$wsPath     = $script:AIMakerConfig.WorkspacePath
$wsManifest = Join-Path $wsPath $script:AIMakerConfig.ManifestFile

if (Test-Path $wsManifest) {
    Write-Host "  ✓ Workspace already exists" -ForegroundColor Green
}
else {
    New-WorkspaceScaffold -Pill "red"
    Write-Host "  ✓ Workspace created at $wsPath" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# STEP 6: GIT INIT + REMOTE
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 6: Setting up git repository..." -ForegroundColor White

$gitDir = Join-Path $wsPath ".git"

# git init
if (Test-Path $gitDir) {
    Write-Host "  ✓ Git already initialized" -ForegroundColor Green
}
else {
    Push-Location $wsPath
    git init --initial-branch=main 2>$null
    git config user.name $ghUser
    git config user.email "$ghUser@users.noreply.github.com"
    Pop-Location
    Write-Host "  ✓ Git initialized (branch: main)" -ForegroundColor Green
}

# Create GitHub repo (private)
$repoExists = $null -ne (gh repo view "$ghUser/$RepoName" --json name 2>$null)
if ($repoExists) {
    Write-Host "  ✓ Remote repo already exists" -ForegroundColor Green
}
else {
    gh repo create $RepoName --private --description "AI Maker v3 workspace"
    if ($LASTEXITCODE -ne 0) { throw "gh repo create failed (exit: $LASTEXITCODE)" }
    Write-Host "  ✓ Created private repo: $ghUser/$RepoName" -ForegroundColor Green
}

# Set remote
Push-Location $wsPath
$existingRemote = git remote get-url origin 2>$null
if (-not $existingRemote) {
    git remote add origin "https://github.com/$ghUser/$RepoName.git"
    Write-Host "  ✓ Remote 'origin' set" -ForegroundColor Green
}
else {
    Write-Host "  ✓ Remote 'origin' already configured" -ForegroundColor Green
}
Pop-Location

# ═══════════════════════════════════════════════════════════════
# STEP 7: WRITE MANIFEST
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 7: Writing manifest..." -ForegroundColor White

$manifest = New-AIMakerManifest -Pill "red" -Skills $installedSkills
Write-AIMakerManifest -Manifest $manifest
Write-Host "  ✓ Manifest written" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# STEP 8: INITIAL COMMIT + PUSH
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 8: Initial commit and push..." -ForegroundColor White

Push-Location $wsPath
git add -A 2>$null
$status = git status --porcelain 2>$null

if ($status) {
    git commit -m "AI Maker v3 — initial setup (Red Pill)" 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
    Write-Host "  ✓ Committed" -ForegroundColor Green

    git push -u origin main 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git push failed (exit: $LASTEXITCODE)" }
    Write-Host "  ✓ Pushed to GitHub" -ForegroundColor Green
}
else {
    Write-Host "  ✓ Already up to date" -ForegroundColor Green
}
Pop-Location

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║        ✓ Red Pill installed!              ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  What you got:" -ForegroundColor White
Write-Host "    • 22 skills (11 AI Maker + 11 AI Workbench)" -ForegroundColor Gray
Write-Host "    • Git-backed workspace at: $wsPath" -ForegroundColor Gray
Write-Host "    • Private GitHub repo: https://github.com/$ghUser/$RepoName" -ForegroundColor Gray
Write-Host ""
Write-Host "  Open the Copilot App and add this folder as a project:" -ForegroundColor White
Write-Host "  $wsPath" -ForegroundColor Cyan
Write-Host ""

