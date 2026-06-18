#Requires -Version 7.0
<#
.SYNOPSIS
    R1 — Red Pill, Fresh Win11 (no prior AIMaker, no workspace, no skills)

    Assertion priority order:
    1. #1 Protected-asset preservation  (trivially empty for R1)
    2. #3 Required artifacts present    (includes vault/workbench — Red pill only)
    3. #6 Idempotent rerun
    4. #2 Pill purity (no Blue-pill contamination in output)
    5. #12.1/#12.2/#12.5 MCP command shape + SHELL env var + stale path
    6. #9 Exit code contract

    VM-only assertions (#4 #11) and full #12.3/#12.4 are excluded via -Tag.
#>

BeforeAll {
    $ManifestPath = Join-Path $PSScriptRoot '..\fixtures\red\R1\fixture-manifest.json'
    $HarnessLib   = Join-Path $PSScriptRoot '..\harness\AIMakerTestLib.psm1'
    $SandboxMod   = Join-Path $PSScriptRoot '..\fixtures\shared\AIMakerSandbox.psm1'
    Import-Module $HarnessLib  -Force
    Import-Module $SandboxMod  -Force

    $script:Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    $script:SB = New-InstallerSandbox -Case 'R1'
    Enter-InstallerSandbox -Sandbox $script:SB

    $script:SnapBeforeInstall = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:RegBefore         = Get-RegistrySnapshot -KeyPaths @('HKCU:\Environment')

    $script:InstallResult     = Invoke-SandboxRedInstall -Sandbox $script:SB

    $script:SnapAfterInstall  = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:WorkspaceManifest = Get-DirectoryTreeManifest -Root $script:SB.Workspace -EA SilentlyContinue
    $script:SkillsManifest    = Get-DirectoryTreeManifest -Root $script:SB.SkillsPath -EA SilentlyContinue
    $script:InstallDiff       = Compare-StateManifest `
        -Before $script:SnapBeforeInstall `
        -After  $script:SnapAfterInstall

    $script:SnapBeforeRerun   = Get-DirectoryTreeManifest -Root $script:SB.Root
    $script:RerunResult       = Invoke-SandboxRedInstall -Sandbox $script:SB
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

Describe 'R1 #9 Exit code — install succeeds' -Tag Sandbox {
    It 'install returns exit code 0' {
        $script:InstallResult.ExitCode | Should -Be 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #1 — Protected-asset preservation (trivially empty for R1)
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R1 #1 Protected-asset preservation (fresh — no prior state)' -Tag Sandbox {
    It 'no pre-existing files were removed by install' {
        # R1 is a fresh install; SnapBeforeInstall should have no files under our control.
        # This assertion validates that the diff machinery works and produces a clean result.
        $contentRemovals = @($script:InstallDiff.Removed | Where-Object { -not $_.IsDirectory })
        $contentRemovals.Count | Should -Be 0
    }
    It 'no pre-existing files were corrupted by install (SHA256 unchanged)' {
        $contentChanges = @($script:InstallDiff.Changed | Where-Object {
            $null -ne ($_.Fields | Where-Object { $_.Field -eq 'Sha256' })
        })
        $contentChanges.Count | Should -Be 0
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #3 — Required artifacts present
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R1 #3 Required artifacts present' -Tag Sandbox {
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
    It 'vault/workbench directory exists in workspace (Red pill only)' {
        Test-Path (Join-Path $script:SB.Workspace 'vault\workbench') -PathType Container | Should -BeTrue
    }
    It 'copilot-instructions.md was written to .github/' {
        Test-Path (Join-Path $script:SB.Workspace '.github\copilot-instructions.md') | Should -BeTrue
    }
    It 'copilot-instructions.md contains Red pill marker "AI Workspace"' {
        $content = Get-Content (Join-Path $script:SB.Workspace '.github\copilot-instructions.md') -Raw
        $content | Should -Match 'AI Workspace'
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

Describe 'R1 #6 Idempotent rerun' -Tag Sandbox {
    It 'second install returns exit code 0' {
        $script:RerunResult.ExitCode | Should -Be 0
    }
    It 'no new files were added on second install' {
        # Known lib bug (v3.0.10): Install-Skills idempotency defect — nested skill dir on rerun.
        # This assertion INTENTIONALLY fails against v3.0.10. Filed as issue.
        @($script:RerunDiff.Added).Count | Should -Be 0
    }
    It 'no files were removed on second install' {
        @($script:RerunDiff.Removed).Count | Should -Be 0
    }
    It 'no files were changed on second install (idempotent content)' {
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
# ASSERTION #2 — Pill purity (installed output — no Blue-pill contamination)
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R1 #2 Pill purity (installed output)' -Tag Sandbox {
    BeforeAll {
        # Red pill purity: the meaningful contamination is the workspace instructions template
        # containing "AI Maker Workspace" (the Blue pill marker). Agent files that reference
        # "Blue Pill" by name are legitimate identity content, not contamination.
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
    It 'copilot-instructions.md does not contain "AI Maker Workspace" (Blue pill marker)' {
        $instPath = Join-Path $script:SB.Workspace '.github\copilot-instructions.md'
        if (Test-Path $instPath) {
            $content = Get-Content $instPath -Raw
            $content | Should -Not -Match 'AI Maker Workspace'
        }
    }
}

# ════════════════════════════════════════════════════════════════════════════════
# ASSERTION #12.1 / #12.2 / #12.5 — MCP command shape, SHELL env var, agency path
# ════════════════════════════════════════════════════════════════════════════════

Describe 'R1 #12.1 MCP command shape (Windows)' -Tag Sandbox {
    BeforeAll {
        $script:McpCfg = $null
        try { $script:McpCfg = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json } catch {}
    }

    It 'm-mcp-servers.json is parseable' {
        $script:McpCfg | Should -Not -BeNullOrEmpty
    }
    It 'any non-.exe command has SHELL set in User scope (shim-requires-SHELL)' {
        $shell = [Environment]::GetEnvironmentVariable('SHELL', 'User')
        $servers = $script:McpCfg.servers.PSObject.Properties
        foreach ($entry in $servers) {
            $cmd = $entry.Value.command
            if ($cmd -and $cmd -notmatch '(?i)\.exe$' -and $cmd -notmatch '^[A-Za-z]:\\') {
                $shell | Should -Not -BeNullOrEmpty -Because "server '$($entry.Name)' uses shim '$cmd' — SHELL must be set"
            }
        }
    }
    It 'workiq command is not a POSIX-shell invocation' {
        $script:McpCfg.servers.workiq.command | Should -Not -Match '^(/bin/sh|bash|sh\s+-c)'
    }
    It 'bluebird command is not a POSIX-shell invocation' {
        $script:McpCfg.servers.bluebird.command | Should -Not -Match '^(/bin/sh|bash|sh\s+-c)'
    }
    It 'workiq command uses a Windows-legal launcher' {
        $script:McpCfg.servers.workiq.command | Should -Match '(?i)(pwsh|powershell|cmd|\.exe)'
    }
    It 'bluebird command uses a Windows-legal launcher' {
        $script:McpCfg.servers.bluebird.command | Should -Match '(?i)(pwsh|powershell|cmd|\.exe)'
    }
}

Describe 'R1 #12.2 SHELL env var written to correct scope' -Tag Sandbox {
    It 'SHELL in HKCU:\Environment ends with sh.exe (Git sh)' {
        $shell = [Environment]::GetEnvironmentVariable('SHELL', 'User')
        if ($null -eq $shell) {
            Set-ItResult -Skipped -Because 'SHELL not set (Git not installed on this machine)'
            return
        }
        $shell | Should -Match '(?i)sh\.exe$'
    }
    It 'SHELL is NOT set in Machine scope (User scope only per install-blue.ps1:177)' {
        $machineSHELL = [Environment]::GetEnvironmentVariable('SHELL', 'Machine')
        if ($null -ne $machineSHELL) {
            Set-ItResult -Skipped -Because "Machine-scope SHELL pre-exists: $machineSHELL"
            return
        }
        $machineSHELL | Should -BeNullOrEmpty
    }
}

Describe 'R1 #12.5 Stale versioned agency path probe' -Tag Sandbox {
    BeforeAll {
        $script:McpCfg12_5   = $null
        try { $script:McpCfg12_5 = Get-Content $script:SB.McpConfigPath -Raw | ConvertFrom-Json } catch {}
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
                    Should -BeTrue -Because "server '$($entry.Name)' command '$cmd' must exist"
            }
        }
    }
}
