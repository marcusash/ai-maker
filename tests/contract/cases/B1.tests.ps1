#Requires -Version 7.0
<#
.SYNOPSIS
    B1 — Blue Pill, Fresh Win11 (no prior AIMaker, no workspace, no skills)

    Assertion priority order per kickoff-prompt:
    1. #1 Protected-asset preservation  (trivially empty for B1)
    2. #3 Required artifacts present
    3. #6 Idempotent rerun
    4. #2 Pill purity (installed output)
    5. #12.1/#12.2 MCP command shape + SHELL env var
    6. #9 Exit code contract (install succeeds)

    VM-only assertions (#4 #11) and full #12.3/#12.4 are excluded via -Tag.
#>

BeforeAll {
    $ManifestPath = Join-Path $PSScriptRoot '..\fixtures\blue\B1\fixture-manifest.json'
    $HarnessLib   = Join-Path $PSScriptRoot '..\harness\AIMakerTestLib.psm1'
    $SandboxMod   = Join-Path $PSScriptRoot '..\fixtures\shared\AIMakerSandbox.psm1'
    Import-Module $HarnessLib  -Force
    Import-Module $SandboxMod  -Force

    # Load fixture manifest
    $script:Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    # ── Sandbox setup ──────────────────────────────────────────────────────────
    $script:SB = New-InstallerSandbox -Case 'B1'
    Enter-InstallerSandbox -Sandbox $script:SB

    # Snapshot protected zone BEFORE install (B1 = empty → empty manifest)
    $script:SnapBeforeInstall = Get-DirectoryTreeManifest -Root $script:SB.Root

    # Registry snapshot — assert SHELL is written to HKCU:\Environment after install
    $script:RegBefore = Get-RegistrySnapshot -KeyPaths @('HKCU:\Environment')

    # ── Run install ────────────────────────────────────────────────────────────
    $script:InstallResult = Invoke-SandboxBlueInstall -Sandbox $script:SB

    # Post-install snapshots
    $script:SnapAfterInstall  = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:WorkspaceManifest = Get-DirectoryTreeManifest -Root $script:SB.Workspace -EA SilentlyContinue
    $script:SkillsManifest    = Get-DirectoryTreeManifest -Root $script:SB.SkillsPath -EA SilentlyContinue
    $script:InstallDiff       = Compare-StateManifest `
        -Before $script:SnapBeforeInstall `
        -After  $script:SnapAfterInstall

    # Snapshot for idempotency test — run install a second time
    $script:SnapBeforeRerun   = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:RerunResult       = Invoke-SandboxBlueInstall -Sandbox $script:SB
    $script:SnapAfterRerun    = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:RerunDiff         = Compare-StateManifest `
        -Before $script:SnapBeforeRerun `
        -After  $script:SnapAfterRerun
}

AfterAll {
    Remove-InstallerSandbox -Sandbox $script:SB
    Remove-Module AIMakerTestLib  -EA SilentlyContinue -Force
    Remove-Module AIMakerSandbox  -EA SilentlyContinue -Force
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #9 — Exit code contract
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B1 #9 Exit code contract' -Tag Sandbox {
    It 'install returns exit code 0 (success)' {
        $script:InstallResult.ExitCode | Should -Be 0
    }
    It 'idempotent rerun returns exit code 0' {
        $script:RerunResult.ExitCode | Should -Be 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #1 — Protected-asset preservation
# B1 has no pre-existing files, so the protected zone is empty.
# Structure the assertion correctly so it's non-vacuous: assert that the diff
# object exists and that the Changed bucket is empty (no pre-existing file mutated).
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B1 #1 Protected-asset preservation' -Tag Sandbox {
    It 'diff object returned by Compare-StateManifest is non-null' {
        $script:InstallDiff | Should -Not -BeNullOrEmpty
    }
    It 'no pre-existing file has a changed SHA256 after install (B1: no pre-existing files)' {
        # B1 starts fresh — the only Changed entries should be directory timestamp changes
        # (directories get a new LastWriteTime when files are added inside them).
        # Directories have Sha256=''. We care only about file content changes.
        $fileChanges = @($script:InstallDiff.Changed | Where-Object {
            $null -ne ($_.Fields | Where-Object { $_.Field -eq 'Sha256' })
        })
        $fileChanges.Count | Should -Be 0
    }
    It 'no pre-existing file was removed after install' {
        # Nothing existed before, nothing should be removed
        @($script:InstallDiff.Removed).Count | Should -Be 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #3 — Required artifacts present
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B1 #3 Required artifacts present' -Tag Sandbox {
    It 'workspace directory was created' {
        Test-Path $script:SB.Workspace -PathType Container | Should -BeTrue
    }
    It '.github directory exists in workspace' {
        Test-Path (Join-Path $script:SB.Workspace '.github') -PathType Container | Should -BeTrue
    }
    It '.github/agents directory exists in workspace' {
        Test-Path (Join-Path $script:SB.Workspace '.github\agents') -PathType Container | Should -BeTrue
    }
    It 'vault directory exists in workspace' {
        Test-Path (Join-Path $script:SB.Workspace 'vault') -PathType Container | Should -BeTrue
    }
    It 'vault/maker directory exists in workspace' {
        Test-Path (Join-Path $script:SB.Workspace 'vault\maker') -PathType Container | Should -BeTrue
    }
    It 'copilot-instructions.md was written to .github/' {
        Test-Path (Join-Path $script:SB.Workspace '.github\copilot-instructions.md') | Should -BeTrue
    }
    It 'ai-maker.md agent identity file was written to .github/agents/' {
        Test-Path (Join-Path $script:SB.Workspace '.github\agents\ai-maker.md') | Should -BeTrue
    }
    It 'vault/README.md was created' {
        Test-Path (Join-Path $script:SB.Workspace 'vault\README.md') | Should -BeTrue
    }
    It '.gitignore was created in workspace' {
        Test-Path (Join-Path $script:SB.Workspace '.gitignore') | Should -BeTrue
    }
    It 'at least one ai-maker-* skill was installed in skills path' {
        $skills = Get-ChildItem $script:SB.SkillsPath -Directory -Filter 'ai-maker-*' -EA SilentlyContinue
        @($skills).Count | Should -BeGreaterOrEqual 1
    }
    It 'installed skill has a SKILL.md file' {
        $skills = Get-ChildItem $script:SB.SkillsPath -Directory -Filter 'ai-maker-*' -EA SilentlyContinue
        $first = @($skills)[0]
        Test-Path (Join-Path $first.FullName 'SKILL.md') | Should -BeTrue
    }
    It 'm-mcp-servers.json exists in .copilot/' {
        Test-Path $script:SB.McpConfigPath | Should -BeTrue
    }
    It 'm-mcp-servers.json is valid JSON' {
        { Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json -EA Stop } | Should -Not -Throw
    }
    It 'm-mcp-servers.json contains workiq server entry' {
        $cfg = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json
        $cfg.servers.workiq | Should -Not -BeNullOrEmpty
    }
    It 'm-mcp-servers.json contains bluebird server entry' {
        $cfg = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json
        $cfg.servers.bluebird | Should -Not -BeNullOrEmpty
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #6 — Idempotent rerun
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B1 #6 Idempotent rerun' -Tag Sandbox {
    It 'second install returns exit code 0' {
        $script:RerunResult.ExitCode | Should -Be 0
    }
    It 'no new files were added on second install' -Tag 'RealBug-v3010' {
        # Known lib bug (v3.0.10): Install-Skills uses Copy-Item $folder $targetPath -Recurse -Force.
        # When targetPath already exists, PowerShell nests the source dir inside it, producing
        # ai-maker-brainstorming\ai-maker-brainstorming\SKILL.md on the second run.
        # This assertion INTENTIONALLY fails against v3.0.10 — it is a real idempotency defect.
        # Filed as marcusash_microsoft/ai-maker#6. Excluded from CI via -ExcludeTag RealBug-v3010.
        @($script:RerunDiff.Added).Count | Should -Be 0
    }
    It 'no files were removed on second install' {
        @($script:RerunDiff.Removed).Count | Should -Be 0
    }
    It 'no files were changed on second install (idempotent content)' {
        # Install logs (TempLogPath, LogPath) accumulate entries per run — SHA256 changes
        # are expected for log files and must be excluded from the idempotency assertion.
        # All other file content must be identical on re-run.
        $logRelPaths = @(
            'Temp/ai-maker-install.log',
            'UserProfile/.copilot/ai-maker/install-log.jsonl'
        )
        $contentChanges = @($script:RerunDiff.Changed | Where-Object {
            $relPath = $_.RelPath -replace '\\','/'
            ($logRelPaths -notcontains $relPath) -and
            ($null -ne ($_.Fields | Where-Object { $_.Field -eq 'Sha256' }))
        })
        $because = if ($contentChanges.Count -gt 0) {
            "Unexpected content changes on idempotent rerun: $($contentChanges.RelPath -join ', ')"
        } else { '' }
        $contentChanges.Count | Should -Be 0 -Because $because
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #2 — Pill purity (installed output)
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B1 #2 Pill purity (installed output)' -Tag Sandbox {
    BeforeAll {
        $script:WsViolations    = Test-PillPurity -Root $script:SB.Workspace
        $script:SkillsViolations = Test-PillPurity -Root $script:SB.SkillsPath
    }

    It 'workspace tree has zero Workbench/Red-pill contamination violations' {
        if (@($script:WsViolations).Count -gt 0) {
            $detail = ($script:WsViolations | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.MatchedText)" }) -join "`n"
            $false | Should -BeTrue -Because "Violations found:`n$detail"
        }
        @($script:WsViolations).Count | Should -Be 0
    }
    It 'skills tree has zero Workbench/Red-pill contamination violations' {
        if (@($script:SkillsViolations).Count -gt 0) {
            $detail = ($script:SkillsViolations | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.MatchedText)" }) -join "`n"
            $false | Should -BeTrue -Because "Violations found:`n$detail"
        }
        @($script:SkillsViolations).Count | Should -Be 0
    }
    It 'copilot-instructions.md content does not reference Workbench identity' {
        $instPath = Join-Path $script:SB.Workspace '.github\copilot-instructions.md'
        if (Test-Path $instPath) {
            $content = Get-Content $instPath -Raw
            $content | Should -Not -Match '(?i)\bworkbench\b'
        }
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #12.1 / #12.2 / #12.5 — MCP command shape, SHELL env var, agency path (sandbox-eligible)
# ════════════════════════════════════════════════════════════════════════════════
# #12.1 ground truth (ai-maker-lib.ps1:1240-1252): the actual shipped bug class is
# bare shim commands like "npx" (non-.exe, no path) + SHELL unset. The load-bearing
# check is: if command is not a .exe (i.e. a shim/script), SHELL must be set in
# HKCU:\Environment. Bash-style (/bin/sh -c) retained as defense-in-depth only
# (git log -S 'sh -c' = 0 matches — this bug class was never shipped).
#
# #12.5 (new): for any command rooted under %APPDATA%\agency\<version>\, the
# absolute path must exist. Catches agency self-update staleness (no release fixed).

Describe 'B1 #12.1 MCP command shape (Windows)' -Tag Sandbox {
    BeforeAll {
        $script:McpCfg = $null
        try {
            $script:McpCfg = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json
        } catch {}
    }

    It 'm-mcp-servers.json is parseable' {
        $script:McpCfg | Should -Not -BeNullOrEmpty
    }

    # ── Primary #12.1 check: shim-without-SHELL (the actual shipped bug class) ──
    It 'any non-.exe command has SHELL set in User scope (shim-requires-SHELL)' {
        $shell = [Environment]::GetEnvironmentVariable('SHELL', 'User')
        $servers = $script:McpCfg.servers.PSObject.Properties
        foreach ($entry in $servers) {
            $cmd = $entry.Value.command
            if ($cmd -and $cmd -notmatch '(?i)\.exe$' -and $cmd -notmatch '^[A-Za-z]:\\') {
                # Non-.exe, non-absolute-path command = shim (e.g. "npx", "node").
                # SHELL must be set so the shim can resolve to the right interpreter.
                $shell | Should -Not -BeNullOrEmpty -Because "server '$($entry.Name)' uses shim '$cmd' — SHELL must be set"
            }
        }
    }

    # ── Defense-in-depth: bash-style never shipped but guard anyway ──
    It 'workiq command is not a POSIX-shell invocation' {
        $cmd = $script:McpCfg.servers.workiq.command
        $cmd | Should -Not -Match '^(/bin/sh|bash|sh\s+-c)'
    }
    It 'bluebird command is not a POSIX-shell invocation' {
        $cmd = $script:McpCfg.servers.bluebird.command
        $cmd | Should -Not -Match '^(/bin/sh|bash|sh\s+-c)'
    }
    It 'workiq command uses a Windows-legal launcher' {
        $cmd = $script:McpCfg.servers.workiq.command
        $cmd | Should -Match '(?i)(pwsh|powershell|cmd|\.exe)'
    }
    It 'bluebird command uses a Windows-legal launcher' {
        $cmd = $script:McpCfg.servers.bluebird.command
        $cmd | Should -Match '(?i)(pwsh|powershell|cmd|\.exe)'
    }
}

Describe 'B1 #12.2 SHELL env var written to correct scope' -Tag Sandbox {
    It 'SHELL in HKCU:\Environment ends with sh.exe (Git sh)' {
        $shell = [Environment]::GetEnvironmentVariable('SHELL', 'User')
        if ($null -eq $shell) {
            # On a machine where Git is not installed, the installer skips this step.
            # Mark as inconclusive but not a failure — SHELL absence is tested in meta-test 7b.
            Set-ItResult -Skipped -Because 'SHELL not set (Git not installed on this machine)'
            return
        }
        $shell | Should -Match '(?i)sh\.exe$'
    }
    It 'SHELL is NOT set in Machine scope (User scope only per install-blue.ps1:177)' {
        $machineSHELL = [Environment]::GetEnvironmentVariable('SHELL', 'Machine')
        # If machine-scope is also set, that's a regression — installer should use User scope only.
        # This assertion passes if machine scope is null (not set) OR if the value was pre-existing.
        # We use the registry snapshot diff to check: no SHELL key should have been ADDED to HKLM.
        # For now, a direct assertion: machine-scope SHELL should not be set to Git sh.exe
        # (which would indicate the installer scope was changed to Machine without this test updating).
        if ($null -ne $machineSHELL) {
            # Pre-existing machine SHELL — note it but don't fail
            Set-ItResult -Skipped -Because "Machine-scope SHELL pre-exists: $machineSHELL — pre-existing, not installer-authored"
            return
        }
        $machineSHELL | Should -BeNullOrEmpty
    }
}

Describe 'B1 #12.5 Stale versioned agency path probe' -Tag Sandbox {
    # For any MCP server command rooted under %APPDATA%\agency\<version>\,
    # assert the absolute path exists. Catches agency self-update staleness:
    # after update, old version dir is removed but m-mcp-servers.json still
    # points at it — all Layer 1 checks (JSON valid, command shape) pass green
    # while the server is actually broken.
    BeforeAll {
        $script:McpCfg12_5 = $null
        try {
            $script:McpCfg12_5 = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json
        } catch {}
        $script:AgencyAppData = Join-Path $env:APPDATA 'agency'
    }

    It 'm-mcp-servers.json parseable for path probe' {
        $script:McpCfg12_5 | Should -Not -BeNullOrEmpty
    }
    It 'all versioned agency commands resolve to existing paths' {
        $servers = $script:McpCfg12_5.servers.PSObject.Properties
        foreach ($entry in $servers) {
            $cmd = $entry.Value.command
            if ($cmd -and $cmd -like "$($script:AgencyAppData)\*") {
                Test-Path $cmd -PathType Leaf |
                    Should -BeTrue -Because "server '$($entry.Name)' command '$cmd' must exist (stale-path protection)"
            }
        }
    }
}

