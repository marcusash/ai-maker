#Requires -Version 7.0
<#
.SYNOPSIS
    B2 — Blue Pill, with prior C:\AIMaker\ populated

    Assertion priority order per kickoff-prompt:
    1. #1 Protected-asset preservation  (load-bearing: legacy-maker files must survive)
    2. #3 Required artifacts present
    3. #6 Idempotent rerun
    4. #2 Pill purity (installed output)
    5. #12.1/#12.2 MCP command shape + SHELL env var
    6. #9 Exit code contract

    Protected zone = legacy-maker directory populated with realistic files including:
    ADS, non-default ACL, hardlink pair, read-only file (anti-vacuous-test requirement).

    VM-only assertions (#4 #11) are excluded via ExcludeTag in AIMakerTests.psd1.
#>

BeforeDiscovery {
    # Probe: can we create hardlinks? Required for non-vacuous HardLinkCount assertion.
    $script:HardLinkProbeOk = $false
    $probeFile = Join-Path ([System.IO.Path]::GetTempPath()) "aimaker-probe-$(([guid]::NewGuid()).ToString('N').Substring(0,8)).tmp"
    $probeLink = $probeFile + '.link'
    try {
        [System.IO.File]::WriteAllText($probeFile, 'probe')
        New-Item -ItemType HardLink -Path $probeLink -Target $probeFile -Force -EA Stop | Out-Null
        $script:HardLinkProbeOk = $true
        Remove-Item $probeLink -Force -EA SilentlyContinue
    } catch {
        try {
            & fsutil hardlink create $probeLink $probeFile 2>&1 | Out-Null
            $script:HardLinkProbeOk = ($LASTEXITCODE -eq 0)
            Remove-Item $probeLink -Force -EA SilentlyContinue
        } catch {}
    } finally {
        Remove-Item $probeFile -Force -EA SilentlyContinue
    }
}

BeforeAll {
    $ManifestPath = Join-Path $PSScriptRoot '..\fixtures\blue\B2\fixture-manifest.json'
    $HarnessLib   = Join-Path $PSScriptRoot '..\harness\AIMakerTestLib.psm1'
    $SandboxMod   = Join-Path $PSScriptRoot '..\fixtures\shared\AIMakerSandbox.psm1'
    Import-Module $HarnessLib  -Force
    Import-Module $SandboxMod  -Force

    $script:Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    # ── Sandbox + protected zone setup ────────────────────────────────────────
    $script:SB = New-InstallerSandbox -Case 'B2'
    Enter-InstallerSandbox -Sandbox $script:SB

    # Populate legacy-maker (protected zone) BEFORE install
    $script:ProtectedZone = New-B2ProtectedZone -Sandbox $script:SB

    # Snapshot protected zone before install — all six FileStateEntry fields
    $script:SnapProtectedBefore = Get-DirectoryTreeManifest -Root $script:ProtectedZone.Root

    # ── Run install ────────────────────────────────────────────────────────────
    $script:InstallResult = Invoke-SandboxBlueInstall -Sandbox $script:SB

    # Post-install snapshots
    $script:SnapProtectedAfter = Get-DirectoryTreeManifest -Root $script:ProtectedZone.Root
    $script:ProtectedDiff      = Compare-StateManifest `
        -Before $script:SnapProtectedBefore `
        -After  $script:SnapProtectedAfter

    # Full sandbox snapshot for idempotency
    $script:SnapAfterInstall  = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:WorkspaceManifest = Get-DirectoryTreeManifest -Root $script:SB.Workspace -EA SilentlyContinue
    $script:SkillsManifest    = Get-DirectoryTreeManifest -Root $script:SB.SkillsPath -EA SilentlyContinue

    # Idempotency: snapshot → rerun → diff
    $script:SnapBeforeRerun = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:RerunResult     = Invoke-SandboxBlueInstall -Sandbox $script:SB
    $script:SnapAfterRerun  = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:RerunDiff       = Compare-StateManifest `
        -Before $script:SnapBeforeRerun `
        -After  $script:SnapAfterRerun
}

AfterAll {
    # Unhide read-only files before cleanup so Remove-Item can delete them
    if ($script:ProtectedZone) {
        try { Set-ItemProperty $script:ProtectedZone.ReadOnlyFile -Name IsReadOnly -Value $false -EA SilentlyContinue } catch {}
    }
    Remove-InstallerSandbox -Sandbox $script:SB
    Remove-Module AIMakerTestLib -EA SilentlyContinue -Force
    Remove-Module AIMakerSandbox -EA SilentlyContinue -Force
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #9 — Exit code contract
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B2 #9 Exit code contract' -Tag Sandbox {
    It 'install returns exit code 0 even when legacy-maker is present' {
        # Installer detects legacy-maker and shows a warning, but does NOT fail.
        # "Your existing files will NOT be touched" — exit 0.
        $script:InstallResult.ExitCode | Should -Be 0
    }
    It 'idempotent rerun returns exit code 0' {
        $script:RerunResult.ExitCode | Should -Be 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #1 — Protected-asset preservation (LOAD-BEARING)
# B2 has a full protected zone: legacy-maker files must be byte-identical
# (SHA256, ACL, LastWriteUtc, CreatedUtc, AdsNames, IsReparsePoint, HardLinkCount)
# after the installer runs.
# Per PRD §6.3: "Cannot prove → unproven, NOT passed."
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B2 #1 Protected-asset preservation' -Tag Sandbox {
    It 'Compare-StateManifest of protected zone returns a non-null diff object' {
        $script:ProtectedDiff | Should -Not -BeNullOrEmpty
    }
    It 'no protected file was added or removed (protected zone count unchanged)' {
        @($script:ProtectedDiff.Added).Count   | Should -Be 0
        @($script:ProtectedDiff.Removed).Count | Should -Be 0
    }
    It 'no protected file has a changed SHA256 after install' {
        $sha256Changes = $script:ProtectedDiff.Changed | Where-Object {
            $_.Fields | Where-Object { $_.Field -eq 'Sha256' }
        }
        if (@($sha256Changes).Count -gt 0) {
            $detail = ($sha256Changes | ForEach-Object { "  $($_.RelPath)" }) -join "`n"
            $false | Should -BeTrue -Because "SHA256 changed for:`n$detail"
        }
        @($sha256Changes).Count | Should -Be 0
    }
    It 'no protected file has a changed size after install' {
        $sizeChanges = $script:ProtectedDiff.Changed | Where-Object {
            $_.Fields | Where-Object { $_.Field -eq 'SizeBytes' }
        }
        @($sizeChanges).Count | Should -Be 0
    }
    It 'ADS stream on protected ADS file is intact (AdsNames unchanged)' {
        $adsEntry = $script:SnapProtectedAfter | Where-Object {
            $_.RelPath -like '*with-ads*'
        }
        $adsEntry | Should -Not -BeNullOrEmpty
        # Stream 'protected-marker' must still be present
        $adsEntry.AdsNames | Should -Contain 'protected-marker'
    }
    It 'no ACL change on protected files (AclSddl unchanged)' {
        $aclChanges = $script:ProtectedDiff.Changed | Where-Object {
            $_.Fields | Where-Object { $_.Field -eq 'AclSddl' }
        }
        @($aclChanges).Count | Should -Be 0
    }
    It 'read-only file is still read-only after install' {
        $roFile = $script:ProtectedZone.ReadOnlyFile
        if (Test-Path $roFile) {
            (Get-Item $roFile).IsReadOnly | Should -BeTrue
        }
    }
    It 'HardLinkCount preserved on hardlinked protected files' -Skip:(-not $script:HardLinkProbeOk) {
        $hlOrigEntry = $script:SnapProtectedAfter | Where-Object {
            $_.RelPath -like '*hardlink-original*'
        }
        $hlOrigEntry | Should -Not -BeNullOrEmpty
        $hlOrigEntry.HardLinkCount | Should -BeGreaterOrEqual 2
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #3 — Required artifacts present (same as B1)
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B2 #3 Required artifacts present' -Tag Sandbox {
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
    It 'copilot-instructions.md was written' {
        Test-Path (Join-Path $script:SB.Workspace '.github\copilot-instructions.md') | Should -BeTrue
    }
    It 'ai-maker.md agent identity file was written' {
        Test-Path (Join-Path $script:SB.Workspace '.github\agents\ai-maker.md') | Should -BeTrue
    }
    It 'vault/README.md was created' {
        Test-Path (Join-Path $script:SB.Workspace 'vault\README.md') | Should -BeTrue
    }
    It '.gitignore was created' {
        Test-Path (Join-Path $script:SB.Workspace '.gitignore') | Should -BeTrue
    }
    It 'at least one ai-maker-* skill was installed' {
        $skills = Get-ChildItem $script:SB.SkillsPath -Directory -Filter 'ai-maker-*' -EA SilentlyContinue
        @($skills).Count | Should -BeGreaterOrEqual 1
    }
    It 'm-mcp-servers.json contains workiq and bluebird' {
        $cfg = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json
        $cfg.servers.workiq   | Should -Not -BeNullOrEmpty
        $cfg.servers.bluebird | Should -Not -BeNullOrEmpty
    }
    It 'workspace is in different location from legacy-maker (no clobber)' {
        # The installer must create a SEPARATE workspace, NOT inside legacy-maker
        $script:SB.Workspace | Should -Not -Match [regex]::Escape($script:SB.LegacyMaker)
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #6 — Idempotent rerun
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B2 #6 Idempotent rerun' -Tag Sandbox {
    It 'second install returns exit code 0' {
        $script:RerunResult.ExitCode | Should -Be 0
    }
    It 'no new files added on second install' {
        # Known lib bug (v3.0.10): Install-Skills nested directory on re-run (same as B1).
        # This assertion INTENTIONALLY fails against v3.0.10.
        @($script:RerunDiff.Added).Count | Should -Be 0
    }
    It 'no files removed on second install' {
        @($script:RerunDiff.Removed).Count | Should -Be 0
    }
    It 'no content (SHA256) changes on second install' {
        # Exclude install log files — they accumulate entries per run by design.
        $logRelPaths = @(
            'Temp/ai-maker-install.log',
            'UserProfile/.copilot/ai-maker/install-log.jsonl'
        )
        $contentChanges = @($script:RerunDiff.Changed | Where-Object {
            $relPath = $_.RelPath -replace '\\','/'
            ($logRelPaths -notcontains $relPath) -and
            ($null -ne ($_.Fields | Where-Object { $_.Field -eq 'Sha256' }))
        })
        $contentChanges.Count | Should -Be 0
    }
    It 'protected zone is still intact after second install' {
        # Re-snapshot protected zone after rerun
        $snapRerun = Get-DirectoryTreeManifest -Root $script:ProtectedZone.Root
        $rerunProtectedDiff = Compare-StateManifest -Before $script:SnapProtectedAfter -After $snapRerun
        @($rerunProtectedDiff.Changed).Count | Should -Be 0
        @($rerunProtectedDiff.Added).Count   | Should -Be 0
        @($rerunProtectedDiff.Removed).Count | Should -Be 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #2 — Pill purity (installed output)
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B2 #2 Pill purity (installed output)' -Tag Sandbox {
    BeforeAll {
        $script:WsViolations     = Test-PillPurity -Root $script:SB.Workspace
        $script:SkillsViolations = Test-PillPurity -Root $script:SB.SkillsPath
    }
    It 'workspace tree has zero Workbench/Red-pill contamination' {
        if (@($script:WsViolations).Count -gt 0) {
            $detail = ($script:WsViolations | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.MatchedText)" }) -join "`n"
            $false | Should -BeTrue -Because "Violations found:`n$detail"
        }
        @($script:WsViolations).Count | Should -Be 0
    }
    It 'skills tree has zero Workbench/Red-pill contamination' {
        if (@($script:SkillsViolations).Count -gt 0) {
            $detail = ($script:SkillsViolations | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.MatchedText)" }) -join "`n"
            $false | Should -BeTrue -Because "Violations found:`n$detail"
        }
        @($script:SkillsViolations).Count | Should -Be 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #12.1/#12.2 — MCP command shape + SHELL
# ════════════════════════════════════════════════════════════════════════════════

Describe 'B2 #12.1 MCP command shape (Windows)' -Tag Sandbox {
    BeforeAll {
        $script:McpCfg = $null
        try { $script:McpCfg = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json } catch {}
    }
    It 'workiq command is not a POSIX-shell invocation' {
        $script:McpCfg.servers.workiq.command | Should -Not -Match '^(/bin/sh|bash|sh\s+-c)'
    }
    It 'bluebird command is not a POSIX-shell invocation' {
        $script:McpCfg.servers.bluebird.command | Should -Not -Match '^(/bin/sh|bash|sh\s+-c)'
    }
    It 'workiq command uses Windows-legal launcher' {
        $script:McpCfg.servers.workiq.command | Should -Match '(?i)(pwsh|powershell|cmd|\.exe)'
    }
    It 'bluebird command uses Windows-legal launcher' {
        $script:McpCfg.servers.bluebird.command | Should -Match '(?i)(pwsh|powershell|cmd|\.exe)'
    }
}
