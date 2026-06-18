#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 — Core library module
.DESCRIPTION
    Shared functions for install-blue.ps1, install-red.ps1, and migrate.ps1.
    Covers: manifest management, detection matrix, transaction log, scaffold creation.
    Requires PowerShell 7+ (install.bat bootstraps pwsh via winget if not present).
.VERSION
    3.0.10
#>

# ═══════════════════════════════════════════════════════════════
# §1. CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:AIMakerConfig = @{
    Version          = "3.0.10"
    ManifestFile     = ".ai-maker-manifest.json"
    SchemaVersion    = 1
    SkillsPath       = Join-Path $env:USERPROFILE ".copilot\skills"
    WorkspacePath    = "C:\GitHub\ai-workspace"
    LogPath          = Join-Path $env:USERPROFILE ".copilot\ai-maker\install-log.jsonl"
    TempLogPath      = Join-Path $env:TEMP "ai-maker-install.log"
    LegacyMakerPath  = "C:\AIMaker"
    LegacyWorkbenchPath = "C:\AIWorkbench"
    MakerSkillPrefix = "ai-maker-"
    WorkbenchSkillPrefix = "ai-workbench-"
    MakerSkillCount  = 11
    WorkbenchSkillCount = 11
    TotalSkillCount  = 22
    AgentsZipUrl     = "https://github.com/marcusash/ai-maker/releases/download/v3.0.10/agents.zip"
    McpConfigPath    = Join-Path $env:USERPROFILE ".copilot\m-mcp-servers.json"
    AgencyBinaryFallback = Join-Path $env:APPDATA "agency\CurrentVersion\agency.exe"
}

# Known stock hashes for copilot-instructions.md (all previous versions)
$script:KnownStockHashes = @(
    # v3.0.0 — generic stock template (matches Get-StockCopilotInstructionsContent output, LF-normalized)
    "4271d7bf4bf837e9478e16ae8e967f8b690875a14f6541231728d21faf13f877"
    # v3.0.0-v3.0.10 - neutral copilot-instructions.md (unchanged across all releases)
    "bc33ef17b2e320d2b4ae6d6aa38d6913de9b5cb4d259b1ac5e6a1d01918b8a1e"
    # v3.0.1 — Blue Pill (AI Maker only)
    "910f72a6cf3f0bde5a7c118be8bf7954491b6206b66029255a8f7ea8894189e6"
    # v3.0.1 — Red Pill (AI Maker + AI Workbench)
    "280b85a55dbcbd5e87432113aab3c2a934c3b98fbaf2edd130626bb3718b26b8"
    # v3.0.3 — Blue Pill
    "660f474cc0639963080866f2286f065fe15ed28f19ac6f57fc61758c9b3b0eff"
    # v3.0.3 — Red Pill
    "dae81725a279f781482ee31965f8cf2f6047affc87e1ecd9f630133c7ddfb744"
    # v3.0.4-v3.0.10 - Blue Pill (greeting cleanup; content identical across these releases)
    "a94ad044e9ab9c3cc64c224df130c3fc49a2e7da80c180131ef604b0c3f2e4af"
    # v3.0.4-v3.0.10 - Red Pill (greeting cleanup; content identical across these releases)
    "896e80629dd939543c58bb447b5ed2055bf7e4854074dadbfaf6a324b49623e6"
    # NOTE: Pre-v3 instructions have no archived hashes. Users with custom pre-v3 files
    # will be detected as "modified" — their content is preserved as .user.md (safe default).
)

function Get-StockCopilotInstructionsContent {
    <#
    .SYNOPSIS
        Returns the canonical v3.0.0 copilot-instructions.md content.
        Single source of truth — lib owns both the hash and the content.
    #>
    [CmdletBinding()]
    param()

    return @'
# AI Workspace

This project has two AI agents: **AI maker** (creative/strategic) and **AI workbench** (technical/engineering). Names are sentence case. Always.

## Bootstrap Protocol

When you are the first session opened in this project and no "AI maker" or "AI workbench" sessions exist yet, execute this automatically WITHOUT asking:

1. Tell the user: "Setting up your AI agents..."

2. Use `create_session` to create a session named **AI maker** (sentence case, exactly: A-I-space-m-a-k-e-r) with kickoff_prompt:
   "Read .github/agents/ai-maker.md and load that identity. You are AI maker — a creative strategist and executive thinking partner. Your VERY FIRST action in this session, before responding to anything, is to call rename_session with title='AI maker' to lock the session name. Then acknowledge briefly and wait for instructions."
   Set kickoff_mode to "autopilot" and coordinate_with_creator to false.

3. Use `create_session` to create a session named **AI workbench** (sentence case, exactly: A-I-space-w-o-r-k-b-e-n-c-h) with kickoff_prompt:
   "Read .github/agents/ai-workbench.md and load that identity. You are AI workbench — a senior engineer and automation specialist. Your VERY FIRST action in this session, before responding to anything, is to call rename_session with title='AI workbench' to lock the session name. Then acknowledge briefly and wait for instructions."
   Set kickoff_mode to "autopilot" and coordinate_with_creator to false.

4. After both sessions are created, **delete this bootstrapping session** using `delete_item` with your own session ID. This promotes the two agent sessions to root level in the sidebar (not nested as children).

5. If you cannot delete yourself, tell the user:
   "Done! Your two agents are ready. Please delete this setup session now — that will move AI maker and AI workbench to the top level of your sidebar."

Do NOT ask for confirmation. Just create them immediately on first load.

**HARD RULE — naming:** Session names are ALWAYS sentence case: "AI maker" and "AI workbench". Never "AI Maker", "AI Workbench", "ai-maker", "AI maker chat", or "Chat". Every agent's first action in any session is to verify the session name is the canonical sentence-case form, and call `rename_session` to fix it if not.

**IMPORTANT**: The agent sessions must appear at root level in the sidebar, not nested under this bootstrapper. Deleting the bootstrapper after creation achieves this.

## Agent Identity Files

| Agent | File | Domain |
|-------|------|--------|
| **AI maker** | `.github/agents/ai-maker.md` | Research, brainstorming, design, data, ops, writing |
| **AI workbench** | `.github/agents/ai-workbench.md` | PowerShell, CI/CD, git, debugging, testing, security |

## Vault

Persistent memory across sessions:
- `vault/maker/` — research, decisions, brand rules, frameworks
- `vault/workbench/` — scripts, templates, configs, debugging notes

## Routing

AI maker handles creative/strategic requests. AI workbench handles technical/engineering requests. If a request is outside your domain, redirect the user to the other session.
'@
}

# ═══════════════════════════════════════════════════════════════
# §2. TRANSACTION LOG
# ═══════════════════════════════════════════════════════════════

function Initialize-TxLog {
    <#
    .SYNOPSIS
        Ensures the transaction log directory exists.
    #>
    $logDir = Split-Path $script:AIMakerConfig.LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
}

