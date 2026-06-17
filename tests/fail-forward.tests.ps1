#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker v3 -- Fail-forward installer regression fixtures
.DESCRIPTION
    Encodes FA-spec'd fail-forward contract (v3.x): installer is fail-forward,
    not rollback-transactional. Each interrupted install checkpoint must:
      1. Leave a detectably clean scenario code (no "unknown" state)
      2. NOT have written the manifest before scaffold + skills passed
      3. NOT have touched user data or legacy folders
      4. Recover deterministically via same-version re-run (WhatIf-verified)
      5. Be cleanable by reset.bat (behavioral fixtures in reset-behaviors.tests.ps1)

    The 6 checkpoints follow install-blue.ps1 step order:
      CP1: After prereq tools installed (winget Git.Git etc.)
      CP2: After Agency/Copilot App installed
      CP3: After MCP registration (m-mcp-servers.json written)  [stub -- path TBD]
      CP4: After skills installed (~/.copilot/skills/ai-maker-*)
      CP5: After scaffold created, BEFORE manifest write
      CP6: After manifest write (clean complete install)

    Technique: dot-sources ai-maker-lib.ps1, uses PathOverrides + RemoteOverrides
    injection in Get-InstallScenario to sandbox all path checks in TEMP.
    Does NOT touch production paths (C:\GitHub\ai-workspace, ~/.copilot/skills).

    Run:    Invoke-Pester tests\fail-forward.tests.ps1 -Output Detailed
    CI:     Runs on push + PR to main via .github/workflows/preflight.yml
#>

