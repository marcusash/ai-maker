#Requires -Version 5.1
<#
.SYNOPSIS
    AI Maker v3 — Red Pill Installer
.DESCRIPTION
    Installs the full experience: Copilot App (via Agency) + 22 skills + git-backed workspace.
    Includes git, repo creation, and push. GitHub CLI handled by the App.
    Target: technical users who want backup, restore, and version history.
.PARAMETER WhatIf
    Preview all changes without executing.
.PARAMETER Doctor
    Run health check diagnostics.
.PARAMETER SkillsOnly
    Update skills without reinstalling components.
.PARAMETER SkillsSource
    Path to skills source directory (default: downloads from release).
.PARAMETER RepoName
    Name of the GitHub repo to create (default: ai-workspace).
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Doctor,
    [switch]$SkillsOnly,
    [string]$SkillsSource,
    [string]$RepoName = "ai-workspace"
)

$ErrorActionPreference = "Stop"

# ═══════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════

function Show-Banner {
    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Red
    Write-Host "  |       AI Maker v3 - Red Pill             |" -ForegroundColor Red
    Write-Host "  |   Full experience with GitHub backup     |" -ForegroundColor Red
    Write-Host "  +------------------------------------------+" -ForegroundColor Red
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
# LOAD LIBRARY
# ═══════════════════════════════════════════════════════════════

$libPath = Join-Path $PSScriptRoot "ai-maker-lib.ps1"
if (-not (Test-Path $libPath)) {
    $libUrl = "https://github.com/marcusash/ai-maker/releases/latest/download/ai-maker-lib.ps1"
    $libPath = Join-Path $env:TEMP "ai-maker-lib.ps1"
    Write-Host "  Downloading core library..." -ForegroundColor Gray
    Invoke-RestMethod -Uri $libUrl -OutFile $libPath
}
. $libPath

# ═══════════════════════════════════════════════════════════════
# MODES
# ═══════════════════════════════════════════════════════════════

Show-Banner

if ($Doctor) {
    Invoke-HealthCheck
    return
}

if ($WhatIf) {
    Write-Host "  ── DRY RUN MODE ── Nothing will be modified.`n" -ForegroundColor Cyan
}

# ═══════════════════════════════════════════════════════════════
# STEP 1: PREREQUISITES
# ═══════════════════════════════════════════════════════════════

Write-Host "Step 1: Checking prerequisites..." -ForegroundColor White

# Windows version
$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 10) {
    Write-Host "  ✗ Windows 10 or later required." -ForegroundColor Red
    return
}
Write-Host "  ✓ Windows $($osVersion.Major).$($osVersion.Build)" -ForegroundColor Green

# winget
$hasWinget = (Get-Command winget -EA Silent) -ne $null
if (-not $hasWinget) {
    Write-Host "  ✗ winget not found. Install App Installer from the Microsoft Store." -ForegroundColor Red
    Write-Host "    https://aka.ms/getwinget" -ForegroundColor Gray
    return
}
Write-Host "  ✓ winget available" -ForegroundColor Green

# Disk space (Red needs more — repo + .git)
$diskCheck = Get-DiskSpaceCheck
if (-not $diskCheck.ok) {
    Write-Host "  ✗ $($diskCheck.message)" -ForegroundColor Red
    return
}
Write-Host "  ✓ Disk space OK ($($diskCheck.available) GB free)" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# STEP 2: DETECT EXISTING STATE
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 2: Detecting existing setup..." -ForegroundColor White

$scenario = Get-InstallScenario
Write-Host "  Scenario: $($scenario.scenario)" -ForegroundColor Gray
Write-Host "  Action: $($scenario.action)" -ForegroundColor Gray

# Handle blocking scenarios
if ($scenario.scenario -eq "remote-conflict") {
    Write-Host "`n  ✗ CONFLICT: A repo named '$RepoName' exists on GitHub but wasn't created by this installer." -ForegroundColor Red
    Write-Host "  Options:" -ForegroundColor Yellow
    Write-Host "    1. Rename the existing repo on GitHub" -ForegroundColor Gray
    Write-Host "    2. Run with -RepoName <different-name>" -ForegroundColor Gray
    return
}