function Write-TxEntry {
    <#
    .SYNOPSIS
        Appends an entry to the durable transaction log.
    .PARAMETER Operation
        The operation type (INSTALL_SKILL, CREATE_DIR, COPY, GH_REPO_CREATE, GIT_PUSH, etc.)
    .PARAMETER Path
        The path or target affected.
    .PARAMETER From
        Source path (for COPY operations).
    .PARAMETER Reversible
        Whether this operation can be rolled back.
    .PARAMETER WhatIf
        If true, prints the entry but does not write it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Operation,
        [string]$Path,
        [string]$From,
        [bool]$Reversible = $true,
        [switch]$WhatIf
    )

    $entry = @{
        ts         = (Get-Date -Format "o")
        op         = $Operation
        path       = $Path
        reversible = $Reversible
    }
    if ($From) { $entry.from = $From }

    $json = $entry | ConvertTo-Json -Compress

    if ($WhatIf) {
        Write-Host "[WhatIf] $json" -ForegroundColor Cyan
        return
    }

    Initialize-TxLog
    Add-Content -Path $script:AIMakerConfig.LogPath -Value $json -Encoding utf8
    Add-Content -Path $script:AIMakerConfig.TempLogPath -Value $json -Encoding utf8
}

function Invoke-TxOp {
    <#
    .SYNOPSIS
        Executes a destructive operation through the transaction log.
        All installer operations MUST flow through this function.
    .PARAMETER Operation
        Operation type identifier.
    .PARAMETER Description
        Human-readable description for -WhatIf output.
    .PARAMETER Path
        Target path.
    .PARAMETER From
        Source path (for copies).
    .PARAMETER Reversible
        Whether rollback can undo this.
    .PARAMETER ScriptBlock
        The actual operation to execute.
    .PARAMETER WhatIf
        Preview mode — logs but does not execute.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$Description,
        [string]$Path,
        [string]$From,
        [bool]$Reversible = $true,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [switch]$WhatIf
    )

    if ($WhatIf) {
        Write-Host "[WhatIf] $Description" -ForegroundColor Cyan
        Write-TxEntry -Operation $Operation -Path $Path -From $From -Reversible $Reversible -WhatIf
        return
    }

    Write-Host "  → $Description" -ForegroundColor Gray
    Write-TxEntry -Operation $Operation -Path $Path -From $From -Reversible $Reversible

    try {
        & $ScriptBlock
    }
    catch {
        Write-Host "  ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        Write-TxEntry -Operation "FAILED_$Operation" -Path $Path -Reversible $false
        throw
    }
}

function Invoke-Rollback {
    <#
    .SYNOPSIS
        Best-effort rollback of reversible operations from transaction log.
    #>
    [CmdletBinding()]
    param([switch]$WhatIf)

    if (-not (Test-Path $script:AIMakerConfig.LogPath)) {
        Write-Host "No transaction log found. Nothing to roll back." -ForegroundColor Yellow
        return
    }

    $entries = Get-Content $script:AIMakerConfig.LogPath | ForEach-Object { $_ | ConvertFrom-Json }
    $reversible = $entries | Where-Object { $_.reversible -eq $true } | Sort-Object ts -Descending

    Write-Host "`nRollback plan ($($reversible.Count) reversible operations):" -ForegroundColor Yellow

    foreach ($entry in $reversible) {
        switch ($entry.op) {
            "INSTALL_SKILL" {
                $msg = "Remove skill: $($entry.path)"
                if ($WhatIf) { Write-Host "  [WhatIf] $msg" -ForegroundColor Cyan }
                else {
                    Write-Host "  ← $msg"
                    if (Test-Path $entry.path) { Remove-Item $entry.path -Recurse -Force }
                }
            }
            "CREATE_DIR" {
                $msg = "Remove directory: $($entry.path)"
                if ($WhatIf) { Write-Host "  [WhatIf] $msg" -ForegroundColor Cyan }
                else {
                    Write-Host "  ← $msg"
                    if (Test-Path $entry.path) { Remove-Item $entry.path -Recurse -Force }
                }
            }
            "COPY" {
                $msg = "Remove copied file: $($entry.path)"
                if ($WhatIf) { Write-Host "  [WhatIf] $msg" -ForegroundColor Cyan }
                else {
                    Write-Host "  ← $msg"
                    if (Test-Path $entry.path) { Remove-Item $entry.path -Recurse -Force }
                }
            }
            default {
                Write-Host "  ⚠ Cannot reverse: $($entry.op) $($entry.path)" -ForegroundColor Yellow
            }
        }
    }

    if (-not $WhatIf) {
        # Clear the log after successful rollback
        Remove-Item $script:AIMakerConfig.LogPath -Force
        Write-Host "`n✓ Rollback complete." -ForegroundColor Green
    }
}

# ═══════════════════════════════════════════════════════════════
# §3. MANIFEST MANAGEMENT
# ═══════════════════════════════════════════════════════════════

function New-AIMakerManifest {
    <#
    .SYNOPSIS
        Creates a new .ai-maker-manifest.json
    .PARAMETER Pill
        "blue" or "red"
    .PARAMETER MigratedFrom
        Source of migration (e.g., "cli-v2") or $null for fresh install
    .PARAMETER Skills
        Array of skill hashtables with id, version, checksum, installed
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet("blue","red")][string]$Pill,
        [string]$MigratedFrom,
        [array]$Skills = @()
    )

    $manifest = [ordered]@{
        schema            = $script:AIMakerConfig.SchemaVersion
        installer_version = $script:AIMakerConfig.Version
        pill              = $Pill
        installed_at      = (Get-Date -Format "o")
        migrated_from     = $MigratedFrom
        skills            = [ordered]@{
            managed = $Skills
        }
        components        = [ordered]@{
            copilot_app = $true
            copilot_cli = ($Pill -eq "red")
            git         = ($Pill -eq "red")
            gh          = ($Pill -eq "red")
        }
        legacy            = [ordered]@{
            migrated_maker_vault    = $false
            migrated_workbench_vault = $false
            legacy_paths_preserved  = $false
            original_paths          = @()
        }
    }

    return $manifest
}

