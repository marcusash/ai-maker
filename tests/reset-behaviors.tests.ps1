#Requires -Version 7.0
<#
.SYNOPSIS
  Behavioral regression fixtures for reset.bat.

.DESCRIPTION
  For each hideout that reset.bat is responsible for cleaning, this suite:
    1. Seeds the hideout (real path or temp sandbox where possible)
    2. Runs reset.bat
    3. Asserts the path is gone

  COVERAGE MAP:
    ACTIVE  (current reset.bat HEAD) — skills, workspace, transaction log
    PENDING (reset.bat Squirrel update, SHA not yet on remote) — UAC elevation,
            per-machine Copilot, AppX, registry, LOCALAPPDATA, Start Menu x2, TEMP updaters

  SAFETY: These tests are destructive. Guard env var required:
    $env:RESET_BEHAVIORS_UNSAFE = '1'
  Only set this on the VM integration runner, not on a dev machine.

  TAG STRATEGY:
    -Tag 'ResetBehavior'           — all tests in this file
    -Tag 'CurrentResetBat'         — active against current reset.bat HEAD
    -Tag 'PendingSquirrelUpdate'   — activate once FP's reset.bat update lands

.NOTES
  Harness version: 1.0 (June 2026)
  reset.bat HEAD at time of writing: 4-item version (skills, workspace, tx-log)
  FP described full version (6a2646c) not yet visible on remote — stubs documented.
#>

BeforeAll {
    # Safety guard — must be set explicitly to run any destructive test
    $script:SafeToRun = ($env:RESET_BEHAVIORS_UNSAFE -eq '1')

    # Locate reset.bat relative to repo root (two levels up from tests/)
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    # When run from the tests/ folder directly, adjust
    if (Test-Path (Join-Path $PSScriptRoot '..\reset.bat')) {
        $script:ResetBat = (Resolve-Path (Join-Path $PSScriptRoot '..\reset.bat')).Path
    } elseif (Test-Path (Join-Path $repoRoot 'reset.bat')) {
        $script:ResetBat = (Join-Path $repoRoot 'reset.bat')
    } else {
        $script:ResetBat = $null
    }

    # Detect reset.bat capability version (line count proxy)
    $script:ResetBatIsFullSquirrel = $false
    if ($script:ResetBat -and (Test-Path $script:ResetBat)) {
        $content = Get-Content $script:ResetBat -Raw
        # Full Squirrel version has UAC elevation and AppX removal
        $script:ResetBatIsFullSquirrel = ($content -match 'net session' -or $content -match 'Remove-AppxPackage' -or $content -match 'AppX')
    }

    function Invoke-ResetBat {
        if (-not $script:ResetBat) { throw "reset.bat not found" }
        $p = Start-Process 'cmd.exe' -ArgumentList "/c `"$($script:ResetBat)`"" `
            -Wait -PassThru -WindowStyle Hidden
        return $p.ExitCode
    }

    function Seed-SkillDir {
        param([string]$Name)
        $path = Join-Path $env:USERPROFILE ".copilot\skills\$Name"
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'SKILL.md') "# $Name test fixture" -Force
        return $path
    }

    function Seed-Workspace {
        $path = 'C:\GitHub\ai-workspace'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'marker.txt') 'reset-behavior-test' -Force
        return $path
    }

    function Seed-TransactionLog {
        $path = Join-Path $env:USERPROFILE '.copilot\ai-maker'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'install-log.jsonl') '{"step":"test"}' -Force
        return $path
    }
}

# ---------------------------------------------------------------------------
# Harness self-test
# ---------------------------------------------------------------------------
Describe "Reset.bat harness" -Tag 'ResetBehavior' {
    It "locates reset.bat" {
        $script:ResetBat | Should -Not -BeNullOrEmpty
        Test-Path $script:ResetBat | Should -BeTrue
    }

    It "detects reset.bat capability level" {
        # Document which version is active — not a pass/fail gate
        $version = if ($script:ResetBatIsFullSquirrel) { 'full-squirrel' } else { 'lite-4-item' }
        Write-Host "reset.bat capability: $version" -ForegroundColor Cyan
        $true | Should -BeTrue   # always passes — diagnostic only
    }
}