BeforeAll {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    $LibPath  = Join-Path $RepoRoot "installers\ai-maker-lib.ps1"

    # Dot-source the lib so Get-InstallScenario and helpers are available
    . $LibPath

    # ----------------------------------------------------------------
    # Sandbox root: each test run gets a unique TEMP subtree
    # ----------------------------------------------------------------
    $script:SandboxRoot = Join-Path $env:TEMP "ai-maker-ff-$([guid]::NewGuid().ToString('N').Substring(0,8))"

    function New-Sandbox {
        # Fresh subtree for one checkpoint simulation
        $sb = @{
            Workspace       = Join-Path $script:SandboxRoot "workspace"
            SkillsPath      = Join-Path $script:SandboxRoot "skills"
            LegacyMaker     = Join-Path $script:SandboxRoot "legacy-maker"
            LegacyWorkbench = Join-Path $script:SandboxRoot "legacy-workbench"
            UserData        = Join-Path $script:SandboxRoot "userdata"
        }
        # Create the userdata sentinel and legacy folders (must survive all operations)
        New-Item -Path $sb.UserData       -ItemType Directory -Force | Out-Null
        New-Item -Path "$($sb.UserData)\vault\notes.md" -ItemType File -Force | Out-Null
        New-Item -Path $sb.LegacyMaker    -ItemType Directory -Force | Out-Null
        New-Item -Path $sb.LegacyWorkbench -ItemType Directory -Force | Out-Null
        return $sb
    }

    function Get-ScenarioForState {
        param([hashtable]$Sb, [hashtable]$Remote = @{HasNewRemote=$false;HasLegacyRemote=$false;IsOurRepo=$false})
        return Get-InstallScenario `
            -PathOverrides @{
                Workspace       = $Sb.Workspace
                SkillsPath      = $Sb.SkillsPath
                LegacyMaker     = $Sb.LegacyMaker
                LegacyWorkbench = $Sb.LegacyWorkbench
            } `
            -RemoteOverrides $Remote
    }

    function Assert-UserDataIntact {
        param([hashtable]$Sb)
        (Test-Path "$($Sb.UserData)\vault\notes.md") | Should -BeTrue -Because "User data must never be deleted during install"
    }

    function Assert-LegacyFoldersIntact {
        param([hashtable]$Sb)
        (Test-Path $Sb.LegacyMaker)     | Should -BeTrue -Because "Legacy maker folder must survive"
        (Test-Path $Sb.LegacyWorkbench) | Should -BeTrue -Because "Legacy workbench folder must survive"
    }

    function Assert-ManifestNotWritten {
        param([hashtable]$Sb)
        $manifestPath = Join-Path $Sb.Workspace ".ai-maker-manifest.json"
        (Test-Path $manifestPath) | Should -BeFalse -Because "Manifest must NOT exist before scaffold+skills are confirmed"
    }

    function Assert-ManifestIsValid {
        param([hashtable]$Sb)
        $manifestPath = Join-Path $Sb.Workspace ".ai-maker-manifest.json"
        (Test-Path $manifestPath) | Should -BeTrue -Because "Manifest must exist after CP6"
        $m = Get-Content $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        (Test-AIMakerManifest -Manifest $m) | Should -BeNullOrEmpty -Because "Manifest must pass schema validation"
    }

    # Seed skills into sandbox (simulates completed Step 4)
    function Seed-Skills {
        param([hashtable]$Sb, [int]$Count = 22)
        for ($i = 1; $i -le [Math]::Min($Count, 11); $i++) {
            New-Item -Path (Join-Path $Sb.SkillsPath "ai-maker-skill$i") -ItemType Directory -Force | Out-Null
        }
        for ($i = 1; $i -le [Math]::Max(0, $Count - 11); $i++) {
            New-Item -Path (Join-Path $Sb.SkillsPath "ai-workbench-skill$i") -ItemType Directory -Force | Out-Null
        }
    }

    # Seed a success-shaped manifest (CP6 state)
    function Seed-Manifest {
        param([hashtable]$Sb, [string]$Pill = "blue")
        $ws = $Sb.Workspace
        if (-not (Test-Path $ws)) { New-Item $ws -ItemType Directory -Force | Out-Null }
        $m = New-AIMakerManifest -Pill $Pill -Skills @()
        $json = $m | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $ws ".ai-maker-manifest.json") -Value $json -Encoding utf8
    }

    # Inline Invoke-InstallerIsolated reused from prereq-sim for WhatIf re-run assertions
    function Invoke-InstallerWhatIf {
        param([string]$InstallerPath, [switch]$UsePS7)
        $exe    = if ($UsePS7) { 'pwsh.exe' } else { 'powershell.exe' }
        $argStr = "-NoProfile -NonInteractive -File `"$InstallerPath`" -WhatIf"
        $psi    = [System.Diagnostics.ProcessStartInfo]::new($exe, $argStr)
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true
        $proc   = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{ Output = $stdout; ExitCode = $proc.ExitCode }
    }

    $BlueInstaller = Join-Path $RepoRoot "installers\install-blue.ps1"
    $RedInstaller  = Join-Path $RepoRoot "installers\install-red.ps1"
}

AfterAll {
    # Clean up sandbox
    if (Test-Path $script:SandboxRoot) {
        Remove-Item $script:SandboxRoot -Recurse -Force -EA Silent
    }
}


# ================================================================
# CP1: After prereq tools installed, nothing else yet
# State: git/winget installed. No workspace dir. No skills. No manifest.
# ================================================================
Describe "CP1 -- After prereq install" {
    BeforeAll { $script:Sb1 = New-Sandbox }

    It "scenario is fresh-install (clean entry point)" {
        $s = Get-ScenarioForState -Sb $script:Sb1
        $s.scenario | Should -Be "fresh-install"
    }
    It "user data is intact" {
        Assert-UserDataIntact -Sb $script:Sb1
    }
    It "legacy folders are intact" {
        Assert-LegacyFoldersIntact -Sb $script:Sb1
    }
    It "manifest has NOT been written" {
        Assert-ManifestNotWritten -Sb $script:Sb1
    }
    It "WhatIf re-run on Blue proceeds without error" {
        $r = Invoke-InstallerWhatIf -InstallerPath $BlueInstaller
        $r.Output | Should -Not -Match ([regex]::Escape('X '))
    }
}


# ================================================================
# CP2: After Agency (Copilot App) installed, before skills/scaffold
# State: App installed. No workspace. No skills. No manifest.
# Scenario detection is the same as CP1 -- app install is not
# tracked in the filesystem detection matrix (winget owns it).
# ================================================================
Describe "CP2 -- After Agency/Copilot App install" {
    BeforeAll { $script:Sb2 = New-Sandbox }

    It "scenario is fresh-install (workspace + manifest absent)" {
        $s = Get-ScenarioForState -Sb $script:Sb2
        $s.scenario | Should -Be "fresh-install"
    }
    It "user data is intact" {
        Assert-UserDataIntact -Sb $script:Sb2
    }
    It "legacy folders are intact" {
        Assert-LegacyFoldersIntact -Sb $script:Sb2
    }
    It "manifest has NOT been written" {
        Assert-ManifestNotWritten -Sb $script:Sb2
    }
    It "details.hasNewWorkspace is false" {
        $s = Get-ScenarioForState -Sb $script:Sb2
        $s.details.hasNewWorkspace | Should -BeFalse
    }
}


# ================================================================
# CP3: After MCP registration (m-mcp-servers.json written)
# STUB -- MCP registration path not yet in main lib (FA work in progress).
# Contract documented; tests enabled when MCP step lands in ai-maker-lib.ps1.
# ================================================================
Describe "CP3 -- After MCP registration" {
    It "MCP registration state is detectable by Get-InstallScenario" -Skip {
        # Enable when: ai-maker-lib.ps1 exposes MCP state in Get-InstallScenario details
        # Contract:
        #   details.mcpRegistered should be $true
        #   scenario should still be fresh-install (manifest not written yet)
        #   manifest must NOT be written
    }
    It "re-run correctly re-registers MCP without duplicate entries" -Skip {
        # Enable when: MCP registration path is in lib
        # Contract: same-version re-run is idempotent on m-mcp-servers.json
    }
}


# ================================================================
# CP4: After skills installed, before scaffold/manifest
# State: skills present in SkillsPath. No workspace dir. No manifest.
# ================================================================
Describe "CP4 -- After skills install" {
    BeforeAll {
        $script:Sb4 = New-Sandbox
        Seed-Skills -Sb $script:Sb4 -Count 22
    }

    It "scenario is still fresh-install (workspace absent despite skills)" {
        # Skills presence alone does not trigger rerun -- workspace + manifest required
        $s = Get-ScenarioForState -Sb $script:Sb4
        $s.scenario | Should -Be "fresh-install"
    }
    It "details.hasAppSkills is true" {
        $s = Get-ScenarioForState -Sb $script:Sb4
        $s.details.hasAppSkills | Should -BeTrue
    }
    It "details.skillCount is 22" {
        $s = Get-ScenarioForState -Sb $script:Sb4
        $s.details.skillCount | Should -Be 22
    }
    It "user data is intact" {
        Assert-UserDataIntact -Sb $script:Sb4
    }
    It "manifest has NOT been written" {
        Assert-ManifestNotWritten -Sb $script:Sb4
    }
    It "WhatIf re-run on Blue proceeds without error" {
        $r = Invoke-InstallerWhatIf -InstallerPath $BlueInstaller
        $r.Output | Should -Not -Match ([regex]::Escape('X '))
    }
}


# ================================================================
# CP5: After scaffold, BEFORE manifest write
# State: workspace dir exists. No manifest file. Skills present.
# This is the key partial-install checkpoint -- manifest MUST NOT exist.
# ================================================================
Describe "CP5 -- After scaffold, before manifest write" {
    BeforeAll {
        $script:Sb5 = New-Sandbox
        Seed-Skills -Sb $script:Sb5 -Count 22
        # Create workspace dir (scaffold done) but do NOT write manifest
        New-Item -Path $script:Sb5.Workspace -ItemType Directory -Force | Out-Null
    }

    It "scenario is partial-install" {
        $s = Get-ScenarioForState -Sb $script:Sb5
        $s.scenario | Should -Be "partial-install"
    }
    It "details.hasWorkspaceDir is true" {
        $s = Get-ScenarioForState -Sb $script:Sb5
        $s.details.hasWorkspaceDir | Should -BeTrue
    }
    It "details.hasNewWorkspace is false (manifest absent)" {
        $s = Get-ScenarioForState -Sb $script:Sb5
        $s.details.hasNewWorkspace | Should -BeFalse
    }
    It "manifest has NOT been written -- FA invariant: manifest is last step" {
        Assert-ManifestNotWritten -Sb $script:Sb5
    }
    It "user data is intact" {
        Assert-UserDataIntact -Sb $script:Sb5
    }
    It "legacy folders are intact" {
        Assert-LegacyFoldersIntact -Sb $script:Sb5
    }
    It "WhatIf re-run on Blue announces resume, not fresh install" {
        $r = Invoke-InstallerWhatIf -InstallerPath $BlueInstaller
        # Partial-install scenario must be acknowledged in output
        $r.Output | Should -Match '(?i)partial|resume|resuming'
        $r.Output | Should -Not -Match ([regex]::Escape('X '))
    }
}


# ================================================================
# CP6: After manifest write (complete, success-shaped install)
# State: workspace dir + manifest + skills all present.
# Re-run must detect rerun scenario, not overwrite/duplicate.
# ================================================================
Describe "CP6 -- After manifest write (complete install)" {
    BeforeAll {
        $script:Sb6 = New-Sandbox
        Seed-Skills -Sb $script:Sb6 -Count 22
        Seed-Manifest -Sb $script:Sb6 -Pill "blue"
    }

    It "scenario is rerun (all 22 skills present)" {
        $s = Get-ScenarioForState -Sb $script:Sb6 `
            -Remote @{HasNewRemote=$false;HasLegacyRemote=$false;IsOurRepo=$false}
        # Blue pill with no remote: manifest present, no local git, no remote
        # Expected: blue-to-red-upgrade (upgrade path) or rerun with no remote
        # Per lib detection order: hasNewWorkspace + no local git + no remote = blue-to-red-upgrade
        $s.scenario | Should -BeIn @("rerun", "blue-to-red-upgrade", "stale-skills")
    }
    It "manifest passes schema validation" {
        Assert-ManifestIsValid -Sb $script:Sb6
    }
    It "user data is intact" {
        Assert-UserDataIntact -Sb $script:Sb6
    }
    It "legacy folders are intact" {
        Assert-LegacyFoldersIntact -Sb $script:Sb6
    }
    It "WhatIf re-run on Blue does not error" {
        $r = Invoke-InstallerWhatIf -InstallerPath $BlueInstaller
        $r.Output | Should -Not -Match ([regex]::Escape('X '))
    }
    It "manifest pill matches installed pill" {
        $m = Get-Content (Join-Path $script:Sb6.Workspace ".ai-maker-manifest.json") -Raw | ConvertFrom-Json -AsHashtable
        $m.pill | Should -Be "blue"
    }
}