if ($scenario.scenario -eq "remote-unrelated") {
    Write-Host "`n  ✗ CONFLICT: '$RepoName' repo exists on GitHub but is unrelated." -ForegroundColor Red
    Write-Host "  Run with -RepoName <different-name> to use a different repo name." -ForegroundColor Gray
    return
}

if ($scenario.scenario -match "^legacy") {
    Write-Host "`n  ⚠ Existing CLI installation detected." -ForegroundColor Yellow
    Write-Host "  This installer will set up the new system alongside your existing one." -ForegroundColor Yellow
    Write-Host "  After this completes, run migrate.ps1 to move your data." -ForegroundColor Yellow
    Write-Host "  Your existing files will NOT be touched.`n" -ForegroundColor Yellow
}

if ($scenario.scenario -eq "partial-install") {
    Write-Host "  ⚠ Previous partial install detected. Resuming..." -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════
# STEP 3: INSTALL DEVELOPER TOOLS
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly) {
    Write-Host "`nStep 3: Installing developer tools..." -ForegroundColor White

    # Git
    $hasGit = (Get-Command git -EA Silent) -ne $null
    if ($hasGit) {
        $gitVer = (git --version 2>$null) -replace "git version ", ""
        Write-Host "  ✓ Git $gitVer already installed" -ForegroundColor Green
    }
    else {
        Invoke-TxOp -Operation "WINGET_INSTALL" -Description "Install Git" `
            -Path "Git.Git" -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
            winget install Git.Git --accept-source-agreements --accept-package-agreements --silent
            if ($LASTEXITCODE -ne 0) { throw "winget install failed for Git.Git (exit: $LASTEXITCODE)" }
        }
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        Write-Host "  ✓ Git installed" -ForegroundColor Green
    }

    # NOTE: GitHub CLI and Copilot CLI extension are no longer installed separately.
    # The Copilot App (installed via agency gh-app) handles this. PRD §6.2.

    # GitHub Copilot App — installed via agency gh-app (PRD §8 mandate)
    # agency gh-app downloads + installs the App on first run.
    # We no longer use winget install GitHub.CopilotApp.
}

# ═══════════════════════════════════════════════════════════════
# STEP 4: GITHUB AUTHENTICATION
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly) {
    Write-Host "`nStep 4: Checking GitHub authentication..." -ForegroundColor White

    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ⚠ Not authenticated with GitHub." -ForegroundColor Yellow
        Write-Host "  Running: gh auth login" -ForegroundColor Gray

        if (-not $WhatIf) {
            gh auth login --web --git-protocol https
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  ✗ GitHub authentication failed. Run 'gh auth login' manually and retry." -ForegroundColor Red
                return
            }
        }
        else {
            Write-Host "  [WhatIf] Would run gh auth login" -ForegroundColor Cyan
        }
    }

    # Get authenticated username
    $ghUser = (gh api user --jq .login 2>$null)
    if (-not $ghUser) {
        Write-Host "  ✗ Could not determine GitHub username. Run 'gh auth login' and retry." -ForegroundColor Red
        return
    }
    Write-Host "  ✓ Authenticated as: $ghUser" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# STEP 5: INSTALL SKILLS (ALL 22)
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 5: Installing all skills (22)..." -ForegroundColor White

if (-not $SkillsSource) {
    $releaseUrl = "https://github.com/marcusash/ai-maker/releases/latest/download/skills.zip"
    $zipPath = Join-Path $env:TEMP "ai-maker-skills.zip"
    $extractPath = Join-Path $env:TEMP "ai-maker-skills"

    if (-not $WhatIf) {
        Write-Host "  Downloading skills..." -ForegroundColor Gray
        Invoke-RestMethod -Uri $releaseUrl -OutFile $zipPath
        if (-not (Test-Path $zipPath)) { throw "skills.zip download failed — file not found at $zipPath" }
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        $SkillsSource = Join-Path $extractPath "skills"
        if (-not (Test-Path $SkillsSource)) { throw "skills.zip extracted but '$SkillsSource' not found — zip structure may be wrong" }
    }
    else {
        Write-Host "  [WhatIf] Would download skills from $releaseUrl" -ForegroundColor Cyan
        $SkillsSource = "DOWNLOAD"
    }
}

