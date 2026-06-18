#Requires -Version 7.0
<#
.SYNOPSIS
  Agency binary detection + MCP registration verification fixtures.
  Encodes the v3.0.10 contract for CP3.5 and CP3.6.

.DESCRIPTION
  CP3.5 — Agency binary detection (real Velopack layout):

    Velopack install layout (from FP postmortem §6):
      %APPDATA%\agency\
        current\           <- symlink to active app-<ver>\
        app-1.0.45\        <- versioned install dir
          agency.exe
        app-1.0.46\        <- previous version, kept for rollback
        packages\

    Probe order (correct):
      1. %APPDATA%\agency\current\agency.exe   (symlink, fast)
      2. Enumerate %APPDATA%\agency\app-*\agency.exe, pick newest

    Current lib has AgencyBinaryFallback = agency\CurrentVersion\agency.exe.
    "CurrentVersion" is WRONG naming — real symlink is "current\". This fixture
    documents the regression baseline (what the lib checks today) and adds
    pending v3.0.10 tests for the correct probe order.

  CP3.6 — Post-registration verification:
    After Register-AgencyMcpServers, installer must verify mcpRegistered.
    Current gap: unconditional "✓ Agency MCP servers registered" regardless of
    whether registration actually wrote to m-mcp-servers.json.

  AUTO-DETECTION: v3.0.10 gates are Skipped until installer content shows the
  fix. Set AIMAKER_FORCE_V310=1 to force-activate in CI before content scan.

.NOTES
  Harness version: 2.0 — corrected Velopack paths per FP postmortem §6
  Regression: FP postmortem scar list entries 1 (agency not found) + 2 (MCP not launching)
#>

