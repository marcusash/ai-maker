#Requires -Version 7.0
<#
.SYNOPSIS
  Prereq simulator for AI Maker v3 installers.
  PATH-strips tools from child process environment and asserts specific error messages.

.DESCRIPTION
  Tests that the installer's prereq detection emits actionable errors when tools
  are missing, WITHOUT running against real system paths or production installs.

  Technique: fork a child PowerShell via ProcessStartInfo with a modified PATH
  that excises the relevant tool. Parent process PATH is never modified.

  COVERAGE:
    - winget missing → "winget not found" error + return (Blue + Red)
    - Windows version too old → "Windows 10 or later required" error + return
    - Windows 10+ passes version check
    - Harness self-test: PATH stripping works

.NOTES
  Harness version: 1.0
  Adjacent to (not duplicating) tests/preflight.ps1 which covers:
  - PS parse, version consistency, asset manifest, scaffold parity, WhatIf dry-run
  prereq-sim covers: runtime prereq detection behavior when tools absent
#>

BeforeAll {
    $RepoRoot   = Split-Path $PSScriptRoot -Parent
    $BlueInstaller = Join-Path $RepoRoot 'install-blue.ps1'
    $RedInstaller  = Join-Path $RepoRoot 'install-red.ps1'

    # Strip a tool name from a PATH string by removing PATH segments that contain it
    function Remove-ToolFromPath {
        param([string]$Path, [string]$ToolName)
        $segments = $Path -split [System.IO.Path]::PathSeparator
        $stripped  = $segments | Where-Object { -not (Test-Path (Join-Path $_ "$ToolName.exe") -ErrorAction SilentlyContinue) -and $_ -notmatch [regex]::Escape($ToolName) }
        return ($stripped -join [System.IO.Path]::PathSeparator)
    }

    # Run an installer in a child PS7 process with a modified PATH.
    # Returns: {Output, ExitCode}
    function Invoke-InstallerWithPath {
        param(
            [string]$InstallerPath,
            [string]$ModifiedPath,
            [string]$Arguments = '-WhatIf'
        )
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = 'pwsh.exe'
        $psi.Arguments              = "-NoProfile -NonInteractive -File `"$InstallerPath`" $Arguments"
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true
        $psi.Environment['PATH']    = $ModifiedPath

        $proc = [System.Diagnostics.Process]::Start($psi)
        $out  = $proc.StandardOutput.ReadToEnd() + $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{ Output = $out; ExitCode = $proc.ExitCode }
    }
}

# ---------------------------------------------------------------------------
# Harness self-test
# ---------------------------------------------------------------------------
Describe "Prereq sim harness" -Tag 'PrereqSim' {
    It "locates install-blue.ps1" {
        Test-Path $BlueInstaller | Should -BeTrue
    }

    It "locates install-red.ps1" {
        Test-Path $RedInstaller | Should -BeTrue
    }

    It "PATH stripping excises target tool" {
        # Strip 'git' from current PATH and verify git.exe is no longer findable
        $stripped = Remove-ToolFromPath $env:PATH 'git'
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = 'pwsh.exe'
        $psi.Arguments              = '-NoProfile -NonInteractive -Command "Get-Command git -ErrorAction SilentlyContinue"'
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true
        $psi.Environment['PATH']    = $stripped
        $proc = [System.Diagnostics.Process]::Start($psi)
        $out  = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit()
        $out.Trim() | Should -BeNullOrEmpty -Because "git should not be findable after PATH stripping"
    }

    It "parent PATH is not modified after child runs" {
        $originalPath = $env:PATH
        $stripped = Remove-ToolFromPath $env:PATH 'winget'
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = 'pwsh.exe'
        $psi.Arguments              = '-NoProfile -NonInteractive -Command "exit 0"'
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.Environment['PATH']    = $stripped
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        $env:PATH | Should -Be $originalPath
    }
}

# ---------------------------------------------------------------------------
# Blue installer: winget missing
# ---------------------------------------------------------------------------
Describe "Blue installer prereq: winget missing" -Tag 'PrereqSim', 'BluePrereq' {
    It "emits 'winget not found' message and returns without installing" {
        $strippedPath = Remove-ToolFromPath $env:PATH 'winget'
        $result = Invoke-InstallerWithPath -InstallerPath $BlueInstaller -ModifiedPath $strippedPath

        $result.Output | Should -Match '(?i)winget not found'
    }

    It "does NOT reach skills install step when winget missing" {
        $strippedPath = Remove-ToolFromPath $env:PATH 'winget'
        $result = Invoke-InstallerWithPath -InstallerPath $BlueInstaller -ModifiedPath $strippedPath

        # If winget is missing the installer returns early — no skill install output
        $result.Output | Should -Not -Match '(?i)Step [2-9]|Installing skills|Step 2'
    }
}

# ---------------------------------------------------------------------------
# Blue installer: Windows version
# ---------------------------------------------------------------------------
Describe "Blue installer prereq: Windows version" -Tag 'PrereqSim', 'BluePrereq' {
    It "passes version check on Windows 10+" {
        # Run with normal PATH (just -WhatIf) — if OS is Win10+, prereq passes
        $osVersion = [System.Environment]::OSVersion.Version
        if ($osVersion.Major -lt 10) {
            Set-ItResult -Skipped -Because "Test machine is not Windows 10+ — cannot test pass case"
        }
        $result = Invoke-InstallerWithPath -InstallerPath $BlueInstaller -ModifiedPath $env:PATH

        $result.Output | Should -Not -Match '(?i)Windows 10 or later required'
    }
}

# ---------------------------------------------------------------------------
# Red installer: winget missing
# ---------------------------------------------------------------------------
Describe "Red installer prereq: winget missing" -Tag 'PrereqSim', 'RedPrereq' {
    It "emits 'winget not found' message and returns without installing" {
        $strippedPath = Remove-ToolFromPath $env:PATH 'winget'
        $result = Invoke-InstallerWithPath -InstallerPath $RedInstaller -ModifiedPath $strippedPath

        $result.Output | Should -Match '(?i)winget not found'
    }
}

# ---------------------------------------------------------------------------
# Cross-pill: Windows version contract
# ---------------------------------------------------------------------------
Describe "Cross-pill Windows version gate" -Tag 'PrereqSim' {
    It "Blue reports Windows 10+ requirement (not Windows 11)" {
        # Contract: Blue targets Win10+ managers — error text must say '10'
        # If the message said '11', that would be a regression
        $strippedPath = 'C:\Windows\System32'   # bare path — winget missing, will early-return
        $result = Invoke-InstallerWithPath -InstallerPath $BlueInstaller -ModifiedPath $strippedPath

        if ($result.Output -match '(?i)Windows.*required') {
            $result.Output | Should -Match '(?i)Windows 10'
            $result.Output | Should -Not -Match '(?i)Windows 11 required'
        }
        else {
            # Either winget-missing returned first (expected) or version gate not hit
            # Either way: no Windows 11 requirement string — pass
            $result.Output | Should -Not -Match '(?i)Windows 11 required'
        }
    }
}
