<#
.SYNOPSIS
    AI Maker Installer Test Sandbox — Phase 1 (Sandbox layer)

    Provides sandbox setup/teardown and installer invocation for Phase 1 case tests.
    Env-var redirection strategy: set USERPROFILE, APPDATA, LOCALAPPDATA, TEMP to
    per-test dirs before sourcing ai-maker-lib.ps1 so all lib path joins pick up
    the sandbox roots. Override $script:AIMakerConfig.*Path after sourcing to
    redirect the hardcoded WorkspacePath/LegacyMakerPath values.

    NOT a process monitor. Covers file writes through env vars only. Procmon/ETW
    (collateral writes, workspace boundary) is Phase 2 / VM layer.
#>

$ErrorActionPreference = 'Stop'

# ── Repo root discovery ───────────────────────────────────────────────────────
# Resolve the ai-maker repo root regardless of where this module lives in tests/
$script:ModuleRoot    = $PSScriptRoot   # tests/contract/fixtures/shared/
$script:RepoRoot      = Resolve-Path (Join-Path $script:ModuleRoot "..\..\..\..")
$script:LibPath       = Join-Path $script:RepoRoot "ai-maker-lib.ps1"
$script:MockContent   = Join-Path $script:ModuleRoot "mock-content"

# ── New-InstallerSandbox ──────────────────────────────────────────────────────

function New-InstallerSandbox {
    <#
    .SYNOPSIS
        Creates an isolated per-test sandbox directory tree and returns a context object.
    .PARAMETER Case
        Test case ID (B1, B2, R1, R2) — used only to name the sandbox folder.
    .OUTPUTS
        PSCustomObject with all sandbox paths and original env var snapshots.
    #>
    param([string]$Case = 'XX')

    $sandboxRoot = Join-Path $env:TEMP "AIMaker-Test-$Case-$(([guid]::NewGuid()).ToString('N').Substring(0,8))"

    $up   = Join-Path $sandboxRoot 'UserProfile'
    $ad   = Join-Path $up 'AppData\Roaming'
    $lad  = Join-Path $up 'AppData\Local'
    $tmp  = Join-Path $sandboxRoot 'Temp'
    $sp   = Join-Path $up '.copilot\skills'
    $ws   = Join-Path $sandboxRoot 'GitHub\ai-workspace'
    $lm   = Join-Path $sandboxRoot 'AIMaker'
    $lw   = Join-Path $sandboxRoot 'AIWorkbench'

    foreach ($d in @($up, $ad, $lad, $tmp, $sp)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }

    return [pscustomobject]@{
        Root             = $sandboxRoot
        UserProfile      = $up
        AppData          = $ad
        LocalAppData     = $lad
        Temp             = $tmp
        SkillsPath       = $sp
        Workspace        = $ws
        LegacyMaker      = $lm
        LegacyWorkbench  = $lw
        McpConfigPath    = Join-Path $up '.copilot\m-mcp-servers.json'
        LogPath          = Join-Path $up '.copilot\ai-maker\install-log.jsonl'
        # Snapshot of original env vars for restoration
        OrigUserProfile  = $env:USERPROFILE
        OrigAppData      = $env:APPDATA
        OrigLocalAppData = $env:LOCALAPPDATA
        OrigTemp         = $env:TEMP
        OrigTmp          = $env:TMP
    }
}

# ── Enter-InstallerSandbox ────────────────────────────────────────────────────

function Enter-InstallerSandbox {
    <#
    .SYNOPSIS
        Redirects USERPROFILE, APPDATA, LOCALAPPDATA, TEMP to sandbox dirs.
        Call before dot-sourcing ai-maker-lib.ps1 so AIMakerConfig path joins
        pick up the sandbox roots at source time.
    #>
    param([pscustomobject]$Sandbox)

    $env:USERPROFILE  = $Sandbox.UserProfile
    $env:APPDATA      = $Sandbox.AppData
    $env:LOCALAPPDATA = $Sandbox.LocalAppData
    $env:TEMP         = $Sandbox.Temp
    $env:TMP          = $Sandbox.Temp
}

# ── Exit-InstallerSandbox ─────────────────────────────────────────────────────

