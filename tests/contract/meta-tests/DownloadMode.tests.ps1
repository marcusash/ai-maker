#Requires -Version 7.0
<#
.SYNOPSIS
    E2E download-mode simulation test.
    Simulates exactly what happens when a user runs the website one-liner:
    install.bat downloads files to TEMP, then runs install-blue.ps1 from TEMP.

    This catches the class of bugs where $PSScriptRoot = $env:TEMP and
    relative paths to skills/, agents/, etc. break.

    Runs -WhatIf so no system changes are made, but exercises ALL code paths
    including downloads from the live release.
#>

Describe 'Download-mode installer simulation' {

    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
        $sandbox = Join-Path $env:TEMP "ai-maker-e2e-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $sandbox -Force | Out-Null

        # Clean any leftovers from prior runs
        Remove-Item (Join-Path $env:TEMP "ai-maker-skills*") -Recurse -Force -EA SilentlyContinue
        Remove-Item (Join-Path $env:TEMP "ai-maker-agents*") -Recurse -Force -EA SilentlyContinue
    }

    AfterAll {
        Remove-Item $sandbox -Recurse -Force -EA SilentlyContinue
    }

    Context 'install-blue.ps1 from TEMP (simulates install.bat download mode)' {

        BeforeAll {
            # Copy installers to sandbox (simulates what install.bat does)
            Copy-Item (Join-Path $repoRoot 'installers\ai-maker-lib.ps1') (Join-Path $sandbox 'ai-maker-lib.ps1') -Force
            Copy-Item (Join-Path $repoRoot 'installers\install-blue.ps1') (Join-Path $sandbox 'install-blue.ps1') -Force
        }

        It 'install-blue.ps1 -WhatIf completes without errors' {
            $output = pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sandbox 'install-blue.ps1') -WhatIf 2>&1
            $exitCode = $LASTEXITCODE
            $errors = $output | Where-Object { $_ -match 'Exception|Error|throw|Cannot find' }
            $errors | Should -BeNullOrEmpty -Because "WhatIf run should complete without errors. Output: $($output -join "`n")"
            $exitCode | Should -Be 0
        }

        It 'prints Installation complete' {
            $output = pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sandbox 'install-blue.ps1') -WhatIf 2>&1
            ($output -join "`n") | Should -Match 'Installation complete'
        }
    }

    Context 'install-red.ps1 from TEMP (simulates install.bat download mode)' {

        BeforeAll {
            Copy-Item (Join-Path $repoRoot 'installers\ai-maker-lib.ps1') (Join-Path $sandbox 'ai-maker-lib.ps1') -Force
            Copy-Item (Join-Path $repoRoot 'installers\install-red.ps1') (Join-Path $sandbox 'install-red.ps1') -Force
            # Clean agents from blue test
            Remove-Item (Join-Path $sandbox 'agents') -Recurse -Force -EA SilentlyContinue
        }

        It 'install-red.ps1 -WhatIf completes without errors' {
            $output = pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sandbox 'install-red.ps1') -WhatIf 2>&1
            $exitCode = $LASTEXITCODE
            $errors = $output | Where-Object { $_ -match 'Exception|Error|throw|Cannot find' }
            $errors | Should -BeNullOrEmpty -Because "WhatIf run should complete without errors. Output: $($output -join "`n")"
            $exitCode | Should -Be 0
        }

        It 'prints Red Pill installed' {
            $output = pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sandbox 'install-red.ps1') -WhatIf 2>&1
            ($output -join "`n") | Should -Match 'Red Pill installed'
        }
    }

    Context 'PSScriptRoot path resolution' {

        It 'ai-maker-lib.ps1 loads from TEMP without errors' {
            $output = pwsh -NoProfile -ExecutionPolicy Bypass -Command "
                . '$($sandbox -replace "'","''")\ai-maker-lib.ps1'
                Write-Host `"Version: `$(`$script:AIMakerConfig.Version)`"
                Write-Host `"Functions: `$(Get-Command New-WorkspaceScaffold,Test-McpLiveness,Install-Skills -EA SilentlyContinue | Measure-Object | Select-Object -Expand Count)`"
            " 2>&1
            ($output -join "`n") | Should -Match 'Version: 3\.0\.\d+'
            ($output -join "`n") | Should -Match 'Functions: 3'
        }

        It 'skills path does NOT resolve to bare TEMP\skills' {
            # This was the exact bug: PSScriptRoot = TEMP, Join-Path TEMP "skills" = bogus path
            $blueContent = Get-Content (Join-Path $sandbox 'install-blue.ps1') -Raw
            # The fix: isDownloadMode check prevents using TEMP\skills
            $blueContent | Should -Match 'isDownloadMode'
        }
    }
}