if (-not $WhatIf) {
    $existingManifest = Read-AIMakerManifest
    $installedSkills = Install-Skills -Pill "red" -SourcePath $SkillsSource -Manifest $existingManifest -WhatIf:$WhatIf

    $makerCount = ($installedSkills | Where-Object { $_.id -like "ai-maker-*" }).Count
    $workbenchCount = ($installedSkills | Where-Object { $_.id -like "ai-workbench-*" }).Count
    Write-Host "  ✓ $makerCount AI Maker + $workbenchCount AI Workbench skills installed ($($installedSkills.Count) total)" -ForegroundColor Green
}
else {
    Write-Host "  [WhatIf] Would install 22 skills (11 ai-maker + 11 ai-workbench) to ~/.copilot/skills/" -ForegroundColor Cyan
    $installedSkills = @()
}

# ═══════════════════════════════════════════════════════════════
# STEP 6: CREATE WORKSPACE
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly) {
    Write-Host "`nStep 6: Creating workspace..." -ForegroundColor White

    $wsPath = $script:AIMakerConfig.WorkspacePath

    if (Test-Path (Join-Path $wsPath $script:AIMakerConfig.ManifestFile)) {
        Write-Host "  ✓ Workspace already exists" -ForegroundColor Green
    }
    else {
        # Ensure agents are available (download if running from TEMP)
        $agentsDir = Join-Path $PSScriptRoot "agents"
        if (-not (Test-Path $agentsDir)) {
            Write-Host "  Downloading agent identities..." -ForegroundColor Gray
            $agentsZipUrl = "https://github.com/marcusash/ai-maker/releases/latest/download/agents.zip"
            $agentsZipPath = Join-Path $env:TEMP "ai-maker-agents.zip"
            Invoke-RestMethod -Uri $agentsZipUrl -OutFile $agentsZipPath
            New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
            Expand-Archive -Path $agentsZipPath -DestinationPath $agentsDir -Force
            Write-Host "  [OK] agents downloaded" -ForegroundColor Green
        }
        New-WorkspaceScaffold -Pill "red" -WhatIf:$WhatIf
        Write-Host "  ✓ Workspace created at $wsPath" -ForegroundColor Green
    }
}

# ═══════════════════════════════════════════════════════════════
# STEP 7: GIT INIT + REMOTE
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly) {
    Write-Host "`nStep 7: Setting up git repository..." -ForegroundColor White

    $wsPath = $script:AIMakerConfig.WorkspacePath
    $gitDir = Join-Path $wsPath ".git"

    # git init
    if (Test-Path $gitDir) {
        Write-Host "  ✓ Git already initialized" -ForegroundColor Green
    }
    else {
        Invoke-TxOp -Operation "GIT_INIT" -Description "Initialize git repository" `
            -Path $wsPath -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            Push-Location $wsPath
            git init --initial-branch=main 2>$null
            git config user.name $ghUser
            git config user.email "$ghUser@users.noreply.github.com"
            Pop-Location
        }
        Write-Host "  ✓ Git initialized (branch: main)" -ForegroundColor Green
    }

    # Create GitHub repo (private)
    $repoExists = $null -ne (gh repo view "$ghUser/$RepoName" --json name 2>$null)
    if ($repoExists) {
        # Validate it's ours
        $hasManifest = $null -ne (gh api "repos/$ghUser/$RepoName/contents/$($script:AIMakerConfig.ManifestFile)" 2>$null)
        if ($hasManifest) {
            Write-Host "  ✓ Remote repo exists and is ours" -ForegroundColor Green
        }
        else {
            # Repo exists but might be empty or from first push — allow if no manifest yet
            $repoContent = gh api "repos/$ghUser/$RepoName/contents/" 2>$null
            if ($LASTEXITCODE -ne 0) {
                # Empty repo — safe to push
                Write-Host "  ✓ Remote repo exists (empty — safe to push)" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠ Remote repo '$RepoName' exists but wasn't created by this installer." -ForegroundColor Yellow
                Write-Host "  Proceeding — will push manifest on first commit." -ForegroundColor Yellow
            }
        }
    }
    else {
        Invoke-TxOp -Operation "GH_REPO_CREATE" -Description "Create private GitHub repo: $ghUser/$RepoName" `
            -Path "$ghUser/$RepoName" -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
            gh repo create $RepoName --private --description "AI Maker v3 workspace — skills, vault, and configuration"
            if ($LASTEXITCODE -ne 0) { throw "gh repo create failed (exit: $LASTEXITCODE)" }
        }
        Write-Host "  ✓ Created private repo: $ghUser/$RepoName" -ForegroundColor Green
    }

    # Set remote
    if (-not $WhatIf) {
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
    }
    else {
        Write-Host "  [WhatIf] Would set remote to https://github.com/$ghUser/$RepoName.git" -ForegroundColor Cyan
    }
}