function Write-AIMakerManifest {
    <#
    .SYNOPSIS
        Writes manifest to the workspace path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Manifest,
        [string]$Path = (Join-Path $script:AIMakerConfig.WorkspacePath $script:AIMakerConfig.ManifestFile),
        [switch]$WhatIf
    )

    $json = $Manifest | ConvertTo-Json -Depth 5

    Invoke-TxOp -Operation "WRITE_MANIFEST" -Description "Write manifest to $Path" `
        -Path $Path -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
        # Snapshot existing manifest for rollback
        if (Test-Path $Path) {
            Copy-Item $Path "$Path.prev" -Force
        }
        Set-Content -Path $Path -Value $json -Encoding utf8
    }
}

function Read-AIMakerManifest {
    <#
    .SYNOPSIS
        Reads and validates manifest from a path.
    .OUTPUTS
        Parsed manifest object, or $null if not found/invalid.
    #>
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $script:AIMakerConfig.WorkspacePath $script:AIMakerConfig.ManifestFile)
    )

    if (-not (Test-Path $Path)) { return $null }

    try {
        # PS5.1-compatible: ConvertFrom-Json -AsHashtable is PS7+ only
        $obj = Get-Content $Path -Raw | ConvertFrom-Json
        $manifest = @{}
        foreach ($prop in $obj.PSObject.Properties) { $manifest[$prop.Name] = $prop.Value }
        if ($manifest.schema -gt $script:AIMakerConfig.SchemaVersion) {
            Write-Warning "Manifest schema v$($manifest.schema) is newer than this installer (v$($script:AIMakerConfig.SchemaVersion)). Upgrade the installer."
        }
        return $manifest
    }
    catch {
        Write-Warning "Failed to parse manifest at ${Path}: $($_.Exception.Message)"
        return $null
    }
}

function Test-AIMakerManifest {
    <#
    .SYNOPSIS
        Validates a manifest object against the schema.
    .OUTPUTS
        Array of validation error strings. Empty = valid.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Manifest)

    $errors = @()

    if (-not $Manifest.ContainsKey("schema")) { $errors += "Missing 'schema' field" }
    if (-not $Manifest.ContainsKey("installer_version")) { $errors += "Missing 'installer_version' field" }
    if (-not $Manifest.ContainsKey("pill")) { $errors += "Missing 'pill' field" }
    elseif ($Manifest.pill -notin @("blue", "red")) { $errors += "Invalid pill value: '$($Manifest.pill)' (must be 'blue' or 'red')" }
    if (-not $Manifest.ContainsKey("installed_at")) { $errors += "Missing 'installed_at' field" }
    if (-not $Manifest.ContainsKey("skills")) { $errors += "Missing 'skills' block" }
    elseif (-not $Manifest.skills.ContainsKey("managed")) { $errors += "Missing 'skills.managed' array" }
    if (-not $Manifest.ContainsKey("components")) { $errors += "Missing 'components' block" }

    return $errors
}

function Get-SkillChecksum {
    <#
    .SYNOPSIS
        Computes SHA-256 hash of a SKILL.md file.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) { return $null }
    $hash = Get-FileHash -Path $Path -Algorithm SHA256
    return $hash.Hash.ToLower()
}

# ═══════════════════════════════════════════════════════════════
# §4. DETECTION MATRIX
# ═══════════════════════════════════════════════════════════════

function Get-InstallScenario {
    <#
    .SYNOPSIS
        Evaluates current system state and returns the detected scenario + recommended action.
    .PARAMETER PathOverrides
        Hashtable for test injection: Workspace, LegacyMaker, LegacyWorkbench, SkillsPath.
        When provided, uses these paths instead of live filesystem checks.
    .PARAMETER RemoteOverrides
        Hashtable for test injection: HasNewRemote, HasLegacyRemote, IsOurRepo.
        When provided, skips live gh calls and uses injected booleans.
    .OUTPUTS
        Hashtable with: scenario (string ID), action (string), details (hashtable of state)
    #>
    [CmdletBinding()]
    param(
        [switch]$SkipRemoteChecks,
        [hashtable]$PathOverrides,
        [hashtable]$RemoteOverrides,
        [hashtable]$McpOverrides
    )

    # Path resolution — use overrides for testability, live checks otherwise
    if ($PathOverrides) {
        $ws = if ($PathOverrides.Workspace)       { $PathOverrides.Workspace }       else { $script:AIMakerConfig.WorkspacePath }
        $lm = if ($PathOverrides.LegacyMaker)     { $PathOverrides.LegacyMaker }     else { $script:AIMakerConfig.LegacyMakerPath }
        $lw = if ($PathOverrides.LegacyWorkbench) { $PathOverrides.LegacyWorkbench } else { $script:AIMakerConfig.LegacyWorkbenchPath }
        $sp = if ($PathOverrides.SkillsPath)      { $PathOverrides.SkillsPath }      else { $script:AIMakerConfig.SkillsPath }
    }
    else {
        $ws = $script:AIMakerConfig.WorkspacePath
        $lm = $script:AIMakerConfig.LegacyMakerPath
        $lw = $script:AIMakerConfig.LegacyWorkbenchPath
        $sp = $script:AIMakerConfig.SkillsPath
    }

    $state = @{
        hasLegacyMaker     = Test-Path (Join-Path $lm ".github")
        hasLegacyWorkbench = Test-Path (Join-Path $lw ".github")
        hasLegacyGit       = Test-Path (Join-Path $lm ".git")
        hasNewWorkspace    = Test-Path (Join-Path $ws $script:AIMakerConfig.ManifestFile)
        hasWorkspaceDir    = Test-Path $ws
        hasLocalGit        = Test-Path (Join-Path $ws ".git")
        hasAppSkills       = ((Get-ChildItem (Join-Path $sp "ai-maker-*") -Directory -EA Silent).Count -ge 1)
        skillCount         = (Get-ChildItem (Join-Path $sp "ai-maker-*") -Directory -EA Silent).Count +
                            (Get-ChildItem (Join-Path $sp "ai-workbench-*") -Directory -EA Silent).Count
    }

    # Remote checks — use injected values or live gh calls
    if ($RemoteOverrides) {
        $state.hasNewRemote  = [bool]$RemoteOverrides.HasNewRemote
        $state.hasLegacyRemote = [bool]$RemoteOverrides.HasLegacyRemote
        $state.remoteIsOurs  = [bool]$RemoteOverrides.IsOurRepo
    }
    elseif (-not $SkipRemoteChecks) {
        $null = gh repo view ai-workspace --json name 2>$null
        $state.hasNewRemote = ($LASTEXITCODE -eq 0)

        $null = gh repo view pc-setup --json name 2>$null
        $state.hasLegacyRemote = ($LASTEXITCODE -eq 0)

        # Repo identity validation
        if ($state.hasNewRemote) {
            $null = gh api "repos/{owner}/ai-workspace/contents/$($script:AIMakerConfig.ManifestFile)" 2>$null
            $state.remoteIsOurs = ($LASTEXITCODE -eq 0)
        }
        else {
            $state.remoteIsOurs = $false
        }
    }

    # MCP registration check — use injected value or live file inspection
    # McpConfigPath = $env:USERPROFILE.copilotm-mcp-servers.json (already in AIMakerConfig)
    # mcpRegistered = $true ONLY when both workiq + bluebird keys present
    if ($McpOverrides) {
        $state.mcpRegistered        = [bool]$McpOverrides.McpRegistered
        $state.mcpRegisteredServers = @($McpOverrides.McpRegisteredServers ?? @())
    }
    else {
        $mcpPath = $script:AIMakerConfig.McpConfigPath
        $state.mcpRegistered        = $false
        $state.mcpRegisteredServers = @()
        if (Test-Path $mcpPath) {
            try {
                $mcpJson = Get-Content $mcpPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
                $servers  = @($mcpJson.Keys)
                if (($servers -contains 'workiq') -and ($servers -contains 'bluebird')) {
                    $state.mcpRegistered        = $true
                    $state.mcpRegisteredServers = $servers
                }
            }
            catch { <# invalid JSON — mcpRegistered stays $false #> }
        }
    }

    # Scenario detection (order matters — most specific first)
    $scenario = if ($state.hasWorkspaceDir -and -not $state.hasNewWorkspace) {
        # Workspace dir exists but no manifest → partial/interrupted install
        @{ scenario = "partial-install"; action = "Resume from transaction log" }
    }
    elseif ($state.hasNewWorkspace -and $state.hasNewRemote -and -not $state.remoteIsOurs) {
        # Both exist but remote isn't ours
        @{ scenario = "remote-conflict"; action = "STOP — ask user: rename local or remote" }
    }
    elseif ($state.hasNewWorkspace -and $state.hasNewRemote -and $state.remoteIsOurs) {
        # Re-run scenario
        if ($state.skillCount -lt $script:AIMakerConfig.TotalSkillCount) {
            @{ scenario = "stale-skills"; action = "Reinstall skills from source" }
        }
        else {
            @{ scenario = "rerun"; action = "Pull latest, upgrade skills" }
        }
    }
    elseif ($state.hasNewWorkspace -and -not $state.hasLocalGit -and -not $state.hasNewRemote) {
        # Blue→Red upgrade
        @{ scenario = "blue-to-red-upgrade"; action = "git init in place, create remote, push" }
    }
    elseif ($state.hasNewWorkspace -and $state.hasLocalGit -and -not $state.hasNewRemote) {
        # Orphan local git
        @{ scenario = "orphan-local-git"; action = "Create remote, push" }
    }
    elseif (-not $state.hasNewWorkspace -and -not $state.hasLegacyMaker -and -not $state.hasLegacyWorkbench) {
        # Nothing local
        if ($state.hasNewRemote -and $state.remoteIsOurs) {
            @{ scenario = "returning-user-new-machine"; action = "Clone + install skills" }
        }
        elseif ($state.hasNewRemote -and -not $state.remoteIsOurs) {
            @{ scenario = "remote-unrelated"; action = "STOP — ask user to rename remote or pick different name" }
        }
        elseif ($state.hasLegacyRemote) {
            @{ scenario = "returning-user-legacy"; action = "Clone legacy, restructure, install skills" }
        }
        else {
            @{ scenario = "fresh-install"; action = "Fresh install (Blue or Red)" }
        }
    }
    elseif ($state.hasLegacyMaker -and -not $state.hasLegacyGit) {
        # Legacy Maker, no git
        @{ scenario = "legacy-maker-blue"; action = "CLI-to-App migration (Blue Pill path)" }
    }
    elseif (-not $state.hasLegacyMaker -and $state.hasLegacyWorkbench) {
        # Workbench only (no Maker) — force Red
        @{ scenario = "legacy-workbench-only"; action = "Force Red Pill path (Workbench users are technical)" }
    }
    elseif ($state.hasLegacyMaker -and $state.hasLegacyGit) {
        # Legacy Maker with git
        @{ scenario = "legacy-maker-red"; action = "CLI-to-App migration (Red Pill) → copy data, create repo" }
    }
    else {
        @{ scenario = "unknown"; action = "Manual intervention required" }
    }

    $scenario.details = $state
    return $scenario
}

# ═══════════════════════════════════════════════════════════════
# §5. SCAFFOLD CREATION
# ═══════════════════════════════════════════════════════════════

function New-WorkspaceScaffold {
    <#
    .SYNOPSIS
        Creates the ai-workspace project folder with vault structure and templates.
        Verbose logging on every step. Fails loudly if workspace is not created.
    .PARAMETER Pill
        "blue" or "red" — selects the pill-specific copilot-instructions.md.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet("blue","red")][string]$Pill,
        [switch]$WhatIf
    )

    $ws = $script:AIMakerConfig.WorkspacePath
    Write-Host "  Workspace target: $ws" -ForegroundColor Gray

    # ── 0. Resolve agents source (needed for both instructions and identity files) ─
    # ALWAYS download fresh from the release to avoid stale extracts from prior runs.
    # Only fall back to local $PSScriptRoot\agents if download fails AND local copy is complete.
    $agentsDir   = Join-Path $ws ".github\agents"
    $localAgentSource = Join-Path $PSScriptRoot "agents"
    $agentSource = $null
    $pillFileName = "copilot-instructions.$Pill.md"

    if (-not $WhatIf) {
        $agentsZip     = Join-Path $env:TEMP "ai-maker-agents.zip"
        $agentsExtract = Join-Path $env:TEMP "ai-maker-agents"

        # Wipe stale extract — Expand-Archive -Force only overwrites matching files,
        # doesn't delete leftover ones, which has bitten us before.
        if (Test-Path $agentsExtract) {
            Remove-Item $agentsExtract -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $agentsZip) {
            Remove-Item $agentsZip -Force -ErrorAction SilentlyContinue
        }

        $downloadOk = $false
        try {
            Write-Host "  Downloading agents.zip from release..." -ForegroundColor Gray
            # Use Invoke-WebRequest (not Invoke-RestMethod) for binary downloads
            $progressPref = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try {
                Invoke-WebRequest -Uri $script:AIMakerConfig.AgentsZipUrl -OutFile $agentsZip -UseBasicParsing -ErrorAction Stop
            } finally {
                $ProgressPreference = $progressPref
            }
            if (-not (Test-Path $agentsZip) -or (Get-Item $agentsZip).Length -lt 100) {
                throw "agents.zip download produced empty or missing file at $agentsZip"
            }
            Write-Host "  ✓ Downloaded $((Get-Item $agentsZip).Length) bytes" -ForegroundColor Green

            Expand-Archive -Path $agentsZip -DestinationPath $agentsExtract -Force -ErrorAction Stop
            $agentSource = $agentsExtract
            $downloadOk = $true
        }
        catch {
            Write-Host "  ⚠ Failed to download/extract agents.zip: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Fallback to local co-located agents/ folder if download failed
        if (-not $downloadOk -and (Test-Path $localAgentSource)) {
            $localPill = Join-Path $localAgentSource $pillFileName
            if (Test-Path $localPill) {
                Write-Host "  Falling back to local agents/ folder: $localAgentSource" -ForegroundColor Gray
                $agentSource = $localAgentSource
            }
        }

        # Verify the pill-specific instructions file is actually present in the agentSource.
        # If not, FAIL LOUDLY — the previous silent stock fallback caused real user bugs.
        if (-not $agentSource) {
            throw "New-WorkspaceScaffold: cannot resolve agents source. agents.zip download failed and no usable local copy exists. Check network or release asset URL: $($script:AIMakerConfig.AgentsZipUrl)"
        }
        $pillFile = Join-Path $agentSource $pillFileName
        if (-not (Test-Path $pillFile)) {
            $present = (Get-ChildItem $agentSource -Filter '*.md' -EA SilentlyContinue | Select-Object -ExpandProperty Name) -join ', '
            throw "New-WorkspaceScaffold: pill-specific template '$pillFileName' missing from agents source at $agentSource (found: $present). The release's agents.zip is malformed."
        }
        Write-Host "  ✓ Verified pill template: $pillFileName" -ForegroundColor Green
    }
    else {
        Write-Host "  [WhatIf] Would download agents.zip and verify $pillFileName" -ForegroundColor Cyan
        $agentSource = $localAgentSource  # for WhatIf path display
    }

    # ── 1. Directory structure ───────────────────────────────────
    # Blue = Maker only (no vault\workbench). Red = both vaults.
    $dirs = @(
        $ws,
        (Join-Path $ws "vault"),
        (Join-Path $ws "vault\maker"),
        (Join-Path $ws ".github"),
        (Join-Path $ws ".github\agents")
    )
    if ($Pill -eq "red") {
        $dirs = @(
            $ws,
            (Join-Path $ws "vault"),
            (Join-Path $ws "vault\maker"),
            (Join-Path $ws "vault\workbench"),
            (Join-Path $ws ".github"),
            (Join-Path $ws ".github\agents")
        )
    }

    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            Write-Host "  ✓ Exists: $dir" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  + Creating: $dir" -ForegroundColor Gray
            Invoke-TxOp -Operation "CREATE_DIR" -Description "Create: $dir" `
                -Path $dir -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
                # $Path is the Invoke-TxOp param — outer $dir is NOT in scope inside this block
                New-Item -Path $Path -ItemType Directory -Force | Out-Null
            }
            if (-not $WhatIf -and -not (Test-Path $dir)) {
                Write-Error "New-WorkspaceScaffold: failed to create directory '$dir'"
                throw "Directory creation failed: $dir"
            }
        }
    }

    # ── 2. copilot-instructions.md ───────────────────────────────
    # ALWAYS overwrite with pill-specific file. We guaranteed it exists above.
    # Previously this skipped if file existed, but a stale stock file from a prior
    # failed install would never be replaced, leaving users with the wrong agent.
    $instructionsPath = Join-Path $ws ".github\copilot-instructions.md"
    $pillInstructions = Join-Path $agentSource $pillFileName
    Write-Host "  + Writing: .github\copilot-instructions.md (from $pillFileName)" -ForegroundColor Gray
    Invoke-TxOp -Operation "CREATE_FILE" -Description "Write copilot-instructions.md ($Pill)" `
        -Path $instructionsPath -From $pillInstructions -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
        Copy-Item $From $Path -Force
    }

    # ── 3. vault/README.md ───────────────────────────────────────
    $vaultReadme = Join-Path $ws "vault\README.md"
    if (Test-Path $vaultReadme) {
        Write-Host "  ✓ Exists: vault\README.md" -ForegroundColor DarkGray
    }
    else {
        Write-Host "  + Writing: vault\README.md" -ForegroundColor Gray
        Invoke-TxOp -Operation "CREATE_FILE" -Description "Write vault/README.md" `
            -Path $vaultReadme -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            Set-Content -Path $Path -Value $script:VaultReadme -Encoding utf8
        }
    }

    # ── 4. .gitignore ────────────────────────────────────────────
    $gitignorePath = Join-Path $ws ".gitignore"
    if (Test-Path $gitignorePath) {
        Write-Host "  ✓ Exists: .gitignore" -ForegroundColor DarkGray
    }
    else {
        Write-Host "  + Writing: .gitignore" -ForegroundColor Gray
        Invoke-TxOp -Operation "CREATE_FILE" -Description "Write .gitignore" `
            -Path $gitignorePath -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            Set-Content -Path $Path -Value $script:GitIgnoreTemplate -Encoding utf8
        }
    }

    # ── 5. Agent identity files ──────────────────────────────────
    # Blue: ai-maker.md only. Red: ai-maker.md + ai-workbench.md.
    # Explicit allow-list keeps copilot-instructions.*.md and legacy copilot-instructions.md out.
    $agentAllowList = if ($Pill -eq "blue") {
        @("ai-maker.md")
    }
    else {
        @("ai-maker.md", "ai-workbench.md")
    }

    if ($agentSource -and (Test-Path $agentSource)) {
        $agentFiles = Get-ChildItem $agentSource -Filter "*.md" -EA Silent |
            Where-Object { $_.Name -in $agentAllowList }
        if ($agentFiles.Count -eq 0) {
            Write-Host "  ⚠ No agent identity *.md files found in: $agentSource" -ForegroundColor Yellow
        }
        foreach ($agentFile in $agentFiles) {
            $dest = Join-Path $agentsDir $agentFile.Name
            if (Test-Path $dest) {
                Write-Host "  ✓ Exists: .github\agents\$($agentFile.Name)" -ForegroundColor DarkGray
            }
            else {
                Write-Host "  + Copying agent: $($agentFile.Name)" -ForegroundColor Gray
                Invoke-TxOp -Operation "CREATE_FILE" -Description "Write agent: $($agentFile.Name)" `
                    -Path $dest -From $agentFile.FullName -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
                    # $Path and $From are Invoke-TxOp params — outer vars not in scope
                    Copy-Item $From $Path -Force
                }
            }
        }
    }

    # ── 6. Final verification ────────────────────────────────────
    if (-not $WhatIf) {
        # Blue = Maker only. Red = Maker + Workbench. Mirror the directory-creation
        # branching above; previously this list hardcoded vault\workbench for both
        # pills which made every Blue install fail verification with a phantom
        # "AI Workbench missing" error.
        $requiredPaths = @(
            $ws,
            (Join-Path $ws "vault\maker"),
            (Join-Path $ws ".github\copilot-instructions.md"),
            (Join-Path $ws ".github\agents\ai-maker.md")
        )
        if ($Pill -eq "red") {
            $requiredPaths += (Join-Path $ws "vault\workbench")
            $requiredPaths += (Join-Path $ws ".github\agents\ai-workbench.md")
        }
        $missing = $requiredPaths | Where-Object { -not (Test-Path $_) }
        if ($missing) {
            $missing | ForEach-Object { Write-Host "  ✗ MISSING: $_" -ForegroundColor Red }
            throw "New-WorkspaceScaffold: workspace incomplete — $($missing.Count) required path(s) missing. Check write permissions on C:\GitHub."
        }

        # Content marker check: copilot-instructions.md must contain pill-specific marker.
        # Catches the case where a stale/stock file was preserved instead of overwritten.
        $expectedMarker = if ($Pill -eq "blue") { "AI Maker Workspace" } else { "AI Workspace" }
        $ciContent = Get-Content (Join-Path $ws ".github\copilot-instructions.md") -Raw -ErrorAction Stop
        if ($ciContent -notmatch [regex]::Escape($expectedMarker)) {
            $firstLine = ($ciContent -split "`n")[0]
            throw "New-WorkspaceScaffold: copilot-instructions.md does not contain expected marker '$expectedMarker' for Pill=$Pill. First line is: '$firstLine'. The pill template was not applied — this is a packaging bug."
        }
        Write-Host "  ✓ Workspace verified complete (marker '$expectedMarker' present)" -ForegroundColor Green
    }
}

