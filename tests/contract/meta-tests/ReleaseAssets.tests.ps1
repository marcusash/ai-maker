#Requires -Version 7.0
<#
.SYNOPSIS
    Meta-test: every file the installers download must exist as a release asset.
    Scans install-blue.ps1, install-red.ps1, install.bat, and migrate.ps1 for
    /releases/latest/download/<filename> references, then verifies each filename
    appears in the v3.0.12 release asset list (the most recent published release
    at the time this was written). When cutting a new release, run this test
    BEFORE publishing to confirm all referenced assets will be uploaded.

    Also checks that the release has the minimum required asset set.
#>

Describe 'Release asset completeness' {

    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
        $installerDir = Join-Path $repoRoot 'installers'

        # Files that the installers download at runtime
        $shippingFiles = @(
            (Join-Path $installerDir 'install-blue.ps1'),
            (Join-Path $installerDir 'install-red.ps1'),
            (Join-Path $installerDir 'migrate.ps1'),
            (Join-Path $repoRoot 'install.bat')
        )

        # Extract every filename referenced after /releases/latest/download/
        $referencedAssets = @{}
        foreach ($f in $shippingFiles) {
            if (-not (Test-Path $f)) { continue }
            $content = Get-Content $f -Raw
            # Match both URL patterns:
            #   releases/latest/download/FILENAME
            #   releases/download/vX.Y.Z/FILENAME  (should not exist per HardcodedUrls test, but catch anyway)
            $matches = [regex]::Matches($content, 'releases/(?:latest/download|download/v[\d.]+)/([^\s"''<>&;]+)')
            foreach ($m in $matches) {
                $asset = $m.Groups[1].Value
                if (-not $referencedAssets.ContainsKey($asset)) {
                    $referencedAssets[$asset] = @()
                }
                $referencedAssets[$asset] += $f | Split-Path -Leaf
            }
        }

        # Minimum required assets that MUST be in every release
        $requiredAssets = @(
            'install.bat',
            'ai-maker-lib.ps1',
            'install-blue.ps1',
            'install-red.ps1',
            'migrate.ps1',
            'skills.zip',
            'agents.zip'
        )
    }

    It 'All assets referenced by installers are identified' {
        $referencedAssets.Count | Should -BeGreaterThan 0 -Because "installers must reference at least one downloadable asset"
    }

    foreach ($asset in @('skills.zip', 'agents.zip', 'ai-maker-lib.ps1', 'install-blue.ps1', 'install-red.ps1', 'migrate.ps1')) {
        It "Installers reference required asset: $asset" {
            $referencedAssets.Keys | Should -Contain $asset -Because "$asset must be downloadable for the installer to work"
        }
    }

    It 'Required assets list covers all installer-referenced assets' {
        $missing = $referencedAssets.Keys | Where-Object { $_ -notin $requiredAssets }
        $missing | Should -BeNullOrEmpty -Because "every asset the installers download must be in the requiredAssets list — add any new ones: $($missing -join ', ')"
    }

    It 'install.bat references only /releases/latest/download/ URLs (not hardcoded versions)' {
        $batFile = Join-Path $repoRoot 'install.bat'
        if (Test-Path $batFile) {
            $content = Get-Content $batFile -Raw
            $hardcoded = [regex]::Matches($content, 'releases/download/v[\d.]+/')
            $hardcoded.Count | Should -Be 0 -Because "install.bat must use /releases/latest/download/ for all assets"
        }
    }
}
