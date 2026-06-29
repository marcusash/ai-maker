#Requires -Version 7.0
<#
.SYNOPSIS
    Meta-test: no hardcoded version URLs in shipping files.
    Catches releases/download/vX.Y.Z that should be releases/latest/download/.
    Test fixtures (tests/contract/fixtures/) are intentionally excluded —
    they are frozen snapshots pinned to specific versions.
#>

Describe 'No hardcoded version URLs in shipping files' {

    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
        $fixtureDir = Join-Path $repoRoot 'tests\contract\fixtures'

        # Pattern: releases/download/v followed by digits (hardcoded version)
        $badPattern = 'releases/download/v\d'

        # Collect all shipping files (exclude test fixtures)
        $shippingFiles = Get-ChildItem $repoRoot -Recurse -File -Include '*.ps1','*.bat','*.html','*.md' |
            Where-Object { $_.FullName -notlike "$fixtureDir*" -and $_.FullName -notlike "*node_modules*" -and $_.FullName -notlike "*.git*" }
    }

    It 'Installer scripts have no hardcoded version URLs' {
        $installerFiles = $shippingFiles | Where-Object {
            $_.FullName -like '*installers*' -or $_.Name -eq 'install.bat'
        }
        $violations = @()
        foreach ($f in $installerFiles) {
            $hits = Select-String -Path $f.FullName -Pattern $badPattern
            foreach ($h in $hits) {
                $violations += "$($f.Name):$($h.LineNumber): $($h.Line.Trim())"
            }
        }
        $violations | Should -BeNullOrEmpty -Because "all installer URLs must use /releases/latest/download/"
    }

    It 'Website HTML files have no hardcoded version URLs' {
        $htmlFiles = $shippingFiles | Where-Object { $_.Extension -eq '.html' }
        $violations = @()
        foreach ($f in $htmlFiles) {
            $hits = Select-String -Path $f.FullName -Pattern $badPattern
            foreach ($h in $hits) {
                $violations += "$($f.Name):$($h.LineNumber): $($h.Line.Trim())"
            }
        }
        $violations | Should -BeNullOrEmpty -Because "all website URLs must use /releases/latest/download/"
    }

    It 'Release-extras docs have no hardcoded version URLs' {
        $extraFiles = $shippingFiles | Where-Object { $_.FullName -like '*release-extras*' }
        $violations = @()
        foreach ($f in $extraFiles) {
            $hits = Select-String -Path $f.FullName -Pattern $badPattern
            foreach ($h in $hits) {
                $violations += "$($f.Name):$($h.LineNumber): $($h.Line.Trim())"
            }
        }
        $violations | Should -BeNullOrEmpty -Because "all release docs must use /releases/latest/ URLs"
    }

    It 'No file outside test fixtures contains a hardcoded version download URL' {
        $violations = @()
        foreach ($f in $shippingFiles) {
            $hits = Select-String -Path $f.FullName -Pattern $badPattern
            foreach ($h in $hits) {
                $violations += "$($f.Name):$($h.LineNumber): $($h.Line.Trim())"
            }
        }
        $violations | Should -BeNullOrEmpty -Because "hardcoded version URLs break when a new release is published — use /releases/latest/download/ instead"
    }
}
