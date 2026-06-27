#Requires -Version 5.1
<#
.SYNOPSIS
    AI Maker v3 — CLI-to-App Migration Script
.DESCRIPTION
    Migrates existing CLI-based AI Maker / AI Workbench installations to the new
    App-first model. Copy-first approach: data is copied (never moved or deleted).
    Legacy folders are preserved. User confirmation required before any data copy.
.PARAMETER WhatIf
    Preview all changes without executing.
.PARAMETER Doctor
    Run health check diagnostics.
.PARAMETER SkillsSource
    Path to skills source directory (default: downloads from release).
.PARAMETER Force
    Skip confirmation prompts (for automation/testing).
.PARAMETER MarkLegacy
    After successful migration, write .ai-maker-migrated.json in legacy folders.
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Doctor,
    [string]$SkillsSource,
    [switch]$Force,
    [switch]$MarkLegacy
)

$ErrorActionPreference = "Stop"

# ═══════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════

function Show-Banner {
    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Magenta
    Write-Host "  |     AI Maker v3 - Migration Tool         |" -ForegroundColor Magenta
    Write-Host "  |   CLI-to-App: copy-first, safe, simple   |" -ForegroundColor Magenta
    Write-Host "  +------------------------------------------+" -ForegroundColor Magenta
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
# LOAD LIBRARY
# ═══════════════════════════════════════════════════════════════

$libPath = Join-Path $PSScriptRoot "ai-maker-lib.ps1"
if (-not (Test-Path $libPath)) {
    $libUrl = "https://github.com/marcusash/ai-maker/releases/download/v3.0.12/ai-maker-lib.ps1"
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
    Write-Host "  -- DRY RUN MODE -- Nothing will be modified.`n" -ForegroundColor Cyan
}

# ═══════════════════════════════════════════════════════════════
# STEP 1: DETECT EXISTING STATE
# ═══════════════════════════════════════════════════════════════

Write-Host "Step 1: Detecting existing installations..." -ForegroundColor White

$scenario = Get-InstallScenario
Write-Host "  Scenario: $($scenario.scenario)" -ForegroundColor Gray
Write-Host "  Action: $($scenario.action)" -ForegroundColor Gray

$state = $scenario.details

# Validate this is a migration scenario
$migrationScenarios = @(
    "legacy-maker-blue",
    "legacy-maker-red",
    "legacy-workbench-only",
    "returning-user-legacy"
)

if ($scenario.scenario -notin $migrationScenarios) {
    if ($scenario.scenario -eq "fresh-install") {
        Write-Host "`n  No existing CLI installation found." -ForegroundColor Yellow
        Write-Host "  Nothing to migrate. Run install-blue.ps1 or install-red.ps1 for a fresh install." -ForegroundColor Yellow
        return
    }
    elseif ($scenario.scenario -eq "rerun" -or $scenario.scenario -eq "stale-skills") {
        Write-Host "`n  You're already on the App-first model." -ForegroundColor Green
        Write-Host "  No migration needed. Run install-red.ps1 -SkillsOnly to update skills." -ForegroundColor Gray
        return
    }
    elseif ($scenario.scenario -eq "remote-conflict" -or $scenario.scenario -eq "remote-unrelated") {
        Write-Host "`n  ✗ CONFLICT: 'ai-workspace' repo exists on GitHub but wasn't created by this installer." -ForegroundColor Red
        Write-Host "  Rename the existing repo on GitHub before migrating." -ForegroundColor Yellow
        return
    }
    else {
        Write-Host "`n  Scenario '$($scenario.scenario)' is not a migration scenario." -ForegroundColor Yellow
        Write-Host "  This tool handles CLI-to-App migration. Use install-blue.ps1 or install-red.ps1 instead." -ForegroundColor Yellow
        return
    }
}

# ═══════════════════════════════════════════════════════════════
# STEP 2: PREREQUISITES
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 2: Checking prerequisites..." -ForegroundColor White

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
    return
}
Write-Host "  ✓ winget available" -ForegroundColor Green

# Disk space
$diskCheck = Get-DiskSpaceCheck
if (-not $diskCheck.ok) {
    Write-Host "  ✗ $($diskCheck.message)" -ForegroundColor Red
    return
}
Write-Host "  ✓ Disk space OK" -ForegroundColor Green

# Determine migration type
$isRedMigration = ($scenario.scenario -eq "legacy-maker-red") -or
                  ($scenario.scenario -eq "legacy-workbench-only") -or
                  ($scenario.scenario -eq "returning-user-legacy") -or
                  $state.hasLegacyGit

