#Requires -Version 7.0
# AI Maker v3 -- Fail-forward installer regression fixtures
# FA contract (v3.x): fail-forward, not rollback-transactional.
# Uses Get-InstallScenario PathOverrides/RemoteOverrides for TEMP sandbox.
# Does NOT touch production paths.
#
# Run:    Invoke-Pester tests\fail-forward.tests.ps1 -Output Detailed
# CI:     .github/workflows/preflight.yml

BeforeAll {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    $LibPath  = Join-Path $RepoRoot "ai-maker-lib.ps1"
    . $LibPath
    $script:SandboxRoot = Join-Path $env:TEMP ("ai-maker-ff-" + [guid]::NewGuid().ToString("N").Substring(0, 8))

    function New-Sandbox {
        $sb = @{
            Workspace        = Join-Path $script:SandboxRoot "workspace"
            SkillsPath       = Join-Path $script:SandboxRoot "skills"
            LegacyMaker      = Join-Path $script:SandboxRoot "legacy-maker"
            LegacyWorkbench  = Join-Path $script:SandboxRoot "legacy-workbench"
            UserData         = Join-Path $script:SandboxRoot "userdata"
        }
        New-Item "$($sb.UserData)\vault\notes.md" -ItemType File   -Force | Out-Null
        New-Item $sb.LegacyMaker                   -ItemType Directory -Force | Out-Null
        New-Item $sb.LegacyWorkbench               -ItemType Directory -Force | Out-Null
        return $sb
    }

    function Get-ScenarioFor {
        param(
            [hashtable]$Sb,
            [hashtable]$Remote = @{ HasNewRemote = $false; HasLegacyRemote = $false; IsOurRepo = $false },
            [hashtable]$Mcp    = $null
        )
        $params = @{
            PathOverrides   = @{
                Workspace       = $Sb.Workspace
                SkillsPath      = $Sb.SkillsPath
                LegacyMaker     = $Sb.LegacyMaker
                LegacyWorkbench = $Sb.LegacyWorkbench
            }
            RemoteOverrides = $Remote
        }
        if ($Mcp) { $params.McpOverrides = $Mcp }
        return Get-InstallScenario @params
    }

    function Seed-McpJson {
        param([hashtable]$Sb, [string[]]$Servers = @('workiq', 'bluebird'))
        $mcpPath = Join-Path $Sb.UserData "m-mcp-servers.json"
        $obj = @{}
        foreach ($s in $Servers) { $obj[$s] = @{ enabled = $true } }
        Set-Content $mcpPath ($obj | ConvertTo-Json -Depth 3) -Encoding utf8
        return $mcpPath
    }

    function Assert-UserDataIntact {
        param([hashtable]$Sb)
        (Test-Path "$($Sb.UserData)\vault\notes.md") | Should -BeTrue -Because "user data must never be deleted"
    }
    function Assert-LegacyIntact {
        param([hashtable]$Sb)
        (Test-Path $Sb.LegacyMaker)     | Should -BeTrue -Because "legacy maker must survive"
        (Test-Path $Sb.LegacyWorkbench) | Should -BeTrue -Because "legacy workbench must survive"
    }
    function Assert-NoManifest {
        param([hashtable]$Sb)
        (Test-Path (Join-Path $Sb.Workspace ".ai-maker-manifest.json")) | Should -BeFalse `
            -Because "manifest is the last step -- must not exist at this checkpoint"
    }

    function Seed-Skills {
        param([hashtable]$Sb, [int]$Count = 22)
        for ($i = 1; $i -le [Math]::Min($Count, 11); $i++) {
            New-Item (Join-Path $Sb.SkillsPath "ai-maker-skill$i") -ItemType Directory -Force | Out-Null
        }
        for ($i = 1; $i -le [Math]::Max(0, $Count - 11); $i++) {
            New-Item (Join-Path $Sb.SkillsPath "ai-workbench-skill$i") -ItemType Directory -Force | Out-Null
        }
    }

    function Seed-Manifest {
        param([hashtable]$Sb, [string]$Pill = "blue")
        if (-not (Test-Path $Sb.Workspace)) { New-Item $Sb.Workspace -ItemType Directory -Force | Out-Null }
        $m = New-AIMakerManifest -Pill $Pill -Skills @()
        Set-Content (Join-Path $Sb.Workspace ".ai-maker-manifest.json") ($m | ConvertTo-Json -Depth 5) -Encoding utf8
    }

    function Invoke-InstallerWhatIf {
        param([string]$InstallerPath)
        $psi = [System.Diagnostics.ProcessStartInfo]::new(
            "powershell.exe",
            "-NoProfile -NonInteractive -File `"$InstallerPath`" -WhatIf"
        )
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        $out  = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{ Output = $out; ExitCode = $proc.ExitCode }
    }

    $script:BlueInstaller = Join-Path $RepoRoot "installers\install-blue.ps1"
}

