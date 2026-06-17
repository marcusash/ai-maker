#Requires -Version 7.0
<#
.SYNOPSIS
  Agency binary detection + MCP registration verification fixtures.
  Encodes the v3.0.10 contract for CP3.5 and CP3.6.

.DESCRIPTION
  CP3.5 — Agency binary detection (Velopack-style versioned path):
    Contract: when agency.exe is ONLY at $env:APPDATA\agency\<version>\agency.exe
    (no PATH entry, no CurrentVersion path), the installer MUST detect it and
    print "Agency already installed" — NOT trigger a reinstall.

    Current gap: installer checks Get-Command + AgencyBinaryFallback
    ($env:APPDATA\agency\CurrentVersion\agency.exe). It does NOT glob versioned dirs.
    v3.0.10 adds: Get-ChildItem $env:APPDATA\agency\*\agency.exe -EA Silent | First.

  CP3.6 — Post-registration verification:
    Contract: after Register-AgencyMcpServers runs, installer MUST verify
    mcpRegistered via Get-InstallScenario. If false → fail loud, not silent ✓.

    Current gap: installer prints "✓ Agency MCP servers registered" regardless
    of whether registration wrote entries to m-mcp-servers.json.
    v3.0.10 adds: post-registration mcpRegistered check + throw on false.

  AUTO-DETECTION: Both test groups detect v3.0.10 presence via content scan of
  install-blue.ps1. Set $env:AIMAKER_FORCE_V310=1 to force-activate in CI.

.NOTES
  Harness version: 1.0 (June 2026)
  Pairs with: fail-forward.tests.ps1 CP3 (mcpRegistered via McpOverrides)
#>