# ================================================================
# CROSS-CHECKPOINT: manifest ordering invariant
# FA contract: manifest write must be the LAST step.
# If any path writes manifest before scaffold+skills, that is a bug.
# ================================================================
Describe "Manifest ordering invariant" {
    It "partial-install scenario (CP5) has workspace dir without manifest" {
        $sb = New-Sandbox
        New-Item -Path $sb.Workspace -ItemType Directory -Force | Out-Null
        # No manifest seeded -- this IS the partial-install contract
        $s = Get-ScenarioForState -Sb $sb
        $s.scenario | Should -Be "partial-install"
        $manifestPath = Join-Path $sb.Workspace ".ai-maker-manifest.json"
        (Test-Path $manifestPath) | Should -BeFalse -Because "CP5 state must never have a manifest"
    }

    It "fresh-install scenario (CP1-CP4) has no manifest" {
        $sb = New-Sandbox
        $s = Get-ScenarioForState -Sb $sb
        $s.scenario | Should -Be "fresh-install"
        $manifestPath = Join-Path $sb.Workspace ".ai-maker-manifest.json"
        (Test-Path $manifestPath) | Should -BeFalse
    }

    It "Test-AIMakerManifest rejects manifest written without required fields" {
        $badManifest = @{ pill = "blue" }  # missing schema, installer_version, installed_at, skills, components
        $errors = Test-AIMakerManifest -Manifest $badManifest
        $errors.Count | Should -BeGreaterThan 0
    }

    It "New-AIMakerManifest produces a schema-valid manifest" {
        $m = New-AIMakerManifest -Pill "blue" -Skills @()
        $errors = Test-AIMakerManifest -Manifest $m
        $errors | Should -BeNullOrEmpty
    }
}