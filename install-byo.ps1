#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 — Bring Your Own Agents Installer
.DESCRIPTION
    Full infra: Dev Tools + GitHub Copilot App + WorkIQ + GitHub auth.
    Does NOT install AI Maker or AI Workbench skills/agents. Instead,
    clones a GitHub repo of the user's own choosing (their existing
    agent/skills setup) straight into C:\GitHub\<repo-name>, exactly
    like pc-setup's repo clone step — no merge, no overlay.
.NOTES
    SIDE-BY-SIDE INSTALL: does not touch C:\AIMaker, C:\AIWorkbench, or
    C:\GitHub\ai-workspace. This path is for users who already have their
    own agent repo and just want the infra AI Maker normally sets up.
#>
[CmdletBinding()]
param(
    [string]$Repo
)

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
Write-Host "  +------------------------------------------+" -ForegroundColor Magenta
Write-Host "  |    AI Maker v3 - Bring Your Own Agents   |" -ForegroundColor Magenta
Write-Host "  |   Infra only, sync your own agent repo   |" -ForegroundColor Magenta
Write-Host "  +------------------------------------------+" -ForegroundColor Magenta
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# PHASE 1: DEVELOPER TOOLS (same as Red Pill)
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
# PHASE 2: GITHUB AUTH (needed to clone the user's own repo)
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 5: GitHub authentication..." -ForegroundColor White
if (-not (Get-Command gh -EA SilentlyContinue)) {
    Write-Host "  Installing GitHub CLI..." -ForegroundColor Yellow
    winget install GitHub.cli --source winget --accept-source-agreements --accept-package-agreements --silent
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

# ═══════════════════════════════════════════════════════════════
# PHASE 3: SYNC YOUR OWN AGENT REPO (no AI Maker/Workbench install)
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 6: Sync your own agent repo..." -ForegroundColor White

# Accept "org/repo", a full https URL, or a git@ URL; normalize to "org/repo" for gh
function Resolve-BYORepoSlug {
    param([string]$Input)
    $s = $Input.Trim().TrimEnd("/")
    $s = $s -replace "^git@github\.com:", ""
    $s = $s -replace "^https?://github\.com/", ""
    $s = $s -replace "\.git$", ""
    return $s
}

$repoSlug = $null
for ($attempt = 1; $attempt -le 3; $attempt++) {
    $candidate = if ($Repo) { $Repo } else { Read-Host "  Enter the GitHub repo with your agents (e.g. org/repo)" }
    $Repo = $null  # only honor the -Repo param on the first pass
    $slug = Resolve-BYORepoSlug $candidate
    if ($slug -notmatch "^[\w.-]+/[\w.-]+$") {
        Write-Host "  ⚠ '$candidate' doesn't look like org/repo or a GitHub URL — try again" -ForegroundColor Yellow
        continue
    }
    $repoSlug = $slug
    break
}
if (-not $repoSlug) { throw "No valid repo provided after 3 attempts — nothing to sync." }

# Confirm the repo actually exists / is reachable before touching disk
$repoInfo = gh repo view $repoSlug --json nameWithOwner,url 2>$null | ConvertFrom-Json
if (-not $repoInfo) { throw "Could not find or access repo '$repoSlug' — check spelling and your GitHub access." }
$repoSlug = $repoInfo.nameWithOwner
$repoName = ($repoSlug -split "/")[-1]
$destPath = Join-Path "C:\GitHub" $repoName

if (Test-Path (Join-Path $destPath ".git")) {
    Push-Location $destPath
    $existingOrigin = git remote get-url origin 2>$null
    Pop-Location
    $existingSlug = $existingOrigin -replace "^https?://github\.com/", "" -replace "^git@github\.com:", "" -replace "\.git$", ""
    if ($existingSlug -and $existingSlug -ne $repoSlug) {
        throw "C:\GitHub\$repoName already exists and is a different repo ($existingSlug). Rename/move it or choose a different destination before re-running."
    }
    Write-Host "  ✓ $repoName already exists at $destPath — pulling latest" -ForegroundColor Green
    Push-Location $destPath
    try {
        git pull --quiet 2>$null
        if ($LASTEXITCODE -ne 0) { throw "git pull failed in $destPath (uncommitted changes or diverged branch?)" }
    } finally {
        Pop-Location
    }
}
elseif (Test-Path $destPath) {
    throw "C:\GitHub\$repoName exists but isn't a git repo — move it aside and re-run."
}
else {
    New-Item -ItemType Directory -Path "C:\GitHub" -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  Cloning $repoSlug..." -ForegroundColor Yellow
    gh repo clone $repoSlug $destPath 2>$null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $destPath ".git"))) { throw "Failed to clone $repoSlug" }
    Write-Host "  ✓ Cloned to $destPath" -ForegroundColor Green
}

# Configure git identity in the synced repo (same as Red Pill) so first commit doesn't fail
Push-Location $destPath
if (-not (git config user.name 2>$null)) { git config user.name $ghUser }
if (-not (git config user.email 2>$null)) { git config user.email "$ghUser@users.noreply.github.com" }
Pop-Location

# Breadcrumb for verify.ps1 / Invoke-HealthCheck — NOT a full AI Maker manifest (no skills/agents installed)
$byoStateDir = Join-Path $env:USERPROFILE ".copilot\ai-maker"
New-Item -ItemType Directory -Path $byoStateDir -Force -ErrorAction SilentlyContinue | Out-Null
@{
    pill        = "byo"
    repo        = $repoSlug
    path        = $destPath
    synced_at   = (Get-Date).ToString("o")
} | ConvertTo-Json | Set-Content (Join-Path $byoStateDir "byo-manifest.json")

# ═══════════════════════════════════════════════════════════════
# PHASE 4: LAUNCH
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |   ✓ Bring Your Own Agents installed!     |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  What you got:" -ForegroundColor White
Write-Host "    • Dev tools: Git, GitHub Copilot App, GitHub CLI" -ForegroundColor Gray
Write-Host "    • WorkIQ plugin (M365 data via natural language)" -ForegroundColor Gray
Write-Host "    • Your own agent repo synced: $destPath" -ForegroundColor Gray
Write-Host "    • No AI Maker / AI Workbench skills or agents installed" -ForegroundColor Gray
Write-Host ""

# Launch Copilot App pointed at the synced repo, not C:\GitHub\ai-workspace
Write-Host "  Opening the Copilot App..." -ForegroundColor White
$copilotExe = Join-Path $env:LOCALAPPDATA "Programs\GitHub Copilot\github.exe"
if (Test-Path $copilotExe) {
    Start-Process $copilotExe -ArgumentList $destPath
} else {
    Write-Host "  ⚠ Could not find the app. Launch 'GitHub Copilot' from the Start menu." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Next: Connect WorkIQ to Microsoft 365" -ForegroundColor Yellow
Write-Host "    Settings > MCP servers > Plugins tab > click Sign in next to workiq" -ForegroundColor Cyan
Write-Host "    Sign in with your alias@microsoft.com account." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Your synced repo is at: $destPath" -ForegroundColor Cyan
Write-Host ""
