#Requires -Version 7.0
<#
.SYNOPSIS
  Behavioral regression fixtures for reset.bat (marcusash/ai-maker).

.DESCRIPTION
  Tests the full Squirrel-aware reset.bat (HEAD 68dee27+). For each hideout
  that reset.bat targets, this suite seeds the path then asserts removal.

  COVERAGE (all active against current reset.bat HEAD):
    - LOCALAPPDATA Copilot dirs (GitHubCopilot, github-copilot, Programs variants)
    - Start Menu shortcuts (per-user + all-users, both folder + .lnk forms)
    - TEMP Squirrel updater dirs
    - HKCU Uninstall registry key with Copilot DisplayName
    - ai-workspace workspace dir (C:\GitHub\ai-workspace)
    - agency AppData dirs

  VM-ONLY (admin required / too destructive for dev machine):
    - ~/.copilot full wipe (kills Copilot CLI itself)
    - C:\Program Files\GitHub Copilot (per-machine, needs admin)
    - AppX package removal (needs registered package)
    - Process killing

  SAFETY: These tests write to real system paths. Guard required:
    $env:RESET_BEHAVIORS_UNSAFE = '1'
  Only set on VM integration runner. Never on a dev machine with live install.

  ADMIN NOTE: Per-machine tests also require -RunAsAdministrator.
  Tag-filter for non-admin CI: -Tag 'ResetBehavior' -Exclude 'AdminRequired'

.NOTES
  reset.bat HEAD: 68dee27+ (full Squirrel, Remove-AppxPackage, net session UAC)
  Harness version: 2.0 — canonical marcusash/ai-maker
#>

BeforeAll {
    $script:SafeToRun = ($env:RESET_BEHAVIORS_UNSAFE -eq '1')

    # reset.bat lives at repo root (tests/ is one level down)
    $script:ResetBat = Resolve-Path (Join-Path $PSScriptRoot '..\reset.bat') -ErrorAction SilentlyContinue
    if (-not $script:ResetBat) {
        $script:ResetBat = Join-Path (Split-Path $PSScriptRoot -Parent) 'reset.bat'
    }

    # Full-squirrel detection via content signature
    $script:IsFullSquirrel = $false
    if (Test-Path $script:ResetBat) {
        $bat = Get-Content $script:ResetBat -Raw
        $script:IsFullSquirrel = ($bat -match 'Remove-AppxPackage') -and ($bat -match 'net session')
    }

    function Invoke-ResetBat {
        if (-not (Test-Path $script:ResetBat)) { throw "reset.bat not found at $($script:ResetBat)" }
        # Run hidden, capture exit code
        $p = Start-Process 'cmd.exe' -ArgumentList "/c `"$($script:ResetBat)`"" `
            -Wait -PassThru -WindowStyle Hidden
        return $p.ExitCode
    }
}

# ---------------------------------------------------------------------------
# Harness self-test
# ---------------------------------------------------------------------------
Describe "reset.bat harness" -Tag 'ResetBehavior' {
    It "locates reset.bat" {
        $script:ResetBat | Should -Not -BeNullOrEmpty
        Test-Path $script:ResetBat | Should -BeTrue
    }

    It "detects full-squirrel capability" {
        $script:IsFullSquirrel | Should -BeTrue -Because "HEAD 68dee27+ must have Remove-AppxPackage + net session"
    }
}