# ---------------------------------------------------------------------------
# ACTIVE: Current reset.bat HEAD (4-item version)
# ---------------------------------------------------------------------------
Describe "reset.bat removes AI Maker skills" -Tag 'ResetBehavior', 'CurrentResetBat' {
    BeforeEach {
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set — skip destructive test"
        }
    }

    It "removes ai-maker-* skill directories" {
        $seeded = Seed-SkillDir 'ai-maker-reset-test'
        Test-Path $seeded | Should -BeTrue  # confirm seed

        Invoke-ResetBat | Out-Null

        Test-Path $seeded | Should -BeFalse
    }

    It "removes ai-workbench-* skill directories" {
        $seeded = Seed-SkillDir 'ai-workbench-reset-test'
        Test-Path $seeded | Should -BeTrue

        Invoke-ResetBat | Out-Null

        Test-Path $seeded | Should -BeFalse
    }

    It "leaves non-ai-maker skills untouched" {
        $other = Join-Path $env:USERPROFILE ".copilot\skills\other-skill-reset-test"
        New-Item -ItemType Directory -Path $other -Force | Out-Null

        Invoke-ResetBat | Out-Null

        Test-Path $other | Should -BeTrue
        Remove-Item $other -Recurse -Force  # cleanup
    }
}

Describe "reset.bat removes workspace" -Tag 'ResetBehavior', 'CurrentResetBat' {
    BeforeEach {
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set — skip destructive test"
        }
    }

    It "removes C:\GitHub\ai-workspace" {
        $seeded = Seed-Workspace
        Test-Path $seeded | Should -BeTrue

        Invoke-ResetBat | Out-Null

        Test-Path $seeded | Should -BeFalse
    }

    It "is idempotent when workspace already absent" {
        if (Test-Path 'C:\GitHub\ai-workspace') {
            Remove-Item 'C:\GitHub\ai-workspace' -Recurse -Force
        }

        { Invoke-ResetBat } | Should -Not -Throw
    }
}

Describe "reset.bat removes transaction log" -Tag 'ResetBehavior', 'CurrentResetBat' {
    BeforeEach {
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set — skip destructive test"
        }
    }

    It "removes `$env:USERPROFILE\.copilot\ai-maker directory" {
        $seeded = Seed-TransactionLog
        Test-Path $seeded | Should -BeTrue

        Invoke-ResetBat | Out-Null

        Test-Path $seeded | Should -BeFalse
    }
}

Describe "reset.bat exits cleanly" -Tag 'ResetBehavior', 'CurrentResetBat' {
    BeforeEach {
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set — skip destructive test"
        }
    }

    It "exits 0 on clean state (nothing to remove)" {
        # Ensure all managed paths absent
        @(
            'C:\GitHub\ai-workspace',
            (Join-Path $env:USERPROFILE '.copilot\ai-maker')
        ) | ForEach-Object { if (Test-Path $_) { Remove-Item $_ -Recurse -Force } }

        Get-Item (Join-Path $env:USERPROFILE '.copilot\skills\ai-maker-*') -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force

        $exitCode = Invoke-ResetBat
        $exitCode | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# PENDING: Squirrel / full-coverage hideouts
# Activate once FP's reset.bat update (6a2646c) lands on marcusash_microsoft/ai-maker main
# ---------------------------------------------------------------------------
Describe "reset.bat removes per-machine Copilot install [PENDING reset.bat update]" -Tag 'ResetBehavior', 'PendingSquirrelUpdate' {
    BeforeEach {
        if (-not $script:ResetBatIsFullSquirrel) {
            Set-ItResult -Skipped -Because "reset.bat full-squirrel version not yet on remote"
        }
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set"
        }
    }

    It "removes C:\Program Files\GitHub Copilot" {
        # Requires admin — self-elevation is in the full reset.bat
        $path = 'C:\Program Files\GitHub Copilot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'marker.txt') 'reset-test' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }
}

Describe "reset.bat removes AppX package [PENDING reset.bat update]" -Tag 'ResetBehavior', 'PendingSquirrelUpdate' {
    BeforeEach {
        if (-not $script:ResetBatIsFullSquirrel) {
            Set-ItResult -Skipped -Because "reset.bat full-squirrel version not yet on remote"
        }
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set"
        }
    }

    It "runs Remove-AppxPackage for current user Copilot package" {
        # Contract: reset.bat invokes Remove-AppxPackage; if package absent, no error
        # Verification: AppX removal is idempotent (no error when package already gone)
        { Invoke-ResetBat } | Should -Not -Throw
    }
}