# ═══════════════════════════════════════════════════════════════
# §6. SKILL INSTALLATION
# ═══════════════════════════════════════════════════════════════

function Install-Skills {
    <#
    .SYNOPSIS
        Copies skill folders to ~/.copilot/skills/
    .PARAMETER Pill
        "blue" = AI Maker only (11), "red" = both (22)
    .PARAMETER SourcePath
        Path to the skills source directory
    .PARAMETER Manifest
        Existing manifest (for upgrade checksum comparison)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet("blue","red")][string]$Pill,
        [Parameter(Mandatory)][string]$SourcePath,
        [hashtable]$Manifest,
        [switch]$WhatIf
    )

    $filter = if ($Pill -eq "blue") { "ai-maker-*" } else { "ai-*" }
    $skillFolders = Get-ChildItem $SourcePath -Directory -Filter $filter

    $installed = @()

    foreach ($folder in $skillFolders) {
        $targetPath = Join-Path $script:AIMakerConfig.SkillsPath $folder.Name
        $skillMd = Join-Path $folder.FullName "SKILL.md"
        $newChecksum = Get-SkillChecksum -Path $skillMd

        # Check if skill exists and was modified by user
        $existingSkillMd = Join-Path $targetPath "SKILL.md"
        if ((Test-Path $existingSkillMd) -and $Manifest) {
            $managedEntry = $Manifest.skills.managed | Where-Object { $_.id -eq $folder.Name }
            if ($managedEntry) {
                $currentChecksum = Get-SkillChecksum -Path $existingSkillMd
                if ($currentChecksum -ne $managedEntry.checksum) {
                    Write-Host "  ⚠ Skipping $($folder.Name) — user modified (checksum mismatch)" -ForegroundColor Yellow
                    continue
                }
            }
        }

        Invoke-TxOp -Operation "INSTALL_SKILL" -Description "Install skill: $($folder.Name)" `
            -Path $targetPath -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            Copy-Item $folder.FullName $targetPath -Recurse -Force
        }

        $installed += @{
            id        = $folder.Name
            version   = $(
                $vPath = Join-Path $folder.FullName ".bundled-version"
                if (Test-Path $vPath) { (Get-Content $vPath -EA SilentlyContinue) } else { "1.0.0" }
            )
            checksum  = $newChecksum
            installed = (Get-Date -Format "o")
        }
    }

    return $installed
}

# ═══════════════════════════════════════════════════════════════
# §7. MIGRATION HELPERS
# ═══════════════════════════════════════════════════════════════

function Test-CopilotInstructionsModified {
    <#
    .SYNOPSIS
        Checks if copilot-instructions.md was modified by the user.
    .OUTPUTS
        $true if user modified it (don't overwrite), $false if it's stock (safe to overwrite)
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) { return $false }

    # Normalize line endings before hashing (stock hash uses LF)
    $raw = [System.IO.File]::ReadAllText($Path)
    $normalized = $raw -replace "`r`n", "`n"
    $encoding = [System.Text.UTF8Encoding]::new($false)
    $bytes = $encoding.GetBytes($normalized)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-","").ToLower()
    return ($hash -notin $script:KnownStockHashes)
}