function Exit-InstallerSandbox {
    <#
    .SYNOPSIS
        Restores original USERPROFILE, APPDATA, LOCALAPPDATA, TEMP values.
    #>
    param([pscustomobject]$Sandbox)

    $env:USERPROFILE  = $Sandbox.OrigUserProfile
    $env:APPDATA      = $Sandbox.OrigAppData
    $env:LOCALAPPDATA = $Sandbox.OrigLocalAppData
    $env:TEMP         = $Sandbox.OrigTemp
    $env:TMP          = $Sandbox.OrigTmp
}

# ── Remove-InstallerSandbox ───────────────────────────────────────────────────

function Remove-InstallerSandbox {
    <#
    .SYNOPSIS
        Restores env vars and removes all sandbox directories.
    #>
    param([pscustomobject]$Sandbox)

    Exit-InstallerSandbox -Sandbox $Sandbox
    Remove-Item $Sandbox.Root -Recurse -Force -ErrorAction SilentlyContinue
}

# ── New-B2ProtectedZone ───────────────────────────────────────────────────────

function New-B2ProtectedZone {
    <#
    .SYNOPSIS
        Populates the B2 sandbox LegacyMaker directory with a representative set
        of protected files that the installer must NOT modify.

        Per FF's anti-vacuous-test rule: the protected zone must include at least one
        file exercising each FileStateEntry schema field:
          - ADS stream           (AdsNames test: stream removal would be caught)
          - Non-default ACL      (AclSddl test: ACL change would be caught)
          - Hardlink pair        (HardLinkCount test: link removal would be caught)
          - Read-only attribute  (basic preservation)
          - Regular files with known content (SHA256/size/timestamp)

    .PARAMETER Sandbox
        Sandbox context from New-InstallerSandbox.
    .OUTPUTS
        Hashtable: Root (the legacy-maker dir), SnapshotPath (for assertions),
        and file path info for each special-case file.
    #>
    param([pscustomobject]$Sandbox)

    $root = $Sandbox.LegacyMaker
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    # — Regular subdirectory structure ──────────────────────────────────
    foreach ($d in @('.github', 'agents', 'vault', 'vault/notes')) {
        New-Item -ItemType Directory -Path (Join-Path $root $d) -Force | Out-Null
    }

    # — Regular files ────────────────────────────────────────────────────
    $instFile = Join-Path $root '.github\copilot-instructions.md'
    Set-Content $instFile '# Old copilot instructions (protected)' -Encoding utf8

    $agentFile = Join-Path $root 'agents\my-agent.md'
    Set-Content $agentFile '# My legacy agent (protected)' -Encoding utf8

    $notesFile = Join-Path $root 'vault\notes\my-notes.md'
    Set-Content $notesFile "# Meeting notes`n- Discussed Q3 goals`n- Action: follow up" -Encoding utf8

    # — ADS-bearing file ─────────────────────────────────────────────────
    $adsFile = Join-Path $root 'vault\with-ads.md'
    Set-Content $adsFile '# Protected with ADS stream' -Encoding utf8
    Set-Content -LiteralPath $adsFile -Stream 'protected-marker' -Value 'do-not-touch'

    # — Non-default ACL file ─────────────────────────────────────────────
    $aclFile = Join-Path $root 'vault\acl-file.md'
    Set-Content $aclFile '# Protected with custom ACL' -Encoding utf8
    try {
        $acl = Get-Acl -LiteralPath $aclFile
        $networkSid = [System.Security.Principal.SecurityIdentifier]::new(
            [System.Security.Principal.WellKnownSidType]::NetworkSid, $null)
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $networkSid,
            [System.Security.AccessControl.FileSystemRights]::ReadAttributes,
            [System.Security.AccessControl.InheritanceFlags]::None,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule)
        Set-Acl -LiteralPath $aclFile -AclObject $acl
    } catch {
        # Non-fatal: harness will log as UNPROVEN if ACL not settable
    }

    # — Hardlink pair ────────────────────────────────────────────────────
    $hlOriginal = Join-Path $root 'vault\hardlink-original.md'
    $hlLink     = Join-Path $root 'vault\hardlink-link.md'
    Set-Content $hlOriginal '# Protected hardlink original' -Encoding utf8
    try {
        New-Item -ItemType HardLink -Path $hlLink -Target $hlOriginal -Force | Out-Null
    } catch {
        try { & fsutil hardlink create $hlLink $hlOriginal 2>&1 | Out-Null } catch {}
    }

    # — Read-only file ───────────────────────────────────────────────────
    $roFile = Join-Path $root 'vault\readonly.md'
    Set-Content $roFile '# Protected read-only file' -Encoding utf8
    Set-ItemProperty $roFile -Name IsReadOnly -Value $true

    return @{
        Root         = $root
        AdsFile      = $adsFile
        AclFile      = $aclFile
        HlOriginal   = $hlOriginal
        HlLink       = $hlLink
        ReadOnlyFile = $roFile
        AllFiles     = @($instFile, $agentFile, $notesFile, $adsFile, $aclFile, $hlOriginal, $hlLink, $roFile)
    }
}