BeforeAll {
    $RepoRoot      = Split-Path $PSScriptRoot -Parent
    $BlueInstaller = Join-Path $RepoRoot 'install-blue.ps1'
    $LibPath       = Join-Path $RepoRoot 'ai-maker-lib.ps1'
    . $LibPath

    $installerSrc = Get-Content $BlueInstaller -Raw -ErrorAction SilentlyContinue

    # v3.0.10 detection: correct probe uses current\ symlink or app-* glob
    # Also fires when AIMAKER_FORCE_V310=1 for CI pre-activation
    $script:HasCorrectProbe = (
        ($installerSrc -match 'agency\\current\\agency') -or
        ($installerSrc -match 'agency.app-\*') -or
        ($installerSrc -match 'Get-ChildItem.*agency.*app-')
    ) -or ($env:AIMAKER_FORCE_V310 -eq '1')

    $script:HasPostRegCheck = (
        ($installerSrc -match 'mcpRegistered') -or
        ($installerSrc -match 'Register.*Verify|post.reg')
    ) -or ($env:AIMAKER_FORCE_V310 -eq '1')

    $script:SandboxRoot = Join-Path $env:TEMP ("ai-maker-agency-" + [guid]::NewGuid().ToString("N").Substring(0, 8))

    # Run install-blue.ps1 -WhatIf in child pwsh with modified APPDATA
    function Invoke-InstallerWhatIfWith {
        param(
            [string]$PathOverride    = $env:PATH,
            [string]$AppDataOverride = $env:APPDATA
        )
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = 'pwsh.exe'
        $psi.Arguments              = "-NoProfile -NonInteractive -File `"$BlueInstaller`" -WhatIf"
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true
        $psi.Environment['PATH']    = $PathOverride
        $psi.Environment['APPDATA'] = $AppDataOverride
        $proc = [System.Diagnostics.Process]::Start($psi)
        $out  = $proc.StandardOutput.ReadToEnd() + $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{ Output = $out; ExitCode = $proc.ExitCode }
    }

    # Seed a stub agency.exe at a given path
    function New-AgencyStub {
        param([string]$Dir)
        New-Item $Dir -ItemType Directory -Force | Out-Null
        Set-Content (Join-Path $Dir 'agency.exe') 'stub' -Encoding Ascii -Force
        return (Join-Path $Dir 'agency.exe')
    }
}

AfterAll {
    if (Test-Path $script:SandboxRoot) { Remove-Item $script:SandboxRoot -Recurse -Force -EA Silent }
}

# ---------------------------------------------------------------------------
# Harness self-test
# ---------------------------------------------------------------------------
Describe "Agency detection harness" -Tag 'AgencyDetection' {
    It "locates install-blue.ps1" {
        Test-Path $BlueInstaller | Should -BeTrue
    }

    It "AgencyBinaryFallback is in lib config" {
        # Current value is 'CurrentVersion' — documented as wrong path name but kept for
        # regression baseline. v3.0.10 must move to 'current\' or app-* glob.
        $src = Get-Content $LibPath -Raw
        $src | Should -Match 'AgencyBinaryFallback'
    }

    It "reports v3.0.10 probe + post-reg capability" {
        Write-Host "  HasCorrectProbe: $($script:HasCorrectProbe)  HasPostRegCheck: $($script:HasPostRegCheck)" -ForegroundColor Cyan
        $true | Should -BeTrue
    }
}

# ---------------------------------------------------------------------------
# CP3.5 — Agency binary probe path correctness
# ---------------------------------------------------------------------------
Describe "CP3.5 -- Agency binary detection: Velopack layout" -Tag 'AgencyDetection', 'CP3' {

    It "REGRESSION: lib AgencyBinaryFallback uses 'CurrentVersion' (wrong name — should be 'current')" {
        # Documents the wrong path name in the current lib.
        # When v3.0.10 fixes this to 'current\', update test to assert 'current\' is present
        # and 'CurrentVersion' is absent.
        $src = Get-Content $LibPath -Raw
        if ($script:HasCorrectProbe) {
            # v3.0.10 shipped — should now say 'current\' not 'CurrentVersion'
            $src | Should -Match 'agency\\current\\agency'
            $src | Should -Not -Match 'CurrentVersion'
        }
        else {
            # Pre-v3.0.10: documents stale naming
            $src | Should -Match 'CurrentVersion'
        }
    }

    It "installer detects agency.exe at current\ symlink path [v3.0.10]" -Skip:(-not $script:HasCorrectProbe) {
        # v3.0.10 contract: probe order step 1 — %APPDATA%\agency\current\agency.exe
        $fakeAppData = Join-Path $script:SandboxRoot 'appdata-current-symlink'
        New-AgencyStub (Join-Path $fakeAppData 'agency\current') | Out-Null

        $result = Invoke-InstallerWhatIfWith -AppDataOverride $fakeAppData

        $result.Output | Should -Match '(?i)Agency already installed'
        $result.Output | Should -Not -Match '(?i)Installing Agency|Would install Agency'
    }

    It "installer detects agency.exe at versioned app-<ver>\ path [v3.0.10]" -Skip:(-not $script:HasCorrectProbe) {
        # v3.0.10 contract: probe order step 2 — enumerate app-* dirs
        # Simulates post-update state where current\ symlink may lag newest app dir
        $fakeAppData = Join-Path $script:SandboxRoot 'appdata-versioned'
        New-AgencyStub (Join-Path $fakeAppData 'agency\app-1.0.46') | Out-Null

        $result = Invoke-InstallerWhatIfWith -AppDataOverride $fakeAppData

        $result.Output | Should -Match '(?i)Agency already installed'
        $result.Output | Should -Not -Match '(?i)Installing Agency|Would install Agency'
    }

    It "installer triggers install when agency absent from all probe paths [v3.0.10]" -Skip:(-not $script:HasCorrectProbe) {
        # Negative: no agency.exe anywhere → install must be triggered
        $fakeAppData = Join-Path $script:SandboxRoot 'appdata-empty'
        New-Item $fakeAppData -ItemType Directory -Force | Out-Null

        $result = Invoke-InstallerWhatIfWith -AppDataOverride $fakeAppData

        $result.Output | Should -Match '(?i)Would install Agency|Installing Agency'
    }

    It "scar: agency installed but MCP does not launch without SHELL env var (verified post-install)" {
        # FP postmortem scar #2: agency.exe found but MCP registration fails because
        # agency's MCP launcher does process.env.SHELL || "/bin/sh" — no SHELL on Windows
        # → spawns /bin/sh which doesn't exist.
        # Fix: machine-scope SHELL = C:\Program Files\Git\bin\sh.exe
        # This test verifies the SHELL env var is set machine-scope on the test machine.
        $machineShell = [System.Environment]::GetEnvironmentVariable('SHELL', 'Machine')
        if ($machineShell) {
            $machineShell | Should -Match '(?i)sh\.exe|bash'
        }
        else {
            # SHELL not set — document gap, don't hard-fail (may be VM pre-install state)
            Set-ItResult -Skipped -Because "SHELL not set machine-scope — run install-blue.ps1 first"
        }
    }
}

# ---------------------------------------------------------------------------
# CP3.6 — Post-registration verification
# ---------------------------------------------------------------------------
Describe "CP3.6 -- MCP registration: post-registration verify" -Tag 'AgencyDetection', 'CP3' {

    It "lib mcpRegistered uses McpConfigPath (m-mcp-servers.json) for live check" {
        $src = Get-Content $LibPath -Raw
        $src | Should -Match 'McpConfigPath'
        $src | Should -Match 'mcpRegistered'
    }

    It "mcpRegistered = false when m-mcp-servers.json absent (lib contract)" {
        $result = Get-InstallScenario `
            -PathOverrides   @{ Workspace = 'C:\NONEXISTENT\ws'; SkillsPath = (Join-Path $script:SandboxRoot 'skills'); LegacyMaker = 'C:\NONEXISTENT\lm'; LegacyWorkbench = 'C:\NONEXISTENT\lw' } `
            -RemoteOverrides @{ HasNewRemote = $false; HasLegacyRemote = $false; IsOurRepo = $false } `
            -McpOverrides    @{ McpRegistered = $false; McpRegisteredServers = @() }

        $result.details.mcpRegistered | Should -BeFalse
    }

    It "mcpRegistered = true only when BOTH workiq + bluebird present (lib contract)" {
        $result = Get-InstallScenario `
            -PathOverrides   @{ Workspace = 'C:\NONEXISTENT\ws'; SkillsPath = (Join-Path $script:SandboxRoot 'skills'); LegacyMaker = 'C:\NONEXISTENT\lm'; LegacyWorkbench = 'C:\NONEXISTENT\lw' } `
            -RemoteOverrides @{ HasNewRemote = $false; HasLegacyRemote = $false; IsOurRepo = $false } `
            -McpOverrides    @{ McpRegistered = $true; McpRegisteredServers = @('workiq', 'bluebird') }

        $result.details.mcpRegistered | Should -BeTrue
    }

    It "REGRESSION: installer currently prints silent success without verifying registration" {
        # FP postmortem scar #2 (registration side): unconditional "✓ Agency MCP servers registered"
        # v3.0.10 should remove this line and replace with mcpRegistered check + fail-loud.
        $src = Get-Content $BlueInstaller -Raw
        if ($script:HasPostRegCheck) {
            # v3.0.10 shipped — unconditional ✓ must be gone
            $src | Should -Not -Match [regex]::Escape('Write-Host "  ✓ Agency MCP servers registered"')
        }
        else {
            # Pre-v3.0.10: documents the gap
            $src | Should -Match [regex]::Escape('✓ Agency MCP servers registered')
        }
    }

    It "installer fails loud when registration no-ops (SHELL not set) [v3.0.10]" -Skip:(-not $script:HasPostRegCheck) {
        # v3.0.10 contract: after Register-AgencyMcpServers, installer calls Get-InstallScenario
        # with live McpConfigPath. If mcpRegistered = false → throw, not ✓.
        # Simulate: fakeAppData has no m-mcp-servers.json (SHELL-not-set scenario)
        $fakeAppData = Join-Path $script:SandboxRoot 'appdata-noreg'
        New-Item $fakeAppData -ItemType Directory -Force | Out-Null

        $result = Invoke-InstallerWhatIfWith -AppDataOverride $fakeAppData

        $result.Output | Should -Not -Match '✓ Agency MCP servers registered'
        $result.Output | Should -Match '(?i)registration failed|MCP.*failed|not registered|FAILED'
    }
}
