#Requires -Version 5.1
<#
.SYNOPSIS
    AI Maker v3 — Prereq simulator
.DESCRIPTION
    Runs installer prereq detection in a PATH-isolated child process.
    Catches "fresh CPC" failures (missing winget, git, gh, etc.) without
    needing a real clean machine. Adjacent to preflight.ps1 (which covers
    static checks: version drift, asset-manifest gaps, scaffold parity).

    Run:    Invoke-Pester tests\prereq-sim.tests.ps1 -Output Detailed
    CI:     See .github/workflows/preflight.yml (runs on push + PR to main)

    Philosophy: each missing tool must produce a specific, human-readable
    message with an actionable fix (URL or command). A cryptic exception is
    a bug. These tests enforce the contract.
#>

BeforeAll {
    $RepoRoot      = Split-Path $PSScriptRoot -Parent
    $BlueInstaller = Join-Path $RepoRoot "installers\install-blue.ps1"
    $RedInstaller  = Join-Path $RepoRoot "installers\install-red.ps1"

    function Get-StrippedPath {
        param([string[]]$Strip)
        ($env:PATH -split ';' | Where-Object {
            $seg = $_
            -not ($Strip | Where-Object { $seg -match [regex]::Escape($_) })
        }) -join ';'
    }

    function Invoke-InstallerIsolated {
        param(
            [string]   $InstallerPath,
            [string[]] $StripFromPath = @(),
            [string[]] $ExtraArgs     = @('-WhatIf'),
            [switch]   $UsePS7
        )
        $exe    = if ($UsePS7) { 'pwsh.exe' } else { 'powershell.exe' }
        $argStr = "-NoProfile -NonInteractive -File `"$InstallerPath`" $($ExtraArgs -join ' ')"
        $psi    = [System.Diagnostics.ProcessStartInfo]::new($exe, $argStr)
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true
        if ($StripFromPath.Count -gt 0) {
            $psi.EnvironmentVariables['PATH'] = Get-StrippedPath -Strip $StripFromPath
        }
        $proc   = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{ Output = $stdout; ExitCode = $proc.ExitCode }
    }
}

Describe "Prereq simulator -- harness self-test" {
    It "PATH helper removes the target segment" {
        $stripped = Get-StrippedPath -Strip @('WindowsApps')
        $stripped | Should -Not -Match 'WindowsApps'
    }
    It "PATH helper preserves all other segments" {
        $stripped = Get-StrippedPath -Strip @('__nonexistent_segment__')
        $stripped | Should -Be $env:PATH
    }
    It "Blue installer file exists at expected path" {
        $BlueInstaller | Should -Exist
    }
    It "Red installer file exists at expected path" {
        $RedInstaller | Should -Exist
    }
}

Describe "Blue Pill -- prereq detection" {
    It "passes all prereq checks on current machine" {
        $r = Invoke-InstallerIsolated -InstallerPath $BlueInstaller
        $r.Output | Should -Not -Match ([regex]::Escape('X '))
    }
    It "detects missing winget and emits actionable message" {
        $r = Invoke-InstallerIsolated -InstallerPath $BlueInstaller -StripFromPath @('WindowsApps')
        $r.Output | Should -Match 'winget'
        $r.Output | Should -Match 'aka\.ms/getwinget'
    }
    It "does not complain about missing git (Blue is no-git by design)" {
        $r = Invoke-InstallerIsolated -InstallerPath $BlueInstaller -StripFromPath @('\Git\', '\git\')
        $r.Output | Should -Not -Match '(?i)git.*not found'
    }
    It "disk space check failure emits actionable message" -Skip {
        # Needs sandboxed volume or testable hook in ai-maker-lib.ps1.
        # Contract: output must match 'disk' and include GB-free figure.
    }
}

Describe "Red Pill -- prereq detection" {
    It "passes all prereq checks on current machine" {
        $r = Invoke-InstallerIsolated -InstallerPath $RedInstaller -UsePS7
        $r.Output | Should -Not -Match ([regex]::Escape('X '))
    }
    It "detects missing winget and emits actionable message" {
        $r = Invoke-InstallerIsolated -InstallerPath $RedInstaller -StripFromPath @('WindowsApps') -UsePS7
        $r.Output | Should -Match 'winget'
        $r.Output | Should -Match 'aka\.ms/getwinget'
    }
    It "announces git install step when git is absent -- does NOT hard-fail" {
        $r = Invoke-InstallerIsolated -InstallerPath $RedInstaller -StripFromPath @('\Git\', '\git\') -ExtraArgs @('-WhatIf') -UsePS7
        $r.Output | Should -Match '(?i)git'
        $r.Output | Should -Not -Match '(?i)git.*not found'
    }
    It "announces gh CLI install step when gh is absent -- does NOT hard-fail" -Skip {
        # Enable once gh CLI message format in install-red.ps1 Step 3 is confirmed.
    }
    It "disk space check failure emits actionable message" -Skip {
        # Same as Blue -- needs sandboxed volume or lib hook.
    }
}

Describe "Cross-pill -- Windows version gate" {
    It "Blue: emits Windows version on prereq pass" {
        $r = Invoke-InstallerIsolated -InstallerPath $BlueInstaller
        $r.Output | Should -Match '(?i)windows'
    }
    It "Red: emits Windows version on prereq pass" {
        $r = Invoke-InstallerIsolated -InstallerPath $RedInstaller -UsePS7
        $r.Output | Should -Match '(?i)windows'
    }
}