# ── Invoke-SandboxBlueInstall ─────────────────────────────────────────────────

function Invoke-SandboxBlueInstall {
    <#
    .SYNOPSIS
        Runs the Blue installer's key file-operation steps inside the sandbox.

        Strategy:
        1. Copy ai-maker-lib.ps1 to sandbox root so $PSScriptRoot-based agents/
           fallback path resolves to our mock-content agents/ directory.
        2. Override $script:AIMakerConfig after sourcing to redirect hardcoded paths
           (WorkspacePath, LegacyMakerPath, LegacyWorkbenchPath) to sandbox.
        3. Override AgentsZipUrl to a non-routable address so the download fails
           fast and the fallback to $PSScriptRoot/agents fires immediately.
        4. Call New-WorkspaceScaffold and Install-Skills directly (lib functions).
        5. Write a synthetic m-mcp-servers.json to simulate the MCP registration
           step (which requires agency.exe — sandbox cannot run that).

    .PARAMETER Sandbox
        Sandbox context from New-InstallerSandbox.
    .PARAMETER MockContentRoot
        Path to mock-content/ dir. Defaults to module's sibling mock-content/.
    .OUTPUTS
        Hashtable with ExitCode, Workspace, SkillsPath, McpConfigPath.
    #>
    param(
        [pscustomobject]$Sandbox,
        [string]$MockContentRoot = $script:MockContent
    )

    $exitCode = 0
    $workspace = $Sandbox.Workspace
    try {
        # ── 1. Stage lib + mock agents in sandbox root ────────────────
        # New-WorkspaceScaffold uses $PSScriptRoot/agents as its local fallback.
        # By copying the lib to the sandbox and placing mock agents alongside it,
        # $PSScriptRoot inside the sourced lib = $Sandbox.Root, so the fallback
        # resolves to $Sandbox.Root/agents/ which we populate from mock-content.
        $libDst = Join-Path $Sandbox.Root 'ai-maker-lib.ps1'
        Copy-Item $script:LibPath $libDst -Force
        $agentsDst = Join-Path $Sandbox.Root 'agents'
        if (-not (Test-Path $agentsDst)) { New-Item -ItemType Directory -Path $agentsDst -Force | Out-Null }
        # Copy CONTENTS (not the directory itself) so repeated calls don't nest agents\agents\
        Get-ChildItem (Join-Path $MockContentRoot 'agents') | ForEach-Object {
            Copy-Item $_.FullName $agentsDst -Force
        }

        # ── 2. Source the lib (from sandbox so PSScriptRoot = Sandbox.Root) ──
        . $libDst

        # ── 3. Override config paths ──────────────────────────────────
        $script:AIMakerConfig.WorkspacePath      = $workspace
        $script:AIMakerConfig.LegacyMakerPath    = $Sandbox.LegacyMaker
        $script:AIMakerConfig.LegacyWorkbenchPath = $Sandbox.LegacyWorkbench
        $script:AIMakerConfig.SkillsPath         = $Sandbox.SkillsPath
        $script:AIMakerConfig.McpConfigPath      = $Sandbox.McpConfigPath
        $script:AIMakerConfig.LogPath            = $Sandbox.LogPath
        # Non-routable URL forces agents.zip download to fail fast → local fallback fires
        $script:AIMakerConfig.AgentsZipUrl       = 'https://sandbox.test.invalid/agents.zip'

        # ── 4. Scaffold workspace ─────────────────────────────────────
        New-WorkspaceScaffold -Pill 'blue'

        # ── 5. Install skills ─────────────────────────────────────────
        $mockSkills = Join-Path $MockContentRoot 'skills'
        Install-Skills -Pill 'blue' -SourcePath $mockSkills | Out-Null

        # ── 6. Simulate MCP registration (agency.exe cannot run in sandbox) ──
        # Write a valid m-mcp-servers.json so post-install MCP assertions have
        # something to validate. This mirrors what Register-AgencyMcpServers
        # writes, with Windows-legal command shapes (pwsh.exe, not /bin/sh).
        $mcpDir = Split-Path $Sandbox.McpConfigPath
        New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null
        $mcpConfig = @{
            servers = @{
                workiq   = @{ command = 'pwsh.exe'; args = @('-File', 'workiq-mcp.ps1') }
                bluebird = @{ command = 'pwsh.exe'; args = @('-File', 'bluebird-mcp.ps1') }
            }
        }
        $mcpConfig | ConvertTo-Json -Depth 5 | Set-Content $Sandbox.McpConfigPath -Encoding utf8
    }
    catch {
        $exitCode = 1
        Write-Warning "Invoke-SandboxBlueInstall: $($_.Exception.Message)"
    }

    return @{
        ExitCode      = $exitCode
        Workspace     = $workspace
        SkillsPath    = $Sandbox.SkillsPath
        McpConfigPath = $Sandbox.McpConfigPath
    }
}

