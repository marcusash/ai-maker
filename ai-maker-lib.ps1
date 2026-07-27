#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 — Core library module
.DESCRIPTION
    Shared functions for install-blue.ps1, install-red.ps1, and migrate.ps1.
    Covers: manifest management, detection matrix, transaction log, scaffold creation.
.VERSION
    3.0.14
#>

# ═══════════════════════════════════════════════════════════════
# §1. CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$script:AIMakerConfig = @{
    Version          = "3.0.14"
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
    McpServersPath   = (Join-Path $env:USERPROFILE ".copilot\m-mcp-servers.json")
}

# Known stock hashes for copilot-instructions.md (all previous versions)
$script:KnownStockHashes = @(
    # v3.0.0 — shipped with ai-maker-v3 installer (matches Get-StockCopilotInstructionsContent output, LF-normalized)
    "4271d7bf4bf837e9478e16ae8e967f8b690875a14f6541231728d21faf13f877"
    # v3.0.14 — Blue Pill variant (AI Maker only, no Workbench)
    "ad9564771b676742f5de9465306b84704e362b03297c6c5f655de648744652f1"
    # NOTE: Pre-v3 instructions have no archived hashes. Users with custom pre-v3 files
    # will be detected as "modified" — their content is preserved as .user.md (safe default).
)