$pillTarget = if ($isRedMigration) { "red" } else { "blue" }

Write-Host "  Migration target: $($pillTarget.ToUpper()) Pill" -ForegroundColor $(if ($isRedMigration) { "Red" } else { "Blue" })

# ═══════════════════════════════════════════════════════════════
# STEP 3: INVENTORY & SUMMARY
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 3: Taking inventory..." -ForegroundColor White

$inventory = @{
    makerVault      = $null
    workbenchVault  = $null
    makerInstructions = $null
    workbenchInstructions = $null
    legacyFiles     = @()
}

# Maker vault
$makerVaultPath = Join-Path $script:AIMakerConfig.LegacyMakerPath "vault"
if (Test-Path $makerVaultPath) {
    $makerFiles = Get-ChildItem $makerVaultPath -Recurse -File -EA Silent
    $makerSize = ($makerFiles | Measure-Object -Sum Length).Sum
    $inventory.makerVault = @{ path = $makerVaultPath; files = $makerFiles.Count; size = $makerSize }
    Write-Host "  Found: Maker vault ($($makerFiles.Count) files, $([math]::Round($makerSize/1KB,1))KB)" -ForegroundColor Gray
}

# Workbench vault
$workbenchVaultPath = Join-Path $script:AIMakerConfig.LegacyWorkbenchPath "vault"
if (Test-Path $workbenchVaultPath) {
    $wbFiles = Get-ChildItem $workbenchVaultPath -Recurse -File -EA Silent
    $wbSize = ($wbFiles | Measure-Object -Sum Length).Sum
    $inventory.workbenchVault = @{ path = $workbenchVaultPath; files = $wbFiles.Count; size = $wbSize }
    Write-Host "  Found: Workbench vault ($($wbFiles.Count) files, $([math]::Round($wbSize/1KB,1))KB)" -ForegroundColor Gray
}

# Copilot-instructions.md (both)
$makerInstrPath = Join-Path $script:AIMakerConfig.LegacyMakerPath ".github\copilot-instructions.md"
if (Test-Path $makerInstrPath) {
    $modified = Test-CopilotInstructionsModified -Path $makerInstrPath
    $inventory.makerInstructions = @{ path = $makerInstrPath; modified = $modified }
    $status = if ($modified) { "MODIFIED (will preserve)" } else { "stock (will replace with v3)" }
    Write-Host "  Found: Maker copilot-instructions.md — $status" -ForegroundColor Gray
}

$wbInstrPath = Join-Path $script:AIMakerConfig.LegacyWorkbenchPath ".github\copilot-instructions.md"
if (Test-Path $wbInstrPath) {
    $modified = Test-CopilotInstructionsModified -Path $wbInstrPath
    $inventory.workbenchInstructions = @{ path = $wbInstrPath; modified = $modified }
    $status = if ($modified) { "MODIFIED (will preserve)" } else { "stock (will replace with v3)" }
    Write-Host "  Found: Workbench copilot-instructions.md — $status" -ForegroundColor Gray
}

# Other user-created files in legacy paths
foreach ($legacyPath in @($script:AIMakerConfig.LegacyMakerPath, $script:AIMakerConfig.LegacyWorkbenchPath)) {
    if (Test-Path $legacyPath) {
        $userFiles = Get-ChildItem $legacyPath -File -EA Silent |
            Where-Object { $_.Name -notin @(".ai-maker-migrated.json", ".gitignore") }
        foreach ($f in $userFiles) {
            $inventory.legacyFiles += @{ path = $f.FullName; name = $f.Name; source = (Split-Path $legacyPath -Leaf) }
        }
    }
}