# ═══════════════════════════════════════════════════════════════
# STEP 8: WRITE MANIFEST
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 8: Writing manifest..." -ForegroundColor White

$manifest = New-AIMakerManifest -Pill "red" -Skills $installedSkills
Write-AIMakerManifest -Manifest $manifest -WhatIf:$WhatIf

Write-Host "  ✓ Manifest written" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# STEP 9: INITIAL COMMIT + PUSH
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly) {
    Write-Host "`nStep 9: Initial commit and push..." -ForegroundColor White

    if (-not $WhatIf) {
        Push-Location $wsPath

        # Stage everything
        git add -A 2>$null

        # Check if there's anything to commit
        $status = git status --porcelain 2>$null
        if ($status) {
            Invoke-TxOp -Operation "GIT_COMMIT" -Description "Initial commit" `
                -Path $wsPath -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
                git commit -m "AI Maker v3 — initial setup (Red Pill)" 2>$null
                if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
            }
            Write-Host "  ✓ Committed" -ForegroundColor Green

            Invoke-TxOp -Operation "GIT_PUSH" -Description "Push to GitHub" `
                -Path "$ghUser/$RepoName" -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
                git push -u origin main 2>$null
                if ($LASTEXITCODE -ne 0) { throw "git push failed (exit: $LASTEXITCODE)" }
            }
            Write-Host "  ✓ Pushed to GitHub" -ForegroundColor Green
        }
        else {
            Write-Host "  ✓ No changes to commit (already up to date)" -ForegroundColor Green
        }

        Pop-Location
    }
    else {
        Write-Host "  [WhatIf] Would commit and push to $ghUser/$RepoName" -ForegroundColor Cyan
    }
}