function Get-StockCopilotInstructionsContent {
    <#
    .SYNOPSIS
        Returns the canonical copilot-instructions.md content.
        Single source of truth — lib owns both the hash and the content.
        Pill-aware: Blue = AI Maker only, Red = both agents.
    .PARAMETER Pill
        "blue" or "red" — determines which agents are referenced.
    #>
    [CmdletBinding()]
    param(
        [Parameter()][ValidateSet("blue","red")][string]$Pill = "red"
    )

    if ($Pill -eq "blue") {
        return @'
# AI Workspace

This project has one AI agent: **AI Maker** (creative/strategic thinking partner).

## Bootstrap Protocol

When you are the first session opened in this project and no "AI Maker" session exists yet, execute this automatically WITHOUT asking:

1. Tell the user: "Setting up your AI agent..."

2. Use `create_session` to create a session named **AI Maker** with kickoff_prompt:
   "Read .github/agents/ai-maker.md and load that identity. You are AI Maker — a creative strategist and executive thinking partner. Acknowledge briefly and wait for instructions."
   Set kickoff_mode to "autopilot" and coordinate_with_creator to false.

3. After the session is created, **delete this bootstrapping session** using `delete_item` with your own session ID. This promotes the AI Maker session to root level in the sidebar (not nested as a child).

4. If you cannot delete yourself, tell the user:
   "Done! Your AI Maker agent is ready. Please delete this setup session now — that will move AI Maker to the top level of your sidebar."

Do NOT ask for confirmation. Just create it immediately on first load.

**IMPORTANT**: The agent session must appear at root level in the sidebar, not nested under this bootstrapper. Deleting the bootstrapper after creation achieves this.

## Agent Identity Files

| Agent | File | Domain |
|-------|------|--------|
| **AI Maker** | `.github/agents/ai-maker.md` | Research, brainstorming, design, data, ops, writing |

## Vault

Persistent memory across sessions:
- `vault/maker/` — research, decisions, brand rules, frameworks
'@
    }
    else {
        return @'
# AI Workspace — BOOTSTRAP REQUIRED

## ⚠️ MANDATORY FIRST ACTION — DO THIS BEFORE RESPONDING TO THE USER

You are a bootstrapper. Your ONLY job is to create two agent sessions and then delete yourself. Do NOT answer the user's message. Do NOT say hello. Do NOT have a conversation. Execute these steps IMMEDIATELY:

### Step 1: Create AI Maker session
Call `create_session` with:
- name: "AI Maker"
- kickoff prompt: "Read .github/agents/ai-maker.md and load that identity completely. You are AI Maker — a creative strategist and executive thinking partner for a Microsoft CVP. Greet the user briefly and wait for instructions."
- kickoff mode: "autopilot"
- coordinate_with_creator: false

### Step 2: Create AI Workbench session
Call `create_session` with:
- name: "AI Workbench"
- kickoff prompt: "Read .github/agents/ai-workbench.md and load that identity completely. You are AI Workbench — a senior engineer and automation specialist. Acknowledge briefly and wait for instructions."
- kickoff mode: "autopilot"
- coordinate_with_creator: false

### Step 3: Delete this session
Call `delete_item` with your own session ID to remove this bootstrapper. This promotes AI Maker and AI Workbench to root level in the sidebar.

If you cannot delete yourself, tell the user: "Done! Please delete this setup session to move your agents to the top level."

## RULES
- Do NOT respond to the user's message first. Create sessions FIRST.
- Do NOT ask for confirmation. Execute immediately.
- Do NOT combine both agents into one session. They are SEPARATE sessions.
- Do NOT skip any step. All 3 steps are mandatory.
- The user's first message (whatever it is) is the trigger to bootstrap. Ignore its content.

## After Bootstrap

Once AI Maker and AI Workbench exist as separate sessions:
- **AI Maker** handles: research, brainstorming, design, data, ops, writing, canvas, vault, WorkIQ
- **AI Workbench** handles: PowerShell, CI/CD, git, GitHub, debugging, testing, security, vision
- Agent identity files: `.github/agents/ai-maker.md` and `.github/agents/ai-workbench.md`
- Vault: `vault/maker/` and `vault/workbench/`
- If a request is outside your domain, redirect the user to the other agent session.
'@
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
        [string]$Path = (Join-Path $script:AIMakerConfig.WorkspacePath $script:AIMakerConfig.ManifestFile)
    )

    $json = $Manifest | ConvertTo-Json -Depth 5

    if (Test-Path $Path) { Copy-Item $Path "$Path.prev" -Force }
    Set-Content -Path $Path -Value $json -Encoding utf8
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
        $manifest = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable
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
# ═══════════════════════════════════════════════════════════════
# §5. SCAFFOLD CREATION
# ═══════════════════════════════════════════════════════════════

function New-WorkspaceScaffold {
    <#
    .SYNOPSIS
        Creates the ai-workspace project folder with pill-aware vault and agent structure.
    .DESCRIPTION
        PRD §10.3: Blue = ai-maker.md + vault/maker/ ONLY; Red = both agents + both vaults.
    .PARAMETER Pill
        "blue" or "red" — determines which agents and vault dirs are created.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet("blue","red")][string]$Pill,
        [Parameter(Mandatory)][string]$AgentSourcePath
    )

    $ws = $script:AIMakerConfig.WorkspacePath

    # Create directory structure — pill-aware (PRD §10.3)
    $dirs = @(
        $ws,
        (Join-Path $ws "vault"),
        (Join-Path $ws "vault\maker"),
        (Join-Path $ws ".github"),
        (Join-Path $ws ".github\agents")
    )
    if ($Pill -eq "red") {
        $dirs += (Join-Path $ws "vault\workbench")
    }

    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }

    # Write copilot-instructions.md (only if not exists) — pill-aware
    $instructionsPath = Join-Path $ws ".github\copilot-instructions.md"
    if (-not (Test-Path $instructionsPath)) {
        $instructions = Get-StockCopilotInstructionsContent -Pill $Pill
        Set-Content -Path $instructionsPath -Value $instructions -Encoding utf8
    }

    # Write vault README
    $vaultReadme = Join-Path $ws "vault\README.md"
    if (-not (Test-Path $vaultReadme)) {
        Set-Content -Path $vaultReadme -Value $script:VaultReadme -Encoding utf8
    }

    # Write .gitignore
    $gitignorePath = Join-Path $ws ".gitignore"
    if (-not (Test-Path $gitignorePath)) {
        Set-Content -Path $gitignorePath -Value $script:GitIgnoreTemplate -Encoding utf8
    }

    # Write .mcp.json — WorkIQ MCP server connection (required at workspace root)
    $mcpJsonPath = Join-Path $ws ".mcp.json"
    if (-not (Test-Path $mcpJsonPath)) {
        $mcpConfig = @{
            mcpServers = @{
                workiq = @{
                    type            = "http"
                    url             = "https://workiq.svc.cloud.microsoft/mcp"
                    oauthClientId   = "ba081686-5d24-4bc6-a0d6-d034ecffed87"
                    oauthPublicClient = $true
                    auth            = @{ redirectPort = 12798 }
                }
            }
        }
        $mcpJson = $mcpConfig | ConvertTo-Json -Depth 5
        Set-Content -Path $mcpJsonPath -Value $mcpJson -Encoding utf8
    }

    # Write agent identity files — pill-aware (PRD §10.3)
    $agentsDir = Join-Path $ws ".github\agents"
    $agentSource = $AgentSourcePath
    if (-not (Test-Path $agentSource)) {
        throw "New-WorkspaceScaffold: agents source directory not found at $agentSource. Cannot install agent identities."
    }

    $agentFiles = if ($Pill -eq "blue") { @("ai-maker.md") } else { @("ai-maker.md", "ai-workbench.md") }

    foreach ($fileName in $agentFiles) {
        $src = Join-Path $agentSource $fileName
        if (-not (Test-Path $src)) {
            throw "New-WorkspaceScaffold: required agent file '$fileName' not found in $agentSource."
        }
        $dest = Join-Path $agentsDir $fileName
        if (-not (Test-Path $dest)) {
            Copy-Item $src $dest -Force
        }
    }

    # Verify scaffold completed (verify-or-throw — PRD §15)
    $expectedMarker = if ($Pill -eq "blue") { "ai-maker.md" } else { "ai-workbench.md" }
    $checkPath = Join-Path $agentsDir $expectedMarker
    if (-not (Test-Path $checkPath)) {
        throw "New-WorkspaceScaffold: post-scaffold verification failed — $expectedMarker not present at $checkPath"
    }
}