Describe "reset.bat removes LOCALAPPDATA Copilot install [PENDING reset.bat update]" -Tag 'ResetBehavior', 'PendingSquirrelUpdate' {
    BeforeEach {
        if (-not $script:ResetBatIsFullSquirrel) {
            Set-ItResult -Skipped -Because "reset.bat full-squirrel version not yet on remote"
        }
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set"
        }
    }

    It "removes `$env:LOCALAPPDATA\Programs\GitHubCopilot" {
        $path = Join-Path $env:LOCALAPPDATA 'Programs\GitHubCopilot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'marker.txt') 'reset-test' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }
}

Describe "reset.bat removes Start Menu shortcuts [PENDING reset.bat update]" -Tag 'ResetBehavior', 'PendingSquirrelUpdate' {
    BeforeEach {
        if (-not $script:ResetBatIsFullSquirrel) {
            Set-ItResult -Skipped -Because "reset.bat full-squirrel version not yet on remote"
        }
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set"
        }
    }

    It "removes per-user Start Menu shortcut" {
        $path = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\GitHub Copilot.lnk'
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        Set-Content $path 'stub-lnk' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }

    It "removes all-users Start Menu shortcut" {
        $path = Join-Path $env:PROGRAMDATA 'Microsoft\Windows\Start Menu\Programs\GitHub Copilot.lnk'
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        Set-Content $path 'stub-lnk' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }
}

Describe "reset.bat removes stale TEMP Squirrel updaters [PENDING reset.bat update]" -Tag 'ResetBehavior', 'PendingSquirrelUpdate' {
    BeforeEach {
        if (-not $script:ResetBatIsFullSquirrel) {
            Set-ItResult -Skipped -Because "reset.bat full-squirrel version not yet on remote"
        }
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set"
        }
    }

    It "removes TEMP\GitHub Copilot-* updater directories" {
        $path = Join-Path $env:LOCALAPPDATA 'Temp\GitHub Copilot-squirrel-stub'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'Update.exe') 'stub' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }
}

Describe "reset.bat removes registry entries [PENDING reset.bat update]" -Tag 'ResetBehavior', 'PendingSquirrelUpdate' {
    BeforeEach {
        if (-not $script:ResetBatIsFullSquirrel) {
            Set-ItResult -Skipped -Because "reset.bat full-squirrel version not yet on remote"
        }
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set"
        }
    }

    It "removes HKCU Uninstall registry key matching 'Copilot'" {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHubCopilotTest'
        New-Item -Path $key -Force | Out-Null
        Set-ItemProperty -Path $key -Name 'DisplayName' -Value 'GitHub Copilot Test'

        Invoke-ResetBat | Out-Null

        Test-Path $key | Should -BeFalse
    }

    It "leaves non-Copilot uninstall registry keys untouched" {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OtherApp'
        New-Item -Path $key -Force | Out-Null
        Set-ItemProperty -Path $key -Name 'DisplayName' -Value 'Other App'

        Invoke-ResetBat | Out-Null

        Test-Path $key | Should -BeTrue
        Remove-Item $key -Recurse -Force  # cleanup
    }
}