function Get-DiskSpaceCheck {
    <#
    .SYNOPSIS
        Verifies adequate free disk space for migration (3x vault size).
    .OUTPUTS
        Hashtable with: ok (bool), required (bytes), available (bytes), message (string)
    #>
    [CmdletBinding()]
    param()

    $vaultSize = 0
    if (Test-Path $script:AIMakerConfig.LegacyMakerPath) {
        $vaultSize += (Get-ChildItem (Join-Path $script:AIMakerConfig.LegacyMakerPath "vault") -Recurse -EA Silent |
            Measure-Object -Sum Length).Sum
    }
    if (Test-Path $script:AIMakerConfig.LegacyWorkbenchPath) {
        $vaultSize += (Get-ChildItem (Join-Path $script:AIMakerConfig.LegacyWorkbenchPath "vault") -Recurse -EA Silent |
            Measure-Object -Sum Length).Sum
    }

    $required = [long]($vaultSize * 3)
    $drive = (Split-Path $script:AIMakerConfig.WorkspacePath -Qualifier)
    $available = (Get-PSDrive ($drive[0])).Free

    $ok = $available -ge $required
    $message = if ($ok) { "Disk space OK" }
    else { "Need $([math]::Round($required/1MB,1))MB free, have $([math]::Round($available/1MB,1))MB" }

    return @{ ok = $ok; required = $required; available = $available; message = $message }
}