if ($inventory.legacyFiles.Count -gt 0) {
    Write-Host "  Found: $($inventory.legacyFiles.Count) additional file(s) in legacy folders" -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════
# STEP 4: MIGRATION PLAN (CONFIRM)
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 4: Migration plan..." -ForegroundColor White

$ws = $script:AIMakerConfig.WorkspacePath

Write-Host ""
Write-Host "  What will be COPIED (originals are never touched):" -ForegroundColor White
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor Gray

if ($inventory.makerVault) {
    Write-Host "    $($inventory.makerVault.path)  -->  $ws\vault\maker\" -ForegroundColor Gray
}
if ($inventory.workbenchVault) {
    Write-Host "    $($inventory.workbenchVault.path)  -->  $ws\vault\workbench\" -ForegroundColor Gray
}
if ($inventory.makerInstructions -and $inventory.makerInstructions.modified) {
    Write-Host "    $($inventory.makerInstructions.path)  -->  $ws\.github\copilot-instructions.user.md" -ForegroundColor Gray
}
if ($inventory.workbenchInstructions -and $inventory.workbenchInstructions.modified) {
    Write-Host "    $($inventory.workbenchInstructions.path)  -->  $ws\.github\workbench-instructions.user.md" -ForegroundColor Gray
}
if ($inventory.legacyFiles.Count -gt 0) {
    Write-Host "    Additional files  -->  $ws\legacy\" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  What will be INSTALLED:" -ForegroundColor White
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor Gray
$skillCountLabel = if ($isRedMigration) { "22 (all)" } else { "11 (AI Maker)" }
Write-Host "    Skills: $skillCountLabel to ~/.copilot/skills/" -ForegroundColor Gray
Write-Host "    Copilot App (if not installed)" -ForegroundColor Gray
if ($isRedMigration) {
    Write-Host "    Git + GitHub CLI + Copilot CLI" -ForegroundColor Gray
    Write-Host "    GitHub repo: {your-username}/ai-workspace (private)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  What will NOT be changed:" -ForegroundColor White
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host "    $($script:AIMakerConfig.LegacyMakerPath) — left as-is" -ForegroundColor Gray
Write-Host "    $($script:AIMakerConfig.LegacyWorkbenchPath) — left as-is" -ForegroundColor Gray
if ($state.hasLegacyRemote) {
    Write-Host "    GitHub repo: pc-setup — left as-is" -ForegroundColor Gray
}

Write-Host ""

if (-not $Force -and -not $WhatIf) {
    $confirm = Read-Host "  Proceed with migration? [Y/n]"
    if ($confirm -and $confirm -notmatch "^[Yy]") {
        Write-Host "`n  Migration cancelled." -ForegroundColor Yellow
        return
    }
}

# ═══════════════════════════════════════════════════════════════
# STEP 5: INSTALL COPILOT APP
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 5: Ensuring Copilot App is installed..." -ForegroundColor White

$appInstalled = (winget list --id GitHub.CopilotApp --accept-source-agreements 2>$null) -match "GitHub.CopilotApp"
if ($appInstalled) {
    Write-Host "  ✓ Copilot App already installed" -ForegroundColor Green
}
else {
    Invoke-TxOp -Operation "WINGET_INSTALL" -Description "Install GitHub Copilot App" `
        -Path "GitHub.CopilotApp" -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
        winget install GitHub.CopilotApp --accept-source-agreements --accept-package-agreements --silent
        if ($LASTEXITCODE -ne 0) { throw "winget install failed for GitHub.CopilotApp (exit: $LASTEXITCODE)" }
    }
    Write-Host "  ✓ Copilot App installed" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# STEP 6: INSTALL DEV TOOLS (Red migration only)
# ═══════════════════════════════════════════════════════════════

if ($isRedMigration) {
    Write-Host "`nStep 6: Installing developer tools..." -ForegroundColor White

    # Git
    $hasGit = (Get-Command git -EA Silent) -ne $null
    if ($hasGit) {
        Write-Host "  ✓ Git already installed" -ForegroundColor Green
    }
    else {
        Invoke-TxOp -Operation "WINGET_INSTALL" -Description "Install Git" `
            -Path "Git.Git" -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
            winget install Git.Git --accept-source-agreements --accept-package-agreements --silent
            if ($LASTEXITCODE -ne 0) { throw "winget install failed for Git.Git (exit: $LASTEXITCODE)" }
        }
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        Write-Host "  ✓ Git installed" -ForegroundColor Green
    }

    # GitHub CLI
    $hasGh = (Get-Command gh -EA Silent) -ne $null
    if ($hasGh) {
        Write-Host "  ✓ GitHub CLI already installed" -ForegroundColor Green
    }
    else {
        Invoke-TxOp -Operation "WINGET_INSTALL" -Description "Install GitHub CLI" `
            -Path "GitHub.cli" -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
            winget install GitHub.cli --accept-source-agreements --accept-package-agreements --silent
            if ($LASTEXITCODE -ne 0) { throw "winget install failed for GitHub.cli (exit: $LASTEXITCODE)" }
        }
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        Write-Host "  ✓ GitHub CLI installed" -ForegroundColor Green
    }

    # Copilot CLI extension
    $hasCopilotExt = (gh extension list 2>$null) -match "copilot"
    if ($hasCopilotExt) {
        Write-Host "  ✓ Copilot CLI extension already installed" -ForegroundColor Green
    }
    else {
        Invoke-TxOp -Operation "GH_EXTENSION_INSTALL" -Description "Install Copilot CLI extension" `
            -Path "github/gh-copilot" -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            gh extension install github/gh-copilot 2>$null
        }
        Write-Host "  ✓ Copilot CLI extension installed" -ForegroundColor Green
    }

    # GitHub auth
    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ⚠ Not authenticated with GitHub." -ForegroundColor Yellow
        if (-not $WhatIf) {
            gh auth login --web --git-protocol https
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  ✗ Authentication failed. Run 'gh auth login' manually and retry." -ForegroundColor Red
                return
            }
        }
        else {
            Write-Host "  [WhatIf] Would run gh auth login" -ForegroundColor Cyan
        }
    }

    $ghUser = (gh api user --jq .login 2>$null)
    if (-not $ghUser -and -not $WhatIf) {
        Write-Host "  ✗ Could not determine GitHub username." -ForegroundColor Red
        return
    }
    if ($ghUser) { Write-Host "  ✓ Authenticated as: $ghUser" -ForegroundColor Green }
}
else {
    Write-Host "`nStep 6: Skipped (Blue Pill — no dev tools needed)" -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════
# STEP 7: INSTALL SKILLS
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 7: Installing skills..." -ForegroundColor White

# Auto-detect local skills folder
if (-not $SkillsSource) {
    $localSkills = Join-Path $PSScriptRoot "skills"
    if (Test-Path $localSkills) {
        $SkillsSource = $localSkills
        Write-Host "  Using local skills folder" -ForegroundColor Gray
    }
    else {
        $releaseUrl = "https://github.com/marcusash/ai-maker/releases/download/v3.0.12/skills.zip"
        $zipPath = Join-Path $env:TEMP "ai-maker-skills.zip"
        $extractPath = Join-Path $env:TEMP "ai-maker-skills"

        if (-not $WhatIf) {
            Write-Host "  Downloading skills..." -ForegroundColor Gray
            Invoke-RestMethod -Uri $releaseUrl -OutFile $zipPath
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            $SkillsSource = Join-Path $extractPath "skills"
        }
        else {
            Write-Host "  [WhatIf] Would download skills from $releaseUrl" -ForegroundColor Cyan
            $SkillsSource = "DOWNLOAD"
        }
    }
}

if (-not $WhatIf) {
    $existingManifest = Read-AIMakerManifest
    $installedSkills = Install-Skills -Pill $pillTarget -SourcePath $SkillsSource -Manifest $existingManifest -WhatIf:$WhatIf
    Write-Host "  ✓ $($installedSkills.Count) skills installed" -ForegroundColor Green
}
else {
    Write-Host "  [WhatIf] Would install skills ($skillCountLabel) to ~/.copilot/skills/" -ForegroundColor Cyan
    $installedSkills = @()
}

# ═══════════════════════════════════════════════════════════════
# STEP 8: CREATE WORKSPACE & COPY DATA
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 8: Creating workspace and copying data..." -ForegroundColor White

# Create scaffold (idempotent)
New-WorkspaceScaffold -WhatIf:$WhatIf
Write-Host "  ✓ Workspace scaffold ready" -ForegroundColor Green

# Copy vault data
Write-Host "  Copying vault data..." -ForegroundColor Gray
Copy-VaultData -WhatIf:$WhatIf

if ($inventory.makerVault) {
    Write-Host "  ✓ Maker vault copied to vault\maker\" -ForegroundColor Green
}
if ($inventory.workbenchVault) {
    Write-Host "  ✓ Workbench vault copied to vault\workbench\" -ForegroundColor Green
}

# Handle copilot-instructions.md
$instructionsDest = Join-Path $ws ".github\copilot-instructions.md"

if ($inventory.makerInstructions -and $inventory.makerInstructions.modified) {
    # User customized it — preserve as .user.md
    $userDest = Join-Path $ws ".github\copilot-instructions.user.md"
    Invoke-TxOp -Operation "COPY" -Description "Preserve user-modified Maker instructions" `
        -Path $userDest -From $inventory.makerInstructions.path -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
        Copy-Item $inventory.makerInstructions.path $userDest -Force
    }
    Write-Host "  ✓ User-modified instructions preserved as copilot-instructions.user.md" -ForegroundColor Green
}

if ($inventory.workbenchInstructions -and $inventory.workbenchInstructions.modified) {
    $userDest = Join-Path $ws ".github\workbench-instructions.user.md"
    Invoke-TxOp -Operation "COPY" -Description "Preserve user-modified Workbench instructions" `
        -Path $userDest -From $inventory.workbenchInstructions.path -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
        Copy-Item $inventory.workbenchInstructions.path $userDest -Force
    }
    Write-Host "  ✓ User-modified Workbench instructions preserved" -ForegroundColor Green
}

# Copy additional user files to legacy/ subfolder
if ($inventory.legacyFiles.Count -gt 0) {
    $legacyDest = Join-Path $ws "legacy"
    if (-not (Test-Path $legacyDest)) {
        Invoke-TxOp -Operation "CREATE_DIR" -Description "Create legacy folder" `
            -Path $legacyDest -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            New-Item -Path $legacyDest -ItemType Directory -Force | Out-Null
        }
    }

    foreach ($file in $inventory.legacyFiles) {
        $dest = Join-Path $legacyDest "$($file.source)_$($file.name)"
        Invoke-TxOp -Operation "COPY" -Description "Copy legacy file: $($file.name)" `
            -Path $dest -From $file.path -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            Copy-Item $file.path $dest -Force
        }
    }
    Write-Host "  ✓ $($inventory.legacyFiles.Count) additional file(s) copied to legacy\" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# STEP 9: GIT SETUP (Red migration only)
# ═══════════════════════════════════════════════════════════════

if ($isRedMigration) {
    Write-Host "`nStep 9: Setting up git repository..." -ForegroundColor White

    $gitDir = Join-Path $ws ".git"

    # git init
    if (Test-Path $gitDir) {
        Write-Host "  ✓ Git already initialized" -ForegroundColor Green
    }
    else {
        Invoke-TxOp -Operation "GIT_INIT" -Description "Initialize git repository" `
            -Path $ws -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            Push-Location $ws
            git init --initial-branch=main 2>$null
            git config user.name $ghUser
            git config user.email "$ghUser@users.noreply.github.com"
            Pop-Location
        }
        Write-Host "  ✓ Git initialized (branch: main)" -ForegroundColor Green
    }

    # Create/validate remote
    $repoName = "ai-workspace"
    if (-not $WhatIf) {
        $repoExists = $null -ne (gh repo view "$ghUser/$repoName" --json name 2>$null)
        if ($repoExists) {
            Write-Host "  ✓ Remote repo exists" -ForegroundColor Green
        }
        else {
            Invoke-TxOp -Operation "GH_REPO_CREATE" -Description "Create private GitHub repo: $ghUser/$repoName" `
                -Path "$ghUser/$repoName" -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
                gh repo create $repoName --private --description "AI Maker v3 workspace — migrated from CLI"
                if ($LASTEXITCODE -ne 0) { throw "gh repo create failed (exit: $LASTEXITCODE)" }
            }
            Write-Host "  ✓ Created private repo: $ghUser/$repoName" -ForegroundColor Green
        }

        # Set remote
        Push-Location $ws
        $existingRemote = git remote get-url origin 2>$null
        if (-not $existingRemote) {
            git remote add origin "https://github.com/$ghUser/$repoName.git"
            Write-Host "  ✓ Remote 'origin' set" -ForegroundColor Green
        }
        Pop-Location
    }
    else {
        Write-Host "  [WhatIf] Would create repo and set remote" -ForegroundColor Cyan
    }

    # Commit + push
    if (-not $WhatIf) {
        Push-Location $ws
        git add -A 2>$null
        $status = git status --porcelain 2>$null
        if ($status) {
            Invoke-TxOp -Operation "GIT_COMMIT" -Description "Migration commit" `
                -Path $ws -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
                git commit -m "AI Maker v3 — migrated from CLI (vault + config preserved)" 2>$null
                if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
            }
            Write-Host "  ✓ Committed" -ForegroundColor Green

            Invoke-TxOp -Operation "GIT_PUSH" -Description "Push to GitHub" `
                -Path "$ghUser/$repoName" -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
                git push -u origin main 2>$null
                if ($LASTEXITCODE -ne 0) { throw "git push failed (exit: $LASTEXITCODE)" }
            }
            Write-Host "  ✓ Pushed to GitHub" -ForegroundColor Green
        }
        else {
            Write-Host "  ✓ No changes to commit" -ForegroundColor Green
        }
        Pop-Location
    }
    else {
        Write-Host "  [WhatIf] Would commit migrated data and push" -ForegroundColor Cyan
    }
}
else {
    Write-Host "`nStep 9: Skipped (Blue Pill — no git)" -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════
# STEP 10: WRITE MANIFEST
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 10: Writing manifest..." -ForegroundColor White

$manifest = New-AIMakerManifest -Pill $pillTarget -MigratedFrom "cli-v2" -Skills $installedSkills

# Update legacy section
$manifest.legacy.migrated_maker_vault = ($null -ne $inventory.makerVault)
$manifest.legacy.migrated_workbench_vault = ($null -ne $inventory.workbenchVault)
$manifest.legacy.legacy_paths_preserved = $true
$manifest.legacy.original_paths = @($script:AIMakerConfig.LegacyMakerPath, $script:AIMakerConfig.LegacyWorkbenchPath) |
    Where-Object { Test-Path $_ }

Write-AIMakerManifest -Manifest $manifest -WhatIf:$WhatIf
Write-Host "  ✓ Manifest written (migrated_from: cli-v2)" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# STEP 11: MARK LEGACY (OPTIONAL)
# ═══════════════════════════════════════════════════════════════

if ($MarkLegacy -and -not $WhatIf) {
    Write-Host "`nStep 11: Marking legacy folders as migrated..." -ForegroundColor White

    $marker = @{
        migrated_at = (Get-Date -Format "o")
        migrated_to = $ws
        version = "3.0.0"
    } | ConvertTo-Json

    foreach ($legacyPath in @($script:AIMakerConfig.LegacyMakerPath, $script:AIMakerConfig.LegacyWorkbenchPath)) {
        if (Test-Path $legacyPath) {
            $markerPath = Join-Path $legacyPath ".ai-maker-migrated.json"
            Set-Content -Path $markerPath -Value $marker -Encoding utf8
            Write-Host "  ✓ Marked: $legacyPath" -ForegroundColor Green
        }
    }
}
elseif ($MarkLegacy -and $WhatIf) {
    Write-Host "`n  [WhatIf] Would mark legacy folders with .ai-maker-migrated.json" -ForegroundColor Cyan
}
else {
    Write-Host "`nStep 11: Skipped (use -MarkLegacy to mark old folders)" -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |      ✓ Migration complete!               |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  Your data has been copied to:" -ForegroundColor White
Write-Host "    $ws" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Vault locations:" -ForegroundColor White
if ($inventory.makerVault) {
    Write-Host "    vault\maker\   (from C:\AIMaker\vault)" -ForegroundColor Gray
}
if ($inventory.workbenchVault) {
    Write-Host "    vault\workbench\   (from C:\AIWorkbench\vault)" -ForegroundColor Gray
}
if ($inventory.makerInstructions -and $inventory.makerInstructions.modified) {
    Write-Host "    .github\copilot-instructions.user.md (your custom instructions)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "  Original folders UNCHANGED:" -ForegroundColor White
Write-Host "    $($script:AIMakerConfig.LegacyMakerPath) — still there" -ForegroundColor Gray
Write-Host "    $($script:AIMakerConfig.LegacyWorkbenchPath) — still there" -ForegroundColor Gray
Write-Host "    You can delete them manually when you're satisfied." -ForegroundColor Gray
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1. Open the GitHub Copilot App" -ForegroundColor Gray
Write-Host "  2. Add this folder as a project: $ws" -ForegroundColor Gray
Write-Host "  3. Start a new session — your agents will be set up automatically" -ForegroundColor Gray
Write-Host ""

if ($isRedMigration -and $ghUser) {
    Write-Host "  Your GitHub repo: https://github.com/$ghUser/ai-workspace" -ForegroundColor Cyan
    Write-Host ""
}

# Launch App
if (-not $WhatIf) {
    $appPath = (Get-Command "GitHub Copilot" -EA Silent).Source
    if (-not $appPath) {
        $appPath = Join-Path $env:LOCALAPPDATA "Programs\GitHub Copilot\GitHub Copilot.exe"
    }
    if (Test-Path $appPath) {
        Write-Host "  Launching Copilot App..." -ForegroundColor Gray
        Start-Process $appPath
    }
}
