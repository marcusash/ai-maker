#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 — Blue Pill Installer
.DESCRIPTION
    Installs the GitHub Copilot App + 11 AI Maker skills. No git required.
    Target: non-technical managers. Install time: < 5 minutes.
.PARAMETER WhatIf
    Preview all changes without executing.
.PARAMETER Doctor
    Run health check diagnostics.
.PARAMETER SkillsOnly
    Update skills without reinstalling components.
.PARAMETER SkillsSource
    Path to skills source directory (default: downloads from release).
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Doctor,
    [switch]$SkillsOnly,
    [string]$SkillsSource,
    [switch]$SkipAppLaunch
)

$ErrorActionPreference = "Stop"

# ═══════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════

function Show-Banner {
    Write-Host ""
    Write-Host "  +------------------------------------------+" -ForegroundColor Blue
    Write-Host "  |       AI Maker v3 - Blue Pill            |" -ForegroundColor Blue
    Write-Host "  |   Your AI assistant in 5 minutes         |" -ForegroundColor Blue
    Write-Host "  +------------------------------------------+" -ForegroundColor Blue
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
# LOAD LIBRARY
# ═══════════════════════════════════════════════════════════════

$libPath = Join-Path $PSScriptRoot "ai-maker-lib.ps1"
if (-not (Test-Path $libPath)) {
    # If running from irm | iex, download the lib
    $libUrl = "https://github.com/marcusash/ai-maker/releases/download/v3.0.7/ai-maker-lib.ps1"
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

# Disk space
$diskCheck = Get-DiskSpaceCheck
if (-not $diskCheck.ok) {
    Write-Host "  ✗ $($diskCheck.message)" -ForegroundColor Red
    return
}
Write-Host "  ✓ Disk space OK" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# STEP 2: DETECT EXISTING STATE
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 2: Detecting existing setup..." -ForegroundColor White

$scenario = Get-InstallScenario -SkipRemoteChecks
Write-Host "  Scenario: $($scenario.scenario)" -ForegroundColor Gray
Write-Host "  Action: $($scenario.action)" -ForegroundColor Gray

# Handle migration scenarios
if ($scenario.scenario -match "^legacy") {
    Write-Host "`n  ⚠ Existing CLI installation detected." -ForegroundColor Yellow
    Write-Host "  After this install completes, run migrate.ps1 to move your data to the new setup." -ForegroundColor Yellow
    Write-Host "  Your existing files will NOT be touched by this installer.`n" -ForegroundColor Yellow
}

if ($scenario.scenario -eq "partial-install") {
    Write-Host "  ⚠ Previous partial install detected. Resuming..." -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════
# CROSS-PILL GUARD
# ═══════════════════════════════════════════════════════════════

$_guardManifestPath = Join-Path $script:AIMakerConfig.WorkspacePath $script:AIMakerConfig.ManifestFile
if (Test-Path $_guardManifestPath) {
    try {
        $_guardManifest = Get-Content $_guardManifestPath -Raw | ConvertFrom-Json
        if ($_guardManifest.pill -eq "red") {
            Write-Host "[FAIL] This workspace is set up for Red Pill (AI Workbench). Run install-blue with a different -WorkspacePath, or remove the existing workspace first." -ForegroundColor Red
            exit 2
        }
    }
    catch { <# Unreadable manifest: proceed; installer will handle manifest state #> }
}

# ═══════════════════════════════════════════════════════════════
# STEP 3: INSTALL AGENCY (Microsoft's agentic platform)
# Agency installs + launches the Copilot App itself via `agency gh-app`
# in Step 8 — we do NOT install GitHub.CopilotApp via winget separately.
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly) {
    Write-Host "`nStep 3: Installing Agency..." -ForegroundColor White

    $agencyOk = $false
    if (Get-Command agency.exe -EA SilentlyContinue) { $agencyOk = $true }
    elseif (Test-Path $script:AIMakerConfig.AgencyBinaryFallback) { $agencyOk = $true }

    if ($agencyOk) {
        Write-Host "  ✓ Agency already installed" -ForegroundColor Green
    }
    elseif (-not $WhatIf) {
        Write-Host "  → Installing Agency via aka.ms/InstallTool.ps1..." -ForegroundColor Gray
        try {
            $installer = Invoke-RestMethod -Uri "https://aka.ms/InstallTool.ps1" -UseBasicParsing
            Invoke-Expression "& { $installer } agency"
            if (-not (Get-Command agency.exe -EA SilentlyContinue) -and -not (Test-Path $script:AIMakerConfig.AgencyBinaryFallback)) {
                throw "Agency installer completed but agency.exe is not on PATH or at $($script:AIMakerConfig.AgencyBinaryFallback)"
            }
            Write-Host "  ✓ Agency installed" -ForegroundColor Green
        }
        catch {
            throw "Failed to install Agency: $($_.Exception.Message)`n  Manual install: iex `"& { `$(irm aka.ms/InstallTool.ps1) } agency`""
        }
    }
    else { Write-Host "  [WhatIf] Would install Agency via aka.ms/InstallTool.ps1" -ForegroundColor Cyan }

    # 3b. Register Agency MCP servers. Agency exposes M365 through workiq; bluebird is the companion server.
    Write-Host "  → Registering Agency MCP servers (workiq, bluebird)..." -ForegroundColor Gray
    Register-AgencyMcpServers -WhatIf:$WhatIf
    Write-Host "  ✓ Agency MCP servers registered" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# STEP 4: INSTALL SKILLS
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 4: Installing AI Maker skills (11)..." -ForegroundColor White

# Determine skills source
if (-not $SkillsSource) {
    # Check for local skills folder first (e.g., extracted from ZIP)
    $localSkills = Join-Path $PSScriptRoot "skills"
    if (Test-Path $localSkills) {
        $SkillsSource = $localSkills
        Write-Host "  Using local skills from: $localSkills" -ForegroundColor Gray
    }
    else {
        # Download from release
        $releaseUrl = "https://github.com/marcusash/ai-maker/releases/download/v3.0.7/skills.zip"
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
    $installedSkills = Install-Skills -Pill "blue" -SourcePath $SkillsSource -Manifest $existingManifest -WhatIf:$WhatIf

    Write-Host "  ✓ $($installedSkills.Count) skills installed" -ForegroundColor Green
}
else {
    Write-Host "  [WhatIf] Would install 11 ai-maker-* skills to ~/.copilot/skills/" -ForegroundColor Cyan
    $installedSkills = @()
}

# ═══════════════════════════════════════════════════════════════
# STEP 5: CREATE WORKSPACE
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly) {
    Write-Host "`nStep 5: Creating workspace..." -ForegroundColor White

    $wsPath = $script:AIMakerConfig.WorkspacePath
    $manifestCheck = Join-Path $wsPath $script:AIMakerConfig.ManifestFile

    # Always re-run scaffold to repair workspaces from broken prior installs.
    # New-WorkspaceScaffold is idempotent: re-downloads agents, overwrites
    # copilot-instructions.md with correct pill template, verifies marker.
    $instrPath = Join-Path $wsPath ".github\copilot-instructions.md"
    $needsRepair = $false
    if ((Test-Path $wsPath) -and (Test-Path $manifestCheck)) {
        if (-not (Test-Path $instrPath) -or
            -not ((Get-Content $instrPath -Raw -EA SilentlyContinue) -match 'AI Maker Workspace')) {
            Write-Host "  ! Existing workspace has wrong/missing copilot-instructions.md — repairing" -ForegroundColor Yellow
            $needsRepair = $true
        } else {
            Write-Host "  ✓ Workspace exists with correct Blue Pill content at $wsPath" -ForegroundColor Green
        }
    }
    if (-not (Test-Path $wsPath) -or -not (Test-Path $manifestCheck) -or $needsRepair) {
        New-WorkspaceScaffold -Pill "blue" -WhatIf:$WhatIf
        if (-not $WhatIf) {
            if (-not (Test-Path $wsPath)) {
                Write-Host "  ✗ Workspace folder was not created. See error above." -ForegroundColor Red
                throw "Workspace scaffold failed — $wsPath not present after New-WorkspaceScaffold"
            }
            Write-Host "  ✓ Workspace created/repaired at $wsPath" -ForegroundColor Green
        }
        else {
            Write-Host "  [WhatIf] Would create workspace at $wsPath" -ForegroundColor Cyan
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# STEP 6: WRITE MANIFEST
# ═══════════════════════════════════════════════════════════════

Write-Host "`nStep 6: Writing manifest..." -ForegroundColor White

$manifest = New-AIMakerManifest -Pill "blue" -Skills $installedSkills
Write-AIMakerManifest -Manifest $manifest -WhatIf:$WhatIf

Write-Host "  ✓ Manifest written" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# STEP 7: LAUNCH COPILOT APP via `agency gh-app`
# This installs the GitHub Copilot App (from GitHub releases) on first run
# and launches it with Agency mode enabled. Agency owns Entra auth;
# Step 3b registers workiq + bluebird for Copilot App MCP discovery.
# ═══════════════════════════════════════════════════════════════

if (-not $SkipAppLaunch) {
    Write-Host "`nStep 7: Launching Copilot App in Agency mode..." -ForegroundColor White
    Invoke-AgencyGhApp -WhatIf:$WhatIf
}

# ═══════════════════════════════════════════════════════════════
# STEP 9: CLEANUP + INSTRUCTIONS
# ═══════════════════════════════════════════════════════════════

# Clean up temp files
if (-not $WhatIf) {
    Remove-Item (Join-Path $env:TEMP "ai-maker-skills.zip") -EA Silent
    Remove-Item (Join-Path $env:TEMP "ai-maker-skills") -Recurse -EA Silent
    Remove-Item (Join-Path $env:TEMP "ai-maker-agents.zip") -EA Silent
    Remove-Item (Join-Path $env:TEMP "ai-maker-agents") -Recurse -EA Silent
}

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |       Installation complete!             |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  Add C:\GitHub\ai-workspace as a project in the Copilot App." -ForegroundColor Gray
Write-Host "  Open a new session and say anything — AI Maker agents will activate." -ForegroundColor Gray
Write-Host ""

if ($scenario.scenario -match "^legacy") {
    Write-Host "  ─── Migration available ───" -ForegroundColor Yellow
    Write-Host "  You have an existing CLI setup. To migrate your vault and settings:" -ForegroundColor Yellow
    Write-Host "  Run: migrate.ps1" -ForegroundColor Cyan
    Write-Host "  Preview first: migrate.ps1 -WhatIf" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "  Want GitHub backup? Upgrade to Red Pill:" -ForegroundColor Gray
Write-Host "  irm https://github.com/marcusash/ai-maker/releases/download/v3.0.7/install-red.ps1 | iex" -ForegroundColor Blue
Write-Host ""
