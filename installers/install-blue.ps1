#Requires -Version 5.1
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
    [string]$SkillsSource
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
# STEP 3: INSTALL COPILOT APP
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly) {
    Write-Host "`nStep 3: Installing GitHub Copilot App..." -ForegroundColor White

    $appInstalled = (winget list --id GitHub.CopilotApp --accept-source-agreements 2>$null) -match "GitHub.CopilotApp"

    if ($appInstalled) {
        Write-Host "  ✓ Already installed" -ForegroundColor Green
    }
    else {
        Invoke-TxOp -Operation "WINGET_INSTALL" -Description "Install GitHub Copilot App" `
            -Path "GitHub.CopilotApp" -Reversible $false -WhatIf:$WhatIf -ScriptBlock {
            winget install GitHub.CopilotApp --accept-source-agreements --accept-package-agreements --silent
            if ($LASTEXITCODE -ne 0) { throw "winget install failed for GitHub.CopilotApp (exit: $LASTEXITCODE)" }
        }
        Write-Host "  ✓ Copilot App installed" -ForegroundColor Green
    }
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

    if (Test-Path (Join-Path $script:AIMakerConfig.WorkspacePath $script:AIMakerConfig.ManifestFile)) {
        Write-Host "  ✓ Workspace already exists" -ForegroundColor Green
        # Repair any issues from prior installs (idempotent)
        Repair-WorkspaceAssets -Pill "blue" -WhatIf:$WhatIf
    }
    else {
        New-WorkspaceScaffold -Pill "blue" -WhatIf:$WhatIf
        Write-Host "  ✓ Workspace created at $($script:AIMakerConfig.WorkspacePath)" -ForegroundColor Green
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
# STEP 7: INSTALL AGENCY + REGISTER MCP SERVERS
# ═══════════════════════════════════════════════════════════════

if (-not $SkillsOnly -and -not $WhatIf) {
    Write-Host "`nStep 7: Setting up Agency (M365 integration)..." -ForegroundColor White

    # Resolve agency.exe
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

        # Write MCP config (workiq + bluebird)
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
    } else {
        Write-Host "  ⚠ Agency not available — WorkIQ/M365 features will not work until Agency is installed" -ForegroundColor Yellow
        Write-Host "    Run fix-workiq.ps1 later to set up M365 integration" -ForegroundColor Gray
    }
}
elseif ($WhatIf) {
    Write-Host "`nStep 7: [WhatIf] Would install Agency and register MCP servers (workiq + bluebird)" -ForegroundColor Cyan
}

# ═══════════════════════════════════════════════════════════════
# STEP 8: CLEANUP + LAUNCH
# ═══════════════════════════════════════════════════════════════

# Clean up temp files
if (-not $WhatIf) {
    Remove-Item (Join-Path $env:TEMP "ai-maker-skills.zip") -EA Silent
    Remove-Item (Join-Path $env:TEMP "ai-maker-skills") -Recurse -EA Silent
}

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |       Installation complete!             |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  Opening the Copilot App..." -ForegroundColor White
Write-Host "  When it opens, add C:\GitHub\ai-workspace as a project." -ForegroundColor Gray
Write-Host "  Then open a new session and say anything — it will" -ForegroundColor Gray
Write-Host "  automatically create your AI Maker agent." -ForegroundColor Gray
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
    Write-Host "  You have an existing CLI setup. To migrate your vault and settings:" -ForegroundColor Yellow
    Write-Host "  Run: migrate.ps1" -ForegroundColor Cyan
    Write-Host "  Preview first: migrate.ps1 -WhatIf" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "  Want GitHub backup? Upgrade to Red Pill:" -ForegroundColor Gray
Write-Host "  irm https://github.com/marcusash/ai-maker/releases/download/v3.0.12/install-red.ps1 | iex" -ForegroundColor Blue
Write-Host ""