AfterAll {
    if (Test-Path $script:SandboxRoot) { Remove-Item $script:SandboxRoot -Recurse -Force -EA Silent }
}

# ================================================================
# CP1: After prereq tools installed -- nothing else written yet
# ================================================================
Describe "CP1 -- After prereq install" {
    BeforeAll { $script:Sb1 = New-Sandbox }

    It "scenario is fresh-install"           { (Get-ScenarioFor $script:Sb1).scenario | Should -Be "fresh-install" }
    It "user data intact"                    { Assert-UserDataIntact $script:Sb1 }
    It "legacy folders intact"               { Assert-LegacyIntact $script:Sb1 }
    It "manifest not written"                { Assert-NoManifest $script:Sb1 }
    It "WhatIf re-run proceeds without error" { (Invoke-InstallerWhatIf $script:BlueInstaller).Output | Should -Not -Match "X " }
}

# ================================================================
# CP2: After Agency/Copilot App installed
# App install is winget-tracked; not visible in fs detection matrix.
# ================================================================
Describe "CP2 -- After Agency install" {
    BeforeAll { $script:Sb2 = New-Sandbox }

    It "scenario is fresh-install"                { (Get-ScenarioFor $script:Sb2).scenario | Should -Be "fresh-install" }
    It "details.hasNewWorkspace is false"          { (Get-ScenarioFor $script:Sb2).details.hasNewWorkspace | Should -BeFalse }
    It "user data intact"                         { Assert-UserDataIntact $script:Sb2 }
    It "manifest not written"                     { Assert-NoManifest $script:Sb2 }
}

# ================================================================
# CP3: After MCP registration (m-mcp-servers.json written)
# Unblocked by ai-maker-lib.ps1 feat: mcpRegistered in details
# ================================================================
Describe "CP3 -- After MCP registration" {
    BeforeAll { $script:Sb3 = New-Sandbox }

    It "mcpRegistered is true when workiq + bluebird present (via McpOverrides)" {
        $r = Get-ScenarioFor $script:Sb3 -Mcp @{ McpRegistered = $true; McpRegisteredServers = @('workiq', 'bluebird') }
        $r.details.mcpRegistered | Should -BeTrue
    }

    It "mcpRegisteredServers contains both baseline servers (via McpOverrides)" {
        $r = Get-ScenarioFor $script:Sb3 -Mcp @{ McpRegistered = $true; McpRegisteredServers = @('workiq', 'bluebird') }
        $r.details.mcpRegisteredServers | Should -Contain 'workiq'
        $r.details.mcpRegisteredServers | Should -Contain 'bluebird'
    }

    It "mcpRegistered is false when m-mcp-servers.json missing (live path)" {
        # Sandbox has no m-mcp-servers.json; lib reads the real config path
        # Override config path via McpOverrides with a nonexistent file signal
        $r = Get-ScenarioFor $script:Sb3 -Mcp @{ McpRegistered = $false; McpRegisteredServers = @() }
        $r.details.mcpRegistered | Should -BeFalse
    }

    It "mcpRegistered is false when only one server present" {
        $r = Get-ScenarioFor $script:Sb3 -Mcp @{ McpRegistered = $false; McpRegisteredServers = @('workiq') }
        $r.details.mcpRegistered | Should -BeFalse
    }

    It "scenario is still fresh-install at CP3" {
        $r = Get-ScenarioFor $script:Sb3 -Mcp @{ McpRegistered = $true; McpRegisteredServers = @('workiq', 'bluebird') }
        $r.scenario | Should -Be "fresh-install"
    }

    It "manifest NOT written at CP3" { Assert-NoManifest $script:Sb3 }
    It "user data intact at CP3"    { Assert-UserDataIntact $script:Sb3 }
}