# ═══════════════════════════════════════════════════════════════
# STEP 10: INSTALL AGENCY + REGISTER MCP SERVERS (PRD §6.2, §8)
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly -and -not $WhatIf) {
    Write-Host "`nStep 10: Setting up Agency (M365 integration)..." -ForegroundColor White

    # Resolve agency.exe from known install locations
    function Resolve-Agency {
        $candidates = @(
            (Get-Command agency.exe -EA SilentlyContinue).Source,
            "$env:APPDATA\agency\CurrentVersion\agency.exe",
            "$env:LOCALAPPDATA\Microsoft\agency\agency.exe",
            "$env:LOCALAPPDATA\agency\CurrentVersion\agency.exe"
        )
        foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
        return $null
    }

    $agency = Resolve-Agency
    if (-not $agency) {
        Write-Host "  Installing Agency..." -ForegroundColor Gray
        try {
            iex "& { $(irm https://aka.ms/InstallTool.ps1) } agency" 2>$null
            $agency = Resolve-Agency
        } catch {
            Write-Host "  ⚠ Agency install failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    if ($agency) {
        Write-Host "  ✓ Agency found: $agency" -ForegroundColor Green

        # Set SHELL env var (PRD §5.2)
        $gitSh = Join-Path (Split-Path (Get-Command git -EA SilentlyContinue).Source) "..\usr\bin\sh.exe"
        if (Test-Path $gitSh) {
            $resolved = (Resolve-Path $gitSh).Path
            [System.Environment]::SetEnvironmentVariable("SHELL", $resolved, "User")
            $env:SHELL = $resolved
            Write-Host "  ✓ SHELL env var set: $resolved" -ForegroundColor Green
        }

        # Write MCP config (workiq + bluebird) — direct JSON write per PRD §8.4
        $mcpCfg = $script:AIMakerConfig.McpServersPath
        $needsConfig = $true
        if (Test-Path $mcpCfg) {
            try {
                $existing = Get-Content $mcpCfg -Raw | ConvertFrom-Json -AsHashtable
                $servers = @($existing.mcpServers.Keys)
                if (($servers -contains 'workiq') -and ($servers -contains 'bluebird')) {
                    Write-Host "  ✓ MCP config already has workiq + bluebird" -ForegroundColor Green
                    $needsConfig = $false
                }
            } catch { }
        }

        if ($needsConfig) {
            $mcpObj = @{
                mcpServers = @{
                    workiq = @{
                        command = $agency
                        args    = @('mcp','workiq')
                    }
                    bluebird = @{
                        command = $agency
                        args    = @('mcp','bluebird')
                    }
                }
            } | ConvertTo-Json -Depth 10
            New-Item -ItemType Directory -Force -Path (Split-Path $mcpCfg) | Out-Null
            [System.IO.File]::WriteAllText($mcpCfg, $mcpObj, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "  ✓ MCP config written (workiq + bluebird)" -ForegroundColor Green
        }

        # Agency-native MCP servers (PRD §8.5)
        foreach ($srv in @('teams','outlook','planner')) {
            try {
                & $agency config set --global --mcp $srv 2>$null
            } catch { }
        }
        Write-Host "  ✓ Agency-native MCP servers configured (teams, outlook, planner)" -ForegroundColor Green

        # MCP liveness probe (non-fatal — PRD §8)
        Test-McpLiveness -ServerName "workiq" | Out-Null
    } else {
        Write-Host "  ⚠ Agency not available — WorkIQ/M365 features will not work until Agency is installed" -ForegroundColor Yellow
        Write-Host "    Re-run this installer after Agency is available" -ForegroundColor Gray
    }
}
elseif ($WhatIf -and -not $SkillsOnly) {
    Write-Host "`nStep 10: [WhatIf] Would install Agency and register MCP servers (workiq + bluebird + teams + outlook + planner)" -ForegroundColor Cyan
}

# ═══════════════════════════════════════════════════════════════
# STEP 11: CLEANUP + INSTRUCTIONS
# ═══════════════════════════════════════════════════════════════

# Clean up temp files
if (-not $WhatIf) {
    Remove-Item (Join-Path $env:TEMP "ai-maker-skills.zip") -EA Silent
    Remove-Item (Join-Path $env:TEMP "ai-maker-skills") -Recurse -EA Silent
}

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║        ✓ Red Pill installed!              ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  What you got:" -ForegroundColor White
Write-Host "    • GitHub Copilot App — your AI interface" -ForegroundColor Gray
Write-Host "    • 22 skills (11 AI Maker + 11 AI Workbench)" -ForegroundColor Gray
Write-Host "    • Git-backed workspace at: $($script:AIMakerConfig.WorkspacePath)" -ForegroundColor Gray
Write-Host "    • Private GitHub repo: https://github.com/$ghUser/$RepoName" -ForegroundColor Gray
Write-Host "    • Agency + WorkIQ/M365 integration" -ForegroundColor Gray
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1. The Copilot App is launching..." -ForegroundColor Gray
Write-Host "  2. Add this folder as a project:" -ForegroundColor Gray
Write-Host "     $($script:AIMakerConfig.WorkspacePath)" -ForegroundColor Cyan
Write-Host "  3. Start chatting — all 22 skills are active" -ForegroundColor Gray
Write-Host "  4. Your vault syncs to GitHub automatically with:" -ForegroundColor Gray
Write-Host "     git add -A && git commit -m 'vault update' && git push" -ForegroundColor Cyan
Write-Host ""

# Launch via agency (preferred) or direct app exe
if (-not $WhatIf) {
    if ($agency) {
        Start-Process -FilePath $agency -ArgumentList 'gh-app'
    } else {
        $appExe = Join-Path $env:LOCALAPPDATA "Programs\GitHub Copilot\GitHub Copilot.exe"
        if (Test-Path $appExe) { Start-Process $appExe }
    }
}

if ($scenario.scenario -match "^legacy") {
    Write-Host "  ─── Migration available ───" -ForegroundColor Yellow
    Write-Host "  You have existing data in C:\AIMaker or C:\AIWorkbench." -ForegroundColor Yellow
    Write-Host "  To copy it to your new workspace:" -ForegroundColor Yellow
    Write-Host "  Run: migrate.ps1" -ForegroundColor Cyan
    Write-Host "  Preview first: migrate.ps1 -WhatIf" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "  On a new machine, restore everything with:" -ForegroundColor Gray
Write-Host "  gh repo clone $RepoName -- ~/GitHub/ai-workspace && .\install-red.ps1 -SkillsOnly" -ForegroundColor Blue
Write-Host ""