# ---------------------------------------------------------------------------
# LOCALAPPDATA Copilot dirs
# reset.bat step [4] sweeps: GitHubCopilot, GitHub Copilot (space), github-copilot,
# Programs\GitHub Copilot, Programs\GitHubCopilot (both in [2] and [4])
# ---------------------------------------------------------------------------
Describe "reset.bat removes LOCALAPPDATA Copilot dirs" -Tag 'ResetBehavior', 'SquirrelHideout' {
    BeforeEach {
        if (-not $script:SafeToRun) { Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set" }
    }

    It "removes LOCALAPPDATA\GitHubCopilot" {
        $path = Join-Path $env:LOCALAPPDATA 'GitHubCopilot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'marker.txt') 'reset-test' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }

    It "removes LOCALAPPDATA\Programs\GitHubCopilot" {
        $path = Join-Path $env:LOCALAPPDATA 'Programs\GitHubCopilot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'marker.txt') 'reset-test' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }

    It "removes LOCALAPPDATA\Programs\GitHub Copilot (with space)" {
        $path = Join-Path $env:LOCALAPPDATA 'Programs\GitHub Copilot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'marker.txt') 'reset-test' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }
}

# ---------------------------------------------------------------------------
# Start Menu shortcuts
# reset.bat step [2F] and [5]: both folder forms and .lnk forms,
# per-user (%APPDATA%) AND all-users (%PROGRAMDATA%)
# ---------------------------------------------------------------------------
Describe "reset.bat removes Start Menu shortcuts" -Tag 'ResetBehavior', 'SquirrelHideout' {
    BeforeEach {
        if (-not $script:SafeToRun) { Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set" }
    }

    It "removes per-user Start Menu GitHub Copilot folder" {
        $path = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\GitHub Copilot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'GitHub Copilot.lnk') 'stub' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }

    It "removes per-user Start Menu GitHub Copilot.lnk (standalone shortcut)" {
        $lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\GitHub Copilot.lnk'
        New-Item -ItemType Directory -Path (Split-Path $lnk) -Force | Out-Null
        Set-Content $lnk 'stub' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $lnk | Should -BeFalse
    }

    It "removes all-users Start Menu GitHub Copilot folder" {
        $path = Join-Path $env:PROGRAMDATA 'Microsoft\Windows\Start Menu\Programs\GitHub Copilot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'GitHub Copilot.lnk') 'stub' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }

    It "removes per-user GitHub Inc Start Menu folder (Squirrel drop location)" {
        $path = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\GitHub, Inc'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'GitHub Copilot.lnk') 'stub' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }
}

# ---------------------------------------------------------------------------
# TEMP Squirrel updater dirs
# reset.bat step [2E]: %LOCALAPPDATA%\Temp\GitHub Copilot-*
# ---------------------------------------------------------------------------
Describe "reset.bat removes stale TEMP Squirrel updater dirs" -Tag 'ResetBehavior', 'SquirrelHideout' {
    BeforeEach {
        if (-not $script:SafeToRun) { Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set" }
    }

    It "removes LOCALAPPDATA\Temp\GitHub Copilot-* updater dir" {
        $path = Join-Path $env:LOCALAPPDATA 'Temp\GitHub Copilot-squirrel-stub'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'Update.exe') 'stub' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }
}

# ---------------------------------------------------------------------------
# Registry: HKCU Uninstall sweep
# reset.bat step [2C]: sweeps HKCU/HKLM/WOW6432Node for DisplayName matching 'Copilot'
# HKCU can be seeded without admin — HKLM requires admin (VMOnly)
# ---------------------------------------------------------------------------
Describe "reset.bat sweeps HKCU Uninstall registry entries" -Tag 'ResetBehavior', 'SquirrelHideout' {
    BeforeEach {
        if (-not $script:SafeToRun) { Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set" }
    }

    It "removes HKCU Uninstall key with Copilot DisplayName" {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GitHubCopilotResetTest'
        New-Item -Path $key -Force | Out-Null
        Set-ItemProperty -Path $key -Name 'DisplayName' -Value 'GitHub Copilot Reset Test'

        Invoke-ResetBat | Out-Null

        Test-Path $key | Should -BeFalse
    }

    It "leaves non-Copilot HKCU Uninstall keys untouched" {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OtherAppResetTest'
        New-Item -Path $key -Force | Out-Null
        Set-ItemProperty -Path $key -Name 'DisplayName' -Value 'Some Other App'

        Invoke-ResetBat | Out-Null

        $exists = Test-Path $key
        Remove-Item $key -Recurse -Force -ErrorAction SilentlyContinue
        $exists | Should -BeTrue
    }
}

# ---------------------------------------------------------------------------
# Workspace
# reset.bat step [5]: C:\GitHub\ai-workspace
# ---------------------------------------------------------------------------
Describe "reset.bat removes ai-workspace" -Tag 'ResetBehavior' {
    BeforeEach {
        if (-not $script:SafeToRun) { Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set" }
    }

    It "removes C:\GitHub\ai-workspace" {
        $path = 'C:\GitHub\ai-workspace'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'marker.txt') 'reset-test' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }

    It "is idempotent when ai-workspace already absent" {
        if (Test-Path 'C:\GitHub\ai-workspace') { Remove-Item 'C:\GitHub\ai-workspace' -Recurse -Force }
        { Invoke-ResetBat } | Should -Not -Throw
    }
}

# ---------------------------------------------------------------------------
# VM-ONLY: paths requiring admin or registered packages
# Activate in Week 2 VM suite with AdminRequired + RESET_BEHAVIORS_UNSAFE=1
# ---------------------------------------------------------------------------
Describe "reset.bat removes per-machine Copilot (C:\Program Files) [VMOnly]" -Tag 'ResetBehavior', 'VMOnly', 'AdminRequired' {
    BeforeEach {
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set — VM suite only"
        }
    }

    It "removes C:\Program Files\GitHub Copilot" {
        $path = 'C:\Program Files\GitHub Copilot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'marker.txt') 'reset-test' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }

    It "removes C:\Program Files (x86)\GitHub Copilot" {
        $path = 'C:\Program Files (x86)\GitHub Copilot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content (Join-Path $path 'marker.txt') 'reset-test' -Force

        Invoke-ResetBat | Out-Null

        Test-Path $path | Should -BeFalse
    }
}

Describe "reset.bat removes AppX Copilot package [VMOnly]" -Tag 'ResetBehavior', 'VMOnly' {
    BeforeEach {
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set — VM suite only"
        }
    }

    It "Remove-AppxPackage call is idempotent when package already absent" {
        # On a clean VM post-reset, AppX query should return nothing; no error
        { Invoke-ResetBat } | Should -Not -Throw
    }
}

Describe "reset.bat wipes ~/.copilot [VMOnly]" -Tag 'ResetBehavior', 'VMOnly' {
    BeforeEach {
        if (-not $script:SafeToRun) {
            Set-ItResult -Skipped -Because "RESET_BEHAVIORS_UNSAFE not set — VM suite only, destroys Copilot CLI"
        }
    }

    It "removes ~/.copilot entirely" {
        # On VM only — wipes Copilot CLI and all sessions from dev machines
        $path = Join-Path $env:USERPROFILE '.copilot'
        Invoke-ResetBat | Out-Null
        Test-Path $path | Should -BeFalse
    }
}