# ── Invoke-SandboxRedInstall ──────────────────────────────────────────────────

function Invoke-SandboxRedInstall {
    <#
    .SYNOPSIS
        Runs the Red installer's key file-operation steps inside the sandbox.
        Mirrors Invoke-SandboxBlueInstall with Pill = 'red'.
        Red pill additionally creates vault\workbench.
    .PARAMETER Sandbox
        Sandbox context from New-InstallerSandbox.
    .PARAMETER MockContentRoot
        Path to mock-content/ dir. Defaults to module's sibling mock-content/.
    .OUTPUTS
        Hashtable with ExitCode, Workspace, SkillsPath, McpConfigPath.
    #>
    param(
        [pscustomobject]$Sandbox,
        [string]$MockContentRoot = $script:MockContent
    )

    $exitCode = 0
    $workspace = $Sandbox.Workspace
    try {
        $libDst = Join-Path $Sandbox.Root 'ai-maker-lib.ps1'
        Copy-Item $script:LibPath $libDst -Force
        $agentsDst = Join-Path $Sandbox.Root 'agents'
        if (-not (Test-Path $agentsDst)) { New-Item -ItemType Directory -Path $agentsDst -Force | Out-Null }
        Get-ChildItem (Join-Path $MockContentRoot 'agents') | ForEach-Object {
            Copy-Item $_.FullName $agentsDst -Force
        }
        . $libDst
        $script:AIMakerConfig.WorkspacePath       = $workspace
        $script:AIMakerConfig.LegacyMakerPath     = $Sandbox.LegacyMaker
        $script:AIMakerConfig.LegacyWorkbenchPath = $Sandbox.LegacyWorkbench
        $script:AIMakerConfig.SkillsPath          = $Sandbox.SkillsPath
        $script:AIMakerConfig.McpConfigPath       = $Sandbox.McpConfigPath
        $script:AIMakerConfig.LogPath             = $Sandbox.LogPath
        $script:AIMakerConfig.AgentsZipUrl        = 'https://sandbox.test.invalid/agents.zip'
        New-WorkspaceScaffold -Pill 'red'
        $mockSkills = Join-Path $MockContentRoot 'skills'
        Install-Skills -Pill 'red' -SourcePath $mockSkills | Out-Null
        $mcpDir = Split-Path $Sandbox.McpConfigPath
        New-Item -ItemType Directory -Path $mcpDir -Force | Out-Null
        $mcpConfig = @{
            servers = @{
                workiq   = @{ command = 'pwsh.exe'; args = @('-File', 'workiq-mcp.ps1') }
                bluebird = @{ command = 'pwsh.exe'; args = @('-File', 'bluebird-mcp.ps1') }
            }
        }
        $mcpConfig | ConvertTo-Json -Depth 5 | Set-Content $Sandbox.McpConfigPath -Encoding utf8
    }
    catch {
        $exitCode = 1
        Write-Warning "Invoke-SandboxRedInstall: $($_.Exception.Message)"
    }

    return @{
        ExitCode      = $exitCode
        Workspace     = $workspace
        SkillsPath    = $Sandbox.SkillsPath
        McpConfigPath = $Sandbox.McpConfigPath
    }
}

# ── Test-PillPurity ───────────────────────────────────────────────────────────