function Copy-VaultData {
    <#
    .SYNOPSIS
        Copies vault data from legacy paths to new workspace (symmetric namespacing).
    #>
    [CmdletBinding()]
    param([switch]$WhatIf)

    $ws = $script:AIMakerConfig.WorkspacePath
    $makerVault = Join-Path $script:AIMakerConfig.LegacyMakerPath "vault"
    $workbenchVault = Join-Path $script:AIMakerConfig.LegacyWorkbenchPath "vault"

    if (Test-Path $makerVault) {
        $dest = Join-Path $ws "vault\maker"
        Invoke-TxOp -Operation "COPY" -Description "Copy Maker vault → vault\maker\" `
            -Path $dest -From $makerVault -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            Copy-Item "$makerVault\*" $dest -Recurse -Force -EA Silent
        }
    }

    if (Test-Path $workbenchVault) {
        $dest = Join-Path $ws "vault\workbench"
        Invoke-TxOp -Operation "COPY" -Description "Copy Workbench vault → vault\workbench\" `
            -Path $dest -From $workbenchVault -Reversible $true -WhatIf:$WhatIf -ScriptBlock {
            Copy-Item "$workbenchVault\*" $dest -Recurse -Force -EA Silent
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# §8. HEALTH CHECK (-Doctor)
# ═══════════════════════════════════════════════════════════════

function Invoke-HealthCheck {
    <#
    .SYNOPSIS
        Runs diagnostic checks and reports status.
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n═══ AI Maker v3 Health Check ═══`n" -ForegroundColor Cyan

    $checks = @()

    # Copilot App
    $appInstalled = (winget list --id GitHub.CopilotApp --accept-source-agreements 2>$null) -match "GitHub.CopilotApp"
    $checks += @{ name = "Copilot App"; ok = [bool]$appInstalled; detail = if ($appInstalled) { "Installed" } else { "NOT FOUND" } }

    # Skills count
    $makerCount = (Get-ChildItem (Join-Path $script:AIMakerConfig.SkillsPath "ai-maker-*") -Directory -EA Silent).Count
    $wbCount = (Get-ChildItem (Join-Path $script:AIMakerConfig.SkillsPath "ai-workbench-*") -Directory -EA Silent).Count
    $checks += @{ name = "AI Maker skills"; ok = ($makerCount -ge 11); detail = "$makerCount/11" }
    $checks += @{ name = "AI Workbench skills"; ok = ($wbCount -ge 11); detail = "$wbCount/11" }

    # Manifest
    $manifest = Read-AIMakerManifest
    $checks += @{ name = "Manifest"; ok = ($null -ne $manifest); detail = if ($manifest) { "v$($manifest.installer_version) ($($manifest.pill))" } else { "NOT FOUND" } }

    # Workspace
    $wsExists = Test-Path $script:AIMakerConfig.WorkspacePath
    $checks += @{ name = "Workspace folder"; ok = $wsExists; detail = $script:AIMakerConfig.WorkspacePath }

    # Skills directory writable
    $writable = $true
    try { $testFile = Join-Path $script:AIMakerConfig.SkillsPath ".write-test"; Set-Content $testFile "test" -EA Stop; Remove-Item $testFile }
    catch { $writable = $false }
    $checks += @{ name = "Skills dir writable"; ok = $writable; detail = $script:AIMakerConfig.SkillsPath }

    # Git (Red Pill only)
    if ($manifest -and $manifest.pill -eq "red") {
        $gitInstalled = (Get-Command git -EA Silent) -ne $null
        $checks += @{ name = "Git"; ok = $gitInstalled; detail = if ($gitInstalled) { (git --version 2>$null) } else { "NOT FOUND" } }

        $ghInstalled = (Get-Command gh -EA Silent) -ne $null
        $checks += @{ name = "GitHub CLI"; ok = $ghInstalled; detail = if ($ghInstalled) { "Installed" } else { "NOT FOUND" } }

        if ($ghInstalled) {
            $null = gh auth status 2>$null
            $authed = ($LASTEXITCODE -eq 0)
            $checks += @{ name = "GitHub auth"; ok = $authed; detail = if ($authed) { "Authenticated" } else { "NOT LOGGED IN" } }
        }
    }

    # Print results
    foreach ($check in $checks) {
        $icon = if ($check.ok) { "✓" } else { "✗" }
        $color = if ($check.ok) { "Green" } else { "Red" }
        Write-Host "  $icon $($check.name): $($check.detail)" -ForegroundColor $color
    }

    $failed = ($checks | Where-Object { -not $_.ok }).Count
    Write-Host "`n$(if ($failed -eq 0) { '✓ All checks passed' } else { "✗ $failed issue(s) found" })" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

    return $checks
}

# ═══════════════════════════════════════════════════════════════
# §9. TEMPLATE CONTENT (inline for single-file distribution)
# ═══════════════════════════════════════════════════════════════

$script:StockInstructions = @'
# AI Workspace — Copilot Instructions

This is your personal AI workspace. It's where you work with Copilot on anything from research and writing to design thinking and day-to-day tasks.

## What this workspace is for

This workspace is set up for creative and analytical work. You have two areas:

- **vault/maker** — your creative toolkit: research, brainstorming, design thinking, writing, and strategy
- **vault/workbench** — your technical toolkit: code, automation, testing, and engineering tasks

Use the maker side when you're exploring ideas or producing content. Use the workbench side when you're building or debugging something.

## How to work with Copilot here

Just describe what you want to do. If you want to research something, brainstorm ideas, draft a document, analyze data, or write a script — start talking and Copilot will figure out which skills apply.

You don't need to remember command names or skill names. Natural language works fine.

## A few things to know

- Your vault is yours. Nothing in it is shared unless you share it.
- Skills are installed in your local profile. They update when you run the installer again.
- If something isn't working the way you expect, describe the behavior and Copilot will help diagnose it.

## Tone

Be direct. You don't need to be polite to get good results. If a response isn't useful, say so and ask for something different.

## Memory

Save important decisions, preferences, and context to your vault so you remember them next time. If I tell you something I want you to remember, save it.
'@

$script:VaultReadme = @'
# vault

This folder holds the context and content that powers your AI workspace skills.

## vault/maker

AI Maker skills live here. Use this side for:

- Research and synthesis
- Brainstorming and ideation
- Design thinking and strategy
- Writing, editing, and content creation
- Data exploration and analysis
- Canvas and presentation work

## vault/workbench

AI Workbench skills live here. Use this side for:

- Writing and running scripts (PowerShell, Python, etc.)
- Code review and debugging
- CI/CD and automation
- Security and dependency checks
- Prompt engineering (building new skills)
- GitHub and repo management

## What goes in the vault vs. your project folders

The vault is for **ongoing context** — things that make your skills smarter over time. Examples: a style guide you want writing to follow, a glossary of terms, a set of example outputs you liked.

Your actual project files (code, documents, deliverables) should stay in your project folders. The vault is context, not storage.

## Keeping it clean

If a skill folder has grown large with files you no longer need, clear it out. Old context can confuse new work just as much as no context.
'@

$script:GitIgnoreTemplate = @'
# Secrets and credentials
.env
.env.*
secrets/
*.pem
*.key
*.pfx
*.p12
.gh-token
*.secret
credentials.json

# Temporary files
*.tmp
*.temp
*.bak
*.swp
*~

# Logs
*.log
logs/

# OS files
.DS_Store
Thumbs.db
desktop.ini
ehthumbs.db

# Node
node_modules/
npm-debug.log*
yarn-error.log*

# Python
__pycache__/
*.pyc
*.pyo
.venv/
venv/

# Editor
.vscode/launch.json
.idea/
*.suo
*.user
'@

# ═══════════════════════════════════════════════════════════════
# ALIASES (backward compat with FF test stubs)
# ═══════════════════════════════════════════════════════════════

Set-Alias -Name Test-AIMManifest -Value Test-AIMakerManifest -Scope Script
Set-Alias -Name Read-AIMManifest -Value Read-AIMakerManifest -Scope Script
Set-Alias -Name Write-AIMManifest -Value Write-AIMakerManifest -Scope Script
Set-Alias -Name New-AIMManifest -Value New-AIMakerManifest -Scope Script
Set-Alias -Name Get-AIMScenario -Value Get-InstallScenario -Scope Script
Set-Alias -Name Copy-AIMVault -Value Copy-VaultData -Scope Script
Set-Alias -Name Test-AIMInstructionsModified -Value Test-CopilotInstructionsModified -Scope Script
Set-Alias -Name Write-AIMTxEntry -Value Write-TxEntry -Scope Script

# ═══════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════

# When dot-sourced, all functions above are available.
# Key entry points:
#   Get-InstallScenario         — detect current state (§4)
#   New-WorkspaceScaffold       — create project folder (§5)
#   Install-Skills              — copy skills to App path (§6)
#   New-AIMakerManifest         — create manifest object (§3)
#   Write-AIMakerManifest       — persist manifest to disk (§3)
#   Invoke-HealthCheck          — run -Doctor diagnostics (§8)
#   Invoke-Rollback             — best-effort rollback (§2)
#   Copy-VaultData              — migrate legacy vaults (§7)
#   Test-CopilotInstructionsModified — hash check (§7)
#   Get-DiskSpaceCheck          — verify free space (§7)


# ============================================================================
# §6b. AGENCY MCP REGISTRATION + APP LAUNCH (v3.0.1)
# ============================================================================

function Register-AgencyMcpServers {
    <#
    .SYNOPSIS
        Registers Agency's MCP servers (workiq + bluebird) with the Copilot App.
    .DESCRIPTION
        The Copilot App reads ~/.copilot/m-mcp-servers.json to discover MCP servers.
        Agency provides workiq (M365) and bluebird via `agency mcp <name>`.
        This function reads the existing JSON (or creates one with the standard
        filesystem+playwright builtins if missing), merges workiq+bluebird without
        clobbering user customizations, and writes it back as pretty UTF-8 (no BOM).
        Idempotent — safe to run repeatedly.
    .PARAMETER WhatIf
        Preview changes without writing.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $configPath = $script:AIMakerConfig.McpConfigPath

    # Resolve agency.exe — PATH first, then AppData fallback
    $agencyCmd = (Get-Command agency.exe -ErrorAction SilentlyContinue).Source
    if (-not $agencyCmd) {
        $fallback = $script:AIMakerConfig.AgencyBinaryFallback
        if (Test-Path $fallback) { $agencyCmd = $fallback }
    }
    if (-not $agencyCmd) {
        throw "Register-AgencyMcpServers: agency.exe not found on PATH and not at $($script:AIMakerConfig.AgencyBinaryFallback). MCP servers cannot be wired up. Install Agency CLI first."
    }

    # Load or seed config
    $existing = $null
    if (Test-Path $configPath) {
        try {
            $existing = Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Host "    [WARN] m-mcp-servers.json malformed; backing up and re-seeding." -ForegroundColor Yellow
            $bak = "$configPath.bak.$(Get-Date -Format yyyyMMddHHmmss)"
            Copy-Item $configPath $bak -Force
            $existing = $null
        }
    }

    if (-not $existing) {
        # Seed with the standard builtins the App expects when no config exists
        $existing = [PSCustomObject]@{
            servers = [PSCustomObject]@{
                filesystem = [PSCustomObject]@{
                    command = "npx"
                    args    = @("-y", "@modelcontextprotocol/server-filesystem", $env:USERPROFILE)
                    tools   = @("*")
                }
                playwright = [PSCustomObject]@{
                    command = "npx"
                    args    = @("-y", "@playwright/mcp@latest")
                    tools   = @("*")
                }
            }
        }
    }

    # Ensure .servers exists
    if (-not ($existing.PSObject.Properties.Name -contains "servers")) {
        $existing | Add-Member -NotePropertyName "servers" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    # Build target entries
    $workiqEntry = [PSCustomObject]@{
        command = $agencyCmd
        args    = @("mcp", "workiq")
        tools   = @("*")
    }
    $bluebirdEntry = [PSCustomObject]@{
        command = $agencyCmd
        args    = @("mcp", "bluebird")
        tools   = @("*")
    }

    # Merge — only add if missing (preserves user customizations)
    $changed = $false
    foreach ($pair in @(
        @{ Name = "workiq";   Value = $workiqEntry },
        @{ Name = "bluebird"; Value = $bluebirdEntry }
    )) {
        $name = $pair.Name
        if (-not ($existing.servers.PSObject.Properties.Name -contains $name)) {
            $existing.servers | Add-Member -NotePropertyName $name -NotePropertyValue $pair.Value -Force
            $changed = $true
            Write-Host "    [+] Registered MCP server: $name" -ForegroundColor Green
        } else {
            Write-Host "    [=] MCP server already registered: $name (preserved)" -ForegroundColor Gray
        }
    }

    if (-not $changed) {
        Write-Host "    [OK] m-mcp-servers.json already has workiq + bluebird. No change." -ForegroundColor Green
        return
    }

    if ($PSCmdlet.ShouldProcess($configPath, "Write MCP config")) {
        # Ensure parent dir exists
        $parent = Split-Path $configPath -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        $json = $existing | ConvertTo-Json -Depth 10
        # UTF-8 no BOM
        [System.IO.File]::WriteAllText($configPath, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Host "    [OK] Wrote $configPath" -ForegroundColor Green

        # Verify write actually worked and contains both servers
        if (-not (Test-Path $configPath)) {
            throw "Register-AgencyMcpServers: write claimed success but $configPath does not exist."
        }
        $verify = Get-Content $configPath -Raw | ConvertFrom-Json -ErrorAction Stop
        $missing = @()
        if (-not ($verify.servers.PSObject.Properties.Name -contains 'workiq'))   { $missing += 'workiq' }
        if (-not ($verify.servers.PSObject.Properties.Name -contains 'bluebird')) { $missing += 'bluebird' }
        if ($missing.Count -gt 0) {
            throw "Register-AgencyMcpServers: post-write verification failed — missing servers: $($missing -join ', ')"
        }
        Write-Host "    [OK] Verified workiq + bluebird present in config" -ForegroundColor Green
    } else {
        Write-Host "    [WHATIF] Would write $configPath with workiq + bluebird merged in." -ForegroundColor Cyan
    }
}

function Invoke-AgencyGhApp {
    <#
    .SYNOPSIS
        Launches the Copilot App via `agency gh-app`.
    .DESCRIPTION
        Agency exposes `gh-app` to start the Copilot App with all M365 connectors
        wired up. Replaces the legacy Start-Process "GitHub Copilot.exe" call.
        Non-fatal — prints manual fallback message if agency is missing or fails.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $agencyCmd = (Get-Command agency.exe -ErrorAction SilentlyContinue).Source
    if (-not $agencyCmd) {
        $fallback = $script:AIMakerConfig.AgencyBinaryFallback
        if (Test-Path $fallback) { $agencyCmd = $fallback }
    }
    if (-not $agencyCmd) {
        Write-Host "    [SKIP] agency.exe not found. To launch manually: agency gh-app" -ForegroundColor Yellow
        return
    }

    if ($PSCmdlet.ShouldProcess("agency gh-app", "Launch Copilot App")) {
        try {
            & $agencyCmd gh-app
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    [WARN] agency gh-app exited with code $LASTEXITCODE. Launch the App manually." -ForegroundColor Yellow
            } else {
                Write-Host "    [OK] Launched Copilot App via agency gh-app" -ForegroundColor Green
            }
        } catch {
            Write-Host "    [WARN] agency gh-app failed: $($_.Exception.Message). Launch the App manually." -ForegroundColor Yellow
        }
    } else {
        Write-Host "    [WHATIF] Would run: agency gh-app" -ForegroundColor Cyan
    }
}