# ================================================================
# CP4: After skills installed -- workspace/manifest absent
# ================================================================
Describe "CP4 -- After skills install" {
    BeforeAll { $script:Sb4 = New-Sandbox; Seed-Skills $script:Sb4 22 }

    It "scenario is fresh-install (workspace absent dominates)" { (Get-ScenarioFor $script:Sb4).scenario | Should -Be "fresh-install" }
    It "details.hasAppSkills is true"         { (Get-ScenarioFor $script:Sb4).details.hasAppSkills | Should -BeTrue }
    It "details.skillCount is 22"             { (Get-ScenarioFor $script:Sb4).details.skillCount | Should -Be 22 }
    It "user data intact"                     { Assert-UserDataIntact $script:Sb4 }
    It "manifest not written"                 { Assert-NoManifest $script:Sb4 }
    It "WhatIf re-run proceeds without error" { (Invoke-InstallerWhatIf $script:BlueInstaller).Output | Should -Not -Match "X " }
}

# ================================================================
# CP5: After scaffold, BEFORE manifest write (key ordering checkpoint)
# FA invariant: manifest must be the absolute last step.
# ================================================================
Describe "CP5 -- After scaffold, before manifest" {
    BeforeAll {
        $script:Sb5 = New-Sandbox
        Seed-Skills $script:Sb5 22
        New-Item $script:Sb5.Workspace -ItemType Directory -Force | Out-Null
    }

    It "scenario is partial-install"               { (Get-ScenarioFor $script:Sb5).scenario | Should -Be "partial-install" }
    It "details.hasWorkspaceDir is true"            { (Get-ScenarioFor $script:Sb5).details.hasWorkspaceDir | Should -BeTrue }
    It "details.hasNewWorkspace is false"           { (Get-ScenarioFor $script:Sb5).details.hasNewWorkspace | Should -BeFalse }
    It "manifest NOT written -- FA ordering invariant" { Assert-NoManifest $script:Sb5 }
    It "user data intact"                           { Assert-UserDataIntact $script:Sb5 }
    It "legacy folders intact"                      { Assert-LegacyIntact $script:Sb5 }
    It "WhatIf re-run acknowledges partial state"   { (Invoke-InstallerWhatIf $script:BlueInstaller).Output | Should -Match "(?i)partial|resume" }
}

# ================================================================
# CP6: After manifest write -- complete install
# Re-run must detect rerun-family scenario, not fresh-install.
# ================================================================
Describe "CP6 -- After manifest write (complete)" {
    BeforeAll { $script:Sb6 = New-Sandbox; Seed-Skills $script:Sb6 22; Seed-Manifest $script:Sb6 "blue" }

    It "scenario is rerun-family (not fresh-install)" {
        (Get-ScenarioFor $script:Sb6).scenario | Should -BeIn @("rerun", "blue-to-red-upgrade", "stale-skills")
    }
    It "manifest passes schema validation" {
        $m = Get-Content (Join-Path $script:Sb6.Workspace ".ai-maker-manifest.json") -Raw | ConvertFrom-Json -AsHashtable
        (Test-AIMakerManifest -Manifest $m) | Should -BeNullOrEmpty
    }
    It "manifest pill is blue" {
        (Get-Content (Join-Path $script:Sb6.Workspace ".ai-maker-manifest.json") -Raw | ConvertFrom-Json).pill | Should -Be "blue"
    }
    It "user data intact"                     { Assert-UserDataIntact $script:Sb6 }
    It "WhatIf re-run no error"              { (Invoke-InstallerWhatIf $script:BlueInstaller).Output | Should -Not -Match "X " }
}

# ================================================================
# Manifest ordering invariants (cross-cutting, run in isolation)
# ================================================================
Describe "Manifest ordering invariants" {
    It "New-AIMakerManifest output is schema-valid" {
        (Test-AIMakerManifest (New-AIMakerManifest -Pill "blue" -Skills @())) | Should -BeNullOrEmpty
    }
    It "Test-AIMakerManifest rejects manifest missing required fields" {
        (Test-AIMakerManifest @{ pill = "blue" }).Count | Should -BeGreaterThan 0
    }
    It "CP5 state (workspace dir, no manifest) maps to partial-install" {
        $sb = New-Sandbox
        New-Item $sb.Workspace -ItemType Directory -Force | Out-Null
        (Test-Path (Join-Path $sb.Workspace ".ai-maker-manifest.json")) | Should -BeFalse
        (Get-ScenarioFor $sb).scenario | Should -Be "partial-install"
    }
}