function Test-PillPurity {
    <#
    .SYNOPSIS
        Recursively greps a directory for pill-identity contamination.
        Returns a list of violations: @{ Path; LineNumber; MatchedText }.
    .PARAMETER Root
        Directory to scan.
    .PARAMETER ForbiddenPatterns
        Array of regex strings. Defaults to the Blue-pill forbidden list from PRD §4.1 #2.
    .PARAMETER ForbiddenPathSubstrings
        Array of path-component substrings that must not appear in any relative path.
    #>
    param(
        [string]$Root,
        [string[]]$ForbiddenPatterns = @('\bworkbench\b','red[- ]pill','install-red','AIWorkbench','That''s AI workbench territory'),
        [string[]]$ForbiddenPathSubstrings = @('workbench','install-red','ai-workbench'),
        # Paths (relative, forward-slash) excluded from content scan but NOT from path scan.
        # vault/README.md is excluded by default: it's structural documentation that legitimately
        # describes the workbench vault area even in Blue-pill installs.
        [string[]]$ExcludeFromContentScan = @('vault/README.md')
    )

    $violations = @()

    if (-not (Test-Path $Root)) { return $violations }

    $rootFull = (Get-Item -LiteralPath $Root -Force).FullName.TrimEnd('\')
    $files = Get-ChildItem $rootFull -Recurse -File -EA SilentlyContinue

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($rootFull.Length).TrimStart('\').Replace('\','/')

        # Path-component check
        foreach ($sub in $ForbiddenPathSubstrings) {
            if ($rel -imatch [regex]::Escape($sub)) {
                $violations += @{ Path = $rel; LineNumber = 0; MatchedText = "path contains '$sub'" }
            }
        }

        # Content check (text files only)
        $ext = $f.Extension.ToLower()
        $skipContent = $ExcludeFromContentScan | Where-Object { $rel -ieq $_.Replace('\','/') }
        if ($skipContent) { continue }
        if ($ext -in @('.md','.txt','.json','.ps1','.psm1','.yaml','.yml','.xml','.html','.htm','.js','.ts','.bat','.cmd')) {
            try {
                $lines = Get-Content $f.FullName -Encoding utf8 -EA SilentlyContinue
                if ($null -eq $lines) { continue }
                $lineNum = 0
                foreach ($line in $lines) {
                    $lineNum++
                    foreach ($pat in $ForbiddenPatterns) {
                        if ($line -imatch $pat) {
                            $violations += @{ Path = $rel; LineNumber = $lineNum; MatchedText = $line.Trim() }
                        }
                    }
                }
            } catch {}
        }
    }

    return $violations
}

# ── Assert-RequiredArtifacts ──────────────────────────────────────────────────

function Assert-RequiredArtifacts {
    <#
    .SYNOPSIS
        Verifies that all expected paths exist under Workspace and SkillsPath.
        Returns a hashtable: Passed (bool), Missing (string[]).
    #>
    param(
        [string]$Workspace,
        [string]$SkillsPath,
        [string[]]$ExpectedWorkspacePaths,
        [string[]]$ExpectedWorkspaceDirs,
        [int]$ExpectedMinSkillCount = 1,
        [string]$ExpectedSkillPrefix = 'ai-maker-'
    )

    $missing = @()

    foreach ($rel in $ExpectedWorkspacePaths) {
        $abs = Join-Path $Workspace ($rel.Replace('/', '\'))
        if (-not (Test-Path $abs)) { $missing += $rel }
    }

    foreach ($rel in $ExpectedWorkspaceDirs) {
        $abs = Join-Path $Workspace ($rel.Replace('/', '\'))
        if (-not (Test-Path $abs -PathType Container)) { $missing += "$rel (directory)" }
    }

    $skillCount = (Get-ChildItem $SkillsPath -Directory -Filter "$ExpectedSkillPrefix*" -EA SilentlyContinue).Count
    if ($skillCount -lt $ExpectedMinSkillCount) {
        $missing += "at least $ExpectedMinSkillCount $ExpectedSkillPrefix skill(s) in SkillsPath"
    }

    return @{
        Passed  = ($missing.Count -eq 0)
        Missing = $missing
    }
}

Export-ModuleMember -Function @(
    'New-InstallerSandbox',
    'Enter-InstallerSandbox',
    'Exit-InstallerSandbox',
    'Remove-InstallerSandbox',
    'New-B2ProtectedZone',
    'Invoke-SandboxBlueInstall',
    'Invoke-SandboxRedInstall',
    'Test-PillPurity',
    'Assert-RequiredArtifacts'
)