BeforeAll {
    $RepoRoot      = Split-Path $PSScriptRoot -Parent
    $BlueInstaller = Join-Path $RepoRoot 'install-blue.ps1'
    $LibPath       = Join-Path $RepoRoot 'ai-maker-lib.ps1'
    . $LibPath

    # Detect v3.0.10 capability via content scan — no hard version pinning
    $installerSrc       = Get-Content $BlueInstaller -Raw -ErrorAction SilentlyContinue
    $script:HasGlobDetection = ($installerSrc -match 'agency\\\\?\*\\\\?agency\.exe' -or
                                 $installerSrc -match "agency/\*/agency" -or
                                 $installerSrc -match 'Get-ChildItem.*agency.*\*.*agency') -or
                                ($env:AIMAKER_FORCE_V310 -eq '1')
    $script:HasPostRegCheck  = ($installerSrc -match 'mcpRegistered' -or
                                 $installerSrc -match 'Register.*Verify|Verify.*Register') -or
                                ($env:AIMAKER_FORCE_V310 -eq '1')

    $script:SandboxRoot = Join-Path $env:TEMP ("ai-maker-agency-" + [guid]::NewGuid().ToString("N").Substring(0, 8))

    # Run installer WhatIf in a child pwsh with modified PATH and/or APPDATA
    function Invoke-InstallerWhatIfWith {
        param(
            [string]$PathOverride  = $env:PATH,
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

    # Seed a stub agency.exe that exits 0 but does nothing
    function New-AgencyStub {
        param([string]$Dir)
        New-Item $Dir -ItemType Directory -Force | Out-Null
        # Minimal valid PE header stub — but process execution won't be used in WhatIf mode.
        # For non-WhatIf mock testing, use a .ps1 renamed to .exe via PATH trick.
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

    It "reports v3.0.10 capability level" {
        Write-Host "  GlobDetection: $($script:HasGlobDetection)  PostRegCheck: $($script:HasPostRegCheck)" -ForegroundColor Cyan
        $true | Should -BeTrue  # diagnostic only
    }

    It "detects current AgencyBinaryFallback path in installer" {
        # Regression guard: ensure CurrentVersion fallback isn't accidentally removed
        $src = Get-Content $BlueInstaller -Raw
        $src | Should -Match 'AgencyBinaryFallback'
    }
}

# ---------------------------------------------------------------------------
# CP3.5 — Agency binary detection: versioned APPDATA path (Velopack-style)
# ---------------------------------------------------------------------------
Describe "CP3.5 -- Agency binary at versioned APPDATA path" -Tag 'AgencyDetection', 'CP3' {

    It "current installer detects agency at AgencyBinaryFallback (CurrentVersion path)" {
        # This is the EXISTING behavior — regression guard for what works today
        $fakeAppData = Join-Path $script:SandboxRoot 'appdata-current'
        $agencyDir   = Join-Path $fakeAppData 'agency\CurrentVersion'
        New-AgencyStub $agencyDir | Out-Null

        $result = Invoke-InstallerWhatIfWith -AppDataOverride $fakeAppData

        # Current installer checks AgencyBinaryFallback = APPDATA\agency\CurrentVersion\agency.exe
        $result.Output | Should -Match '(?i)Agency already installed'
    }

    It "installer detects agency.exe at versioned path agency\1.0.0\agency.exe [v3.0.10]" -Skip:(-not $script:HasGlobDetection) {
        # PENDING v3.0.10: installer must add glob: Get-ChildItem $env:APPDATA\agency\*\agency.exe
        # When this test activates, it proves the Velopack-style path is found without reinstall.
        $fakeAppData = Join-Path $script:SandboxRoot 'appdata-versioned'
        $agencyDir   = Join-Path $fakeAppData 'agency\1.0.0'
        New-AgencyStub $agencyDir | Out-Null

        $result = Invoke-InstallerWhatIfWith -AppDataOverride $fakeAppData

        # v3.0.10 contract: versioned binary found → "already installed", NOT "Installing Agency"
        $result.Output | Should -Match '(?i)Agency already installed'
        $result.Output | Should -Not -Match '(?i)Installing Agency'
    }

    It "installer does NOT detect agency when only at wrong versioned path (negative)" -Skip:(-not $script:HasGlobDetection) {
        # Contract: a totally absent binary still triggers install
        $fakeAppData = Join-Path $script:SandboxRoot 'appdata-empty'
        New-Item $fakeAppData -ItemType Directory -Force | Out-Null

        $result = Invoke-InstallerWhatIfWith -AppDataOverride $fakeAppData

        # No binary anywhere → WhatIf should say "Would install Agency"
        $result.Output | Should -Match '(?i)Would install Agency|Installing Agency'
    }
}

# ---------------------------------------------------------------------------
# CP3.6 — Post-registration verification: fail loud on no-op
# ---------------------------------------------------------------------------
Describe "CP3.6 -- MCP registration verification fails loud when no-op" -Tag 'AgencyDetection', 'CP3' {

    It "Get-InstallScenario returns mcpRegistered = false when m-mcp-servers.json missing" {
        # Prerequisite: the lib contract (already active from mcpRegistered PR)
        # m-mcp-servers.json not present → mcpRegistered must be false
        $result = Get-InstallScenario `
            -PathOverrides   @{ Workspace='C:\NONEXISTENT\sandbox'; SkillsPath=(Join-Path $script:SandboxRoot 'skills'); LegacyMaker='C:\NONEXISTENT\lm'; LegacyWorkbench='C:\NONEXISTENT\lw' } `
            -RemoteOverrides @{ HasNewRemote=$false; HasLegacyRemote=$false; IsOurRepo=$false } `
            -McpOverrides    @{ McpRegistered=$false; McpRegisteredServers=@() }

        $result.details.mcpRegistered | Should -BeFalse
    }

    It "Get-InstallScenario returns mcpRegistered = true only when workiq + bluebird both present" {
        # Positive contract — already covered by fail-forward CP3 but repeated here for clarity
        $result = Get-InstallScenario `
            -PathOverrides   @{ Workspace='C:\NONEXISTENT\sandbox'; SkillsPath=(Join-Path $script:SandboxRoot 'skills'); LegacyMaker='C:\NONEXISTENT\lm'; LegacyWorkbench='C:\NONEXISTENT\lw' } `
            -RemoteOverrides @{ HasNewRemote=$false; HasLegacyRemote=$false; IsOurRepo=$false } `
            -McpOverrides    @{ McpRegistered=$true; McpRegisteredServers=@('workiq','bluebird') }

        $result.details.mcpRegistered | Should -BeTrue
        $result.details.mcpRegisteredServers | Should -Contain 'workiq'
        $result.details.mcpRegisteredServers | Should -Contain 'bluebird'
    }

    It "installer output after Register-AgencyMcpServers no-op does NOT claim success [v3.0.10]" -Skip:(-not $script:HasPostRegCheck) {
        # PENDING v3.0.10: installer must check mcpRegistered after Register-AgencyMcpServers.
        # When this test activates, it proves a no-op registration causes a loud failure.
        #
        # Approach: run installer WhatIf with a fake APPDATA that has no m-mcp-servers.json.
        # In v3.0.10, installer will check mcpRegistered post-registration in WhatIf mode too.
        $fakeAppData = Join-Path $script:SandboxRoot 'appdata-noreg'
        New-Item $fakeAppData -ItemType Directory -Force | Out-Null

        $result = Invoke-InstallerWhatIfWith -AppDataOverride $fakeAppData

        # v3.0.10 contract: installer must NOT print "✓ Agency MCP servers registered"
        # when m-mcp-servers.json is absent post-registration.
        $result.Output | Should -Not -Match '✓ Agency MCP servers registered'
        $result.Output | Should -Match '(?i)registration failed|MCP.*failed|not registered|FAILED'
    }

    It "installer silent-success string '✓ Agency MCP servers registered' is present in current code [regression]" {
        # Documents the CURRENT silent-✓ behavior so we know when v3.0.10 removes it.
        # When v3.0.10 ships, this test will flip to xfail — update to -Skip or remove.
        $src = Get-Content $BlueInstaller -Raw
        if ($script:HasPostRegCheck) {
            # v3.0.10 shipped — unconditional ✓ should be gone
            $src | Should -Not -Match [regex]::Escape('Write-Host "  ✓ Agency MCP servers registered"')
        }
        else {
            # Current (pre-v3.0.10): unconditional ✓ is present — document it
            $src | Should -Match [regex]::Escape('✓ Agency MCP servers registered')
        }
    }
}