# ═══════════════════════════════════════════════════════════════
# §5b. MCP LIVENESS PROBE (PRD §8 — activation gate verification)
# ═══════════════════════════════════════════════════════════════

function Test-McpLiveness {
    <#
    .SYNOPSIS
        Non-fatal liveness check for Agency MCP server (WorkIQ).
        Spawns the MCP transport, waits for response, kills process.
        Returns $true if alive, $false with warning if not.
    #>
    [CmdletBinding()]
    param(
        [string]$ServerName = "workiq",
        [int]$TimeoutSeconds = 10
    )

    $agencyExe = Get-Command agency -EA SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $agencyExe) {
        Write-Warning "Test-McpLiveness: agency.exe not found in PATH — skipping liveness check"
        return $false
    }

    try {
        $proc = Start-Process -FilePath $agencyExe `
            -ArgumentList "mcp", $ServerName, "--transport", "http" `
            -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\mcp-probe-out.txt" `
            -RedirectStandardError "$env:TEMP\mcp-probe-err.txt"

        # Wait for process to start and respond
        $elapsed = 0
        $alive = $false
        while ($elapsed -lt $TimeoutSeconds) {
            Start-Sleep -Milliseconds 500
            $elapsed += 0.5

            if ($proc.HasExited) {
                # Process exited — check if it output anything before dying
                $output = Get-Content "$env:TEMP\mcp-probe-out.txt" -EA SilentlyContinue -Raw
                if ($output -and $output.Length -gt 0) {
                    $alive = $true
                }
                break
            }

            # If still running after 2s, it's responding (MCP server stays alive)
            if ($elapsed -ge 2) {
                $alive = $true
                break
            }
        }

        # Kill the probe process
        if (-not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -EA SilentlyContinue
        }

        # Cleanup temp files
        Remove-Item "$env:TEMP\mcp-probe-out.txt" -EA SilentlyContinue
        Remove-Item "$env:TEMP\mcp-probe-err.txt" -EA SilentlyContinue

        if ($alive) {
            Write-Host "  ✓ MCP server '$ServerName' is responding" -ForegroundColor Green
            return $true
        }
        else {
            $errContent = Get-Content "$env:TEMP\mcp-probe-err.txt" -EA SilentlyContinue -Raw
            Write-Warning "Test-McpLiveness: MCP server '$ServerName' did not respond within ${TimeoutSeconds}s. Error: $errContent"
            return $false
        }
    }
    catch {
        Write-Warning "Test-McpLiveness: probe failed — $($_.Exception.Message)"
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════
# §5c. REGISTER MCP SERVERS (PRD §8.2 — direct JSON write)
# ═══════════════════════════════════════════════════════════════

function Register-AgencyMcpServers {
    <#
    .SYNOPSIS
        Writes bluebird entry to m-mcp-servers.json.
        Does NOT use a CLI command — writes JSON directly per PRD §8.2.
        NOTE: WorkIQ is now a Copilot App plugin (installed via Install-WorkiqPlugin),
        not an Agency-hosted MCP server.
    .PARAMETER AgencyExePath
        Full path to agency.exe (used as the command in MCP entries).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AgencyExePath
    )

    $mcpFile = $script:AIMakerConfig.McpServersPath
    $mcpDir  = Split-Path $mcpFile -Parent
    if (-not (Test-Path $mcpDir)) { New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null }

    # Read existing or seed empty
    if (Test-Path $mcpFile) {
        $config = Get-Content $mcpFile -Raw | ConvertFrom-Json -AsHashtable
    }
    else {
        $config = @{}
    }

    # Merge bluebird entry (Agency-hosted MCP server)
    $config["bluebird"] = @{
        command = $AgencyExePath
        args    = @("mcp", "bluebird")
        tools   = @("*")
    }

    # Write UTF-8 no BOM
    $json = $config | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($mcpFile, $json, [System.Text.UTF8Encoding]::new($false))
}

