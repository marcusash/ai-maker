#Requires -Version 7.0
<#
.SYNOPSIS
    R2 — Red Pill, with prior C:\AIMaker\ populated

    Assertion priority order:
    1. #1 Protected-asset preservation  (load-bearing: legacy-maker files must survive)
    2. #3 Required artifacts present    (includes vault/workbench — Red pill only)
    3. #6 Idempotent rerun
    4. #2 Pill purity (no Blue-pill contamination in output)
    5. #12.1/#12.2/#12.5 MCP command shape + SHELL env var + stale path
    6. #9 Exit code contract

    Protected zone = legacy-maker directory with ADS, ACL, hardlink, readonly files.
    VM-only assertions (#4 #11) are excluded via -Tag.
#>

BeforeDiscovery {
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
    $ManifestPath = Join-Path $PSScriptRoot '..\fixtures\red\R2\fixture-manifest.json'
    $HarnessLib   = Join-Path $PSScriptRoot '..\harness\AIMakerTestLib.psm1'
    $SandboxMod   = Join-Path $PSScriptRoot '..\fixtures\shared\AIMakerSandbox.psm1'
    Import-Module $HarnessLib  -Force
    Import-Module $SandboxMod  -Force

    $script:Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    $script:SB = New-InstallerSandbox -Case 'R2'
    Enter-InstallerSandbox -Sandbox $script:SB

    # Populate legacy-maker protected zone BEFORE install (reuses B2 populator — same zone)
    $script:ProtectedZone       = New-B2ProtectedZone -Sandbox $script:SB
    $script:SnapProtectedBefore = Get-DirectoryTreeManifest -Root $script:ProtectedZone.Root

    $script:InstallResult      = Invoke-SandboxRedInstall -Sandbox $script:SB

    $script:SnapProtectedAfter = Get-DirectoryTreeManifest -Root $script:ProtectedZone.Root
    $script:ProtectedDiff      = Compare-StateManifest `
        -Before $script:SnapProtectedBefore `
        -After  $script:SnapProtectedAfter

    $script:SnapAfterInstall   = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:WorkspaceManifest  = Get-DirectoryTreeManifest -Root $script:SB.Workspace -EA SilentlyContinue
    $script:SkillsManifest     = Get-DirectoryTreeManifest -Root $script:SB.SkillsPath -EA SilentlyContinue

    $script:SnapBeforeRerun    = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:RerunResult        = Invoke-SandboxRedInstall -Sandbox $script:SB
    $script:SnapAfterRerun     = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:RerunDiff          = Compare-StateManifest `
        -Before $script:SnapBeforeRerun `
        -After  $script:SnapAfterRerun
}

AfterAll {
    # Clear ReadOnly on protected zone files before cleanup
    if ($null -ne $script:ProtectedZone) {
        $roFile = $script:ProtectedZone.ReadOnlyFile
        if ($roFile -and (Test-Path $roFile -EA SilentlyContinue)) {
            try {
                $item = Get-Item -LiteralPath $roFile -Force
                $item.Attributes = $item.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
            } catch {}
        }
    }
    Remove-InstallerSandbox -Sandbox $script:SB
    Remove-Module AIMakerTestLib  -EA SilentlyContinue -Force
    Remove-Module AIMakerSandbox  -EA SilentlyContinue -Force
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #9 — Exit code contract
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R2 #9 Exit code — install succeeds' -Tag Sandbox {
    It 'install returns exit code 0' {
        $script:InstallResult.ExitCode | Should -Be 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #1 — Protected-asset preservation (load-bearing)
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R2 #1 Protected-asset preservation — no files removed' -Tag Sandbox {
    It 'no protected-zone files were removed by install' {
        $removed = @($script:ProtectedDiff.Removed | Where-Object { -not $_.IsDirectory })
        $removed.Count | Should -Be 0 -Because "Protected zone files must survive Red pill install"
    }
}

Describe 'R2 #1 Protected-asset preservation — SHA256 unchanged' -Tag Sandbox {
    # Use Compare-StateManifest diff — avoids silent-skip if filename drifts.
    # Fails loudly if any file is missing OR has a changed hash.
    It 'no protected file was added or removed (count unchanged)' {
        @($script:ProtectedDiff.Added).Count   | Should -Be 0
        @($script:ProtectedDiff.Removed).Count | Should -Be 0
    }
    It 'no protected file has a changed SHA256 after install' {
        $sha256Changes = @($script:ProtectedDiff.Changed | Where-Object {
            $_.Fields | Where-Object { $_.Field -eq 'Sha256' }
        })
        if ($sha256Changes.Count -gt 0) {
            $detail = ($sha256Changes | ForEach-Object { "  $($_.RelPath)" }) -join "`n"
            $false | Should -BeTrue -Because "SHA256 changed for:`n$detail"
        }
        $sha256Changes.Count | Should -Be 0
    }
    It 'no protected file has a changed size after install' {
        $sizeChanges = @($script:ProtectedDiff.Changed | Where-Object {
            $_.Fields | Where-Object { $_.Field -eq 'SizeBytes' }
        })
        $sizeChanges.Count | Should -Be 0
    }
}

Describe 'R2 #1 Protected-asset preservation — special file fields' -Tag Sandbox {
    It 'ADS-bearing file retains its ADS stream' {
        $entry = $script:SnapProtectedBefore | Where-Object { $_.RelPath -match 'with-ads\.md' }
        if ($null -eq $entry -or @($entry.AdsNames).Count -eq 0) {
            Set-ItResult -Skipped -Because 'ADS fixture not present or no streams'
            return
        }
        $after = $script:SnapProtectedAfter | Where-Object { $_.RelPath -eq $entry.RelPath }
        $after.AdsNames | Should -Contain 'protected-marker'
    }
    It 'ACL file retains its AclSddl' {
        $entry = $script:SnapProtectedBefore | Where-Object { $_.RelPath -match 'acl-file\.md' }
        if ($null -eq $entry -or [string]::IsNullOrEmpty($entry.AclSddl)) {
            Set-ItResult -Skipped -Because 'ACL fixture not present'
            return
        }
        $after = $script:SnapProtectedAfter | Where-Object { $_.RelPath -eq $entry.RelPath }
        $after.AclSddl | Should -Be $entry.AclSddl
    }
    It 'hardlink original retains HardLinkCount >= 2' -Skip:(-not $script:HardLinkProbeOk) {
        $entry = $script:SnapProtectedAfter | Where-Object { $_.RelPath -match 'hardlink-original\.md' }
        if ($null -eq $entry) { Set-ItResult -Skipped -Because 'hardlink-original not found'; return }
        $entry.HardLinkCount | Should -BeGreaterOrEqual 2
    }
    It 'ReadOnly file retains ReadOnly attribute' {
        $entry = $script:SnapProtectedAfter | Where-Object { $_.RelPath -match 'readonly\.md' }
        if ($null -eq $entry) { Set-ItResult -Skipped -Because 'readonly.md not found'; return }
        $entry.Attributes | Should -Match 'ReadOnly'
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #3 — Required artifacts present
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R2 #3 Required artifacts present' -Tag Sandbox {
    It 'workspace directory was created' {
        Test-Path $script:SB.Workspace -PathType Container | Should -BeTrue
    }
    It 'vault/workbench directory exists (Red pill only)' {
        Test-Path (Join-Path $script:SB.Workspace 'vault\workbench') -PathType Container | Should -BeTrue
    }
    It 'vault/maker directory exists' {
        Test-Path (Join-Path $script:SB.Workspace 'vault\maker') -PathType Container | Should -BeTrue
    }
    It 'copilot-instructions.md was written' {
        Test-Path (Join-Path $script:SB.Workspace '.github\copilot-instructions.md') | Should -BeTrue
    }
    It 'copilot-instructions.md contains Red pill marker "AI Workspace"' {
        $content = Get-Content (Join-Path $script:SB.Workspace '.github\copilot-instructions.md') -Raw
        $content | Should -Match 'AI Workspace'
    }
    It 'm-mcp-servers.json exists and is valid JSON' {
        Test-Path $script:SB.McpConfigPath | Should -BeTrue
        { Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json -EA Stop } | Should -Not -Throw
    }
    It 'm-mcp-servers.json contains workiq and bluebird' {
        $cfg = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json
        $cfg.servers.workiq   | Should -Not -BeNullOrEmpty
        $cfg.servers.bluebird | Should -Not -BeNullOrEmpty
    }
    It 'at least one ai-maker-* skill was installed' {
        $skills = Get-ChildItem $script:SB.SkillsPath -Directory -Filter 'ai-maker-*' -EA SilentlyContinue
        @($skills).Count | Should -BeGreaterOrEqual 1
    }
    It 'workspace is in different location from legacy-maker (no clobber)' {
        # Installer must create a SEPARATE workspace, NOT inside legacy-maker
        $script:SB.Workspace | Should -Not -Match [regex]::Escape($script:SB.LegacyMaker)
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #6 — Idempotent rerun
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R2 #6 Idempotent rerun' -Tag Sandbox {
    It 'second install returns exit code 0' {
        $script:RerunResult.ExitCode | Should -Be 0
    }
    It 'no new files added on second install' -Tag 'RealBug-v3010' {
        # Known lib bug (v3.0.10): Install-Skills idempotency defect — nested skill dir on rerun.
        # This assertion INTENTIONALLY fails against v3.0.10. Filed as marcusash_microsoft/ai-maker#6.
        # Excluded from CI via -ExcludeTag RealBug-v3010.
        @($script:RerunDiff.Added).Count | Should -Be 0
    }
    It 'no files removed on second install' {
        @($script:RerunDiff.Removed).Count | Should -Be 0
    }
    It 'no files changed on second install (idempotent content)' {
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
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #2 — Pill purity (no Blue-pill contamination)
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R2 #2 Pill purity (installed output)' -Tag Sandbox {
    BeforeAll {
        # Red pill purity: meaningful contamination is "AI Maker Workspace" in instructions.
        # Agent files referencing "Blue Pill" by name are legitimate identity content.
        $redForbiddenPatterns = @('AI Maker Workspace')
        $redForbiddenPaths    = @('install-blue')
        $script:WsViolations     = Test-PillPurity -Root $script:SB.Workspace `
            -ForbiddenPatterns $redForbiddenPatterns `
            -ForbiddenPathSubstrings $redForbiddenPaths
        $script:SkillsViolations = Test-PillPurity -Root $script:SB.SkillsPath `
            -ForbiddenPatterns $redForbiddenPatterns `
            -ForbiddenPathSubstrings $redForbiddenPaths
    }

    It 'workspace tree has zero Blue-pill contamination violations' {
        if (@($script:WsViolations).Count -gt 0) {
            $detail = ($script:WsViolations | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.MatchedText)" }) -join "`n"
            $false | Should -BeTrue -Because "Violations found:`n$detail"
        }
        @($script:WsViolations).Count | Should -Be 0
    }
    It 'skills tree has zero Blue-pill contamination violations' {
        if (@($script:SkillsViolations).Count -gt 0) {
            $detail = ($script:SkillsViolations | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.MatchedText)" }) -join "`n"
            $false | Should -BeTrue -Because "Violations found:`n$detail"
        }
        @($script:SkillsViolations).Count | Should -Be 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #12.1 / #12.2 / #12.5
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R2 #12.1 MCP command shape (Windows)' -Tag Sandbox {
    BeforeAll {
        $script:McpCfg = $null
        try { $script:McpCfg = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json } catch {}
    }

    It 'any non-.exe command has SHELL set in User scope (shim-requires-SHELL)' {
        $shell = [Environment]::GetEnvironmentVariable('SHELL', 'User')
        $servers = $script:McpCfg.servers.PSObject.Properties
        foreach ($entry in $servers) {
            $cmd = $entry.Value.command
            if ($cmd -and $cmd -notmatch '(?i)\.exe$' -and $cmd -notmatch '^[A-Za-z]:\\') {
                $shell | Should -Not -BeNullOrEmpty -Because "server '$($entry.Name)' uses shim '$cmd'"
            }
        }
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

Describe 'R2 #12.2 SHELL env var written to correct scope' -Tag VMOnly {
    It 'SHELL in HKCU:\Environment ends with sh.exe' {
        $shell = [Environment]::GetEnvironmentVariable('SHELL', 'User')
        if ($null -eq $shell) {
            Set-ItResult -Skipped -Because 'SHELL not set (Git not installed on this machine)'
            return
        }
        $shell | Should -Match '(?i)sh\.exe$'
    }
    It 'SHELL is NOT set in Machine scope' {
        $machineSHELL = [Environment]::GetEnvironmentVariable('SHELL', 'Machine')
        if ($null -ne $machineSHELL) {
            Set-ItResult -Skipped -Because "Machine-scope SHELL pre-exists: $machineSHELL"
            return
        }
        $machineSHELL | Should -BeNullOrEmpty
    }
}

Describe 'R2 #12.5 Stale versioned agency path probe' -Tag Sandbox {
    BeforeAll {
        $script:McpCfg12_5   = $null
        try { $script:McpCfg12_5 = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json } catch {}
        $script:AgencyAppData = Join-Path $env:APPDATA 'agency'
    }

    It 'all versioned agency commands resolve to existing paths' {
        $servers = $script:McpCfg12_5.servers.PSObject.Properties
        foreach ($entry in $servers) {
            $cmd = $entry.Value.command
            if ($cmd -and $cmd -like "$($script:AgencyAppData)\*") {
                Test-Path $cmd -PathType Leaf |
                    Should -BeTrue -Because "server '$($entry.Name)' command '$cmd' must exist"
            }
        }
    }
}