# ═══════════════════════════════════════════════════════════════
# §5d. INSTALL WORKIQ PLUGIN (cloud-hosted MCP — no Agency dependency)
# ═══════════════════════════════════════════════════════════════

function Install-WorkiqPlugin {
    <#
    .SYNOPSIS
        Installs the WorkIQ plugin for the Copilot App.
        Copies plugin files to ~/.copilot/installed-plugins/copilot-plugins/workiq/
        and registers it in config.json + settings.json.
        WorkIQ is a cloud-hosted HTTP MCP server (https://workiq.svc.cloud.microsoft/mcp)
        — no Agency dependency, no local binary needed.
    .PARAMETER SourcePath
        Path to the directory containing the workiq plugin files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourcePath
    )

    $copilotDir = Join-Path $env:USERPROFILE ".copilot"
    $pluginDir  = Join-Path $copilotDir "installed-plugins\copilot-plugins\workiq"

    try {
        # Copy plugin files
        if (Test-Path $pluginDir) {
            Remove-Item $pluginDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
        Copy-Item -Path "$SourcePath\*" -Destination $pluginDir -Recurse -Force

        # Register in config.json (managed by the Copilot App)
        # Atomic write: write to temp file, then rename to avoid partial-write races
        $configFile = Join-Path $copilotDir "config.json"
        if (Test-Path $configFile) {
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
        }
        else {
            $config = [PSCustomObject]@{
                installedPlugins = @()
            }
        }

        # Ensure installedPlugins array exists
        if (-not $config.installedPlugins) {
            $config | Add-Member -NotePropertyName "installedPlugins" -NotePropertyValue @() -Force
        }

        # Remove existing workiq entry if present, then add fresh
        # Read version from the plugin's own manifest (source of truth)
        $pluginManifest = Join-Path $SourcePath ".github\plugin\plugin.json"
        $pluginVersion = "0.0.0"
        if (Test-Path $pluginManifest) {
            $pluginVersion = (Get-Content $pluginManifest -Raw | ConvertFrom-Json).version
        }

        $config.installedPlugins = @($config.installedPlugins | Where-Object { $_.name -ne "workiq" })
        $config.installedPlugins += [PSCustomObject]@{
            name         = "workiq"
            marketplace  = "copilot-plugins"
            version      = $pluginVersion
            installed_at = (Get-Date -Format "o")
            enabled      = $true
            cache_path   = $pluginDir
        }

        $configJson = $config | ConvertTo-Json -Depth 5
        $configTmp = "$configFile.$PID.tmp"
        [System.IO.File]::WriteAllText($configTmp, $configJson, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::Move($configTmp, $configFile, $true)

        # Enable in settings.json (atomic write)
        $settingsFile = Join-Path $copilotDir "settings.json"
        if (Test-Path $settingsFile) {
            $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable
        }
        else {
            $settings = @{}
        }

        if (-not $settings.ContainsKey("enabledPlugins")) {
            $settings["enabledPlugins"] = @{}
        }
        $settings["enabledPlugins"]["workiq@copilot-plugins"] = $true

        $settingsJson = $settings | ConvertTo-Json -Depth 5
        $settingsTmp = "$settingsFile.$PID.tmp"
        [System.IO.File]::WriteAllText($settingsTmp, $settingsJson, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::Move($settingsTmp, $settingsFile, $true)
    }
    catch {
        # Clean up plugin dir on failure — removing the dir makes any config entry harmless
        Remove-Item $pluginDir -Recurse -Force -EA SilentlyContinue
        throw
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
        [hashtable]$Manifest
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

        Copy-Item $folder.FullName $targetPath -Recurse -Force

        $installed += @{
            id        = $folder.Name
            version   = (Get-Content (Join-Path $folder.FullName ".bundled-version") -EA Silent) ?? "1.0.0"
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
    param()

    $ws = $script:AIMakerConfig.WorkspacePath
    $makerVault = Join-Path $script:AIMakerConfig.LegacyMakerPath "vault"
    $workbenchVault = Join-Path $script:AIMakerConfig.LegacyWorkbenchPath "vault"

    if (Test-Path $makerVault) {
        $dest = Join-Path $ws "vault\maker"
        Copy-Item "$makerVault\*" $dest -Recurse -Force -EA Silent
    }

    if (Test-Path $workbenchVault) {
        $dest = Join-Path $ws "vault\workbench"
        Copy-Item "$workbenchVault\*" $dest -Recurse -Force -EA Silent
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

    # BYO installs never write .ai-maker-manifest.json — detect the breadcrumb
    # and skip the skills/agents/workspace checks below, which don't apply.
    $byoManifestPath = Join-Path $env:USERPROFILE ".copilot\ai-maker\byo-manifest.json"
    $manifest = Read-AIMakerManifest
    if (-not $manifest -and (Test-Path $byoManifestPath)) {
        $byo = Get-Content $byoManifestPath -Raw | ConvertFrom-Json
        $checks += @{ name = "Manifest"; ok = $true; detail = "byo (repo: $($byo.repo))" }

        $appInstalled = (winget list --id GitHub.CopilotApp --accept-source-agreements 2>$null) -match "GitHub.CopilotApp"
        $checks += @{ name = "Copilot App"; ok = [bool]$appInstalled; detail = if ($appInstalled) { "Installed" } else { "NOT FOUND" } }

        $repoOk = Test-Path (Join-Path $byo.path ".git")
        $checks += @{ name = "Synced repo"; ok = $repoOk; detail = $byo.path }

        return $checks
    }

    # Copilot App
    $appInstalled = (winget list --id GitHub.CopilotApp --accept-source-agreements 2>$null) -match "GitHub.CopilotApp"
    $checks += @{ name = "Copilot App"; ok = [bool]$appInstalled; detail = if ($appInstalled) { "Installed" } else { "NOT FOUND" } }

    # Skills count
    $makerCount = (Get-ChildItem (Join-Path $script:AIMakerConfig.SkillsPath "ai-maker-*") -Directory -EA Silent).Count
    $wbCount = (Get-ChildItem (Join-Path $script:AIMakerConfig.SkillsPath "ai-workbench-*") -Directory -EA Silent).Count
    $checks += @{ name = "AI Maker skills"; ok = ($makerCount -ge 11); detail = "$makerCount/11" }
    $checks += @{ name = "AI Workbench skills"; ok = ($wbCount -ge 11); detail = "$wbCount/11" }

    # Manifest
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
# AI Workspace

This project has two AI agents: **AI Maker** (creative/strategic) and **AI Workbench** (technical/engineering).

## Bootstrap Protocol

When you are the first session opened in this project and no "AI Maker" or "AI Workbench" sessions exist yet, execute this automatically WITHOUT asking:

1. Tell the user: "Setting up your AI agents..."

2. Use `create_session` to create a session named **AI Maker** with kickoff_prompt:
   "Read .github/agents/ai-maker.md and load that identity. You are AI Maker — a creative strategist and executive thinking partner. Acknowledge briefly and wait for instructions."
   Set kickoff_mode to "autopilot" and coordinate_with_creator to false.

3. Use `create_session` to create a session named **AI Workbench** with kickoff_prompt:
   "Read .github/agents/ai-workbench.md and load that identity. You are AI Workbench — a senior engineer and automation specialist. Acknowledge briefly and wait for instructions."
   Set kickoff_mode to "autopilot" and coordinate_with_creator to false.

4. After both sessions are created, **delete this bootstrapping session** using `delete_item` with your own session ID. This promotes the two agent sessions to root level in the sidebar (not nested as children).

5. If you cannot delete yourself, tell the user:
   "Done! Your two agents are ready. Please delete this setup session now — that will move AI Maker and AI Workbench to the top level of your sidebar."

Do NOT ask for confirmation. Just create them immediately on first load.

**IMPORTANT**: The agent sessions must appear at root level in the sidebar, not nested under this bootstrapper. Deleting the bootstrapper after creation achieves this.

## Agent Identity Files

| Agent | File | Domain |
|-------|------|--------|
| **AI Maker** | `.github/agents/ai-maker.md` | Research, brainstorming, design, data, ops, writing |
| **AI Workbench** | `.github/agents/ai-workbench.md` | PowerShell, CI/CD, git, debugging, testing, security |

## Vault

Persistent memory across sessions:
- `vault/maker/` — research, decisions, brand rules, frameworks
- `vault/workbench/` — scripts, templates, configs, debugging notes

## Routing

AI Maker handles creative/strategic requests. AI Workbench handles technical/engineering requests. If a request is outside your domain, redirect the user to the other session.
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
Set-Alias -Name Copy-AIMVault -Value Copy-VaultData -Scope Script
Set-Alias -Name Test-AIMInstructionsModified -Value Test-CopilotInstructionsModified -Scope Script

# ═══════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════

# When dot-sourced, all functions above are available.
# Key entry points:
#   New-WorkspaceScaffold  — create project folder (§5)
#   Install-Skills         — copy skills to App path (§6)
#   New-AIMakerManifest    — create manifest object (§3)
#   Write-AIMakerManifest  — persist manifest to disk (§3)
#   Invoke-HealthCheck     — run -Doctor diagnostics (§8)
#   Copy-VaultData         — migrate legacy vaults (§7)
#   Test-CopilotInstructionsModified — hash check (§7)
#   Get-DiskSpaceCheck     — verify free space (§7)
