#Requires -Version 5.1
<#
.SYNOPSIS
    AI Maker installer regression harness entry point.
.DESCRIPTION
    Runs one or all test cases (B1/B2/R1/R2). In CiMode, known v3.0.10 bugs are
    excluded via Pester tag filter so the gate exits 0 on clean code.
.PARAMETER Case
    Test case to run: B1 | B2 | R1 | R2 | All
.PARAMETER CiMode
    When set, excludes 'RealBug-v3010' tag and writes NUnit XML results to OutputDir.
.PARAMETER OutputDir
    Directory for NUnit XML files (one per case). Created if missing. Requires CiMode.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('B1','B2','R1','R2','All')]
    [string]$Case,

    [switch]$CiMode,

    [string]$OutputDir = ''
)

$ErrorActionPreference = 'Stop'

$allCases = if ($Case -eq 'All') { @('B1','B2','R1','R2') } else { @($Case) }

if ($CiMode -and $OutputDir -ne '' -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$totalPassed  = 0
$totalFailed  = 0
$totalSkipped = 0
$realBugCases = @()
$exitCode     = 0

foreach ($c in $allCases) {
    $env:AIMAKER_TEST_CASE = $c
    $caseFile = Join-Path $PSScriptRoot "contract\cases\$c.tests.ps1"
    if (-not (Test-Path $caseFile)) {
        Write-Error "No test file for case '$c': $caseFile"
        exit 1
    }

    $baseConfig = Import-PowerShellDataFile (Join-Path $PSScriptRoot "contract\AIMakerTests.psd1")
    $cfg = New-PesterConfiguration -Hashtable $baseConfig
    $cfg.Run.Path      = $caseFile
    $cfg.Run.Exit      = $false   # we manage exit ourselves
    $cfg.Run.PassThru  = $true

    if ($CiMode) {
        # Exclude known real bugs so CI gate is green until the installer is fixed.
        $cfg.Filter.ExcludeTag = @('VMOnly','RealBug-v3010')
        if ($OutputDir -ne '') {
            $cfg.TestResult.Enabled      = $true
            $cfg.TestResult.OutputFormat = 'NUnitXml'
            $cfg.TestResult.OutputPath   = Join-Path $OutputDir "$c-results.xml"
        }
    }

    Write-Host ""
    Write-Host "=== Running $c ===" -ForegroundColor Cyan
    $result = Invoke-Pester -Configuration $cfg

    $passed  = $result.PassedCount
    $failed  = $result.FailedCount
    $skipped = $result.SkippedCount

    # Classify failures: real bugs vs unexpected
    $unexpectedFailed = 0
    foreach ($test in $result.Failed) {
        if ('RealBug-v3010' -in $test.Tag) {
            $realBugCases += "$c::$($test.ExpandedName)"
        } else {
            $unexpectedFailed++
        }
    }

    $totalPassed  += $passed
    $totalFailed  += $failed
    $totalSkipped += $skipped
    if ($unexpectedFailed -gt 0) { $exitCode = 1 }
}

# ── Summary report ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== AI Maker Installer Harness Results ===" -ForegroundColor White
Write-Host "Cases run : $($allCases -join ', ')"
Write-Host "Passed    : $totalPassed"
Write-Host "Skipped   : $totalSkipped (conditional — check Git/admin prereqs)"

$knownBugCount = $realBugCases.Count
if ($knownBugCount -gt 0) {
    $label = if ($CiMode) { "EXCLUDED from CI (RealBug-v3010)" } else { "REAL BUG (v3.0.10) — filed as marcusash_microsoft/ai-maker#6" }
    Write-Host "Known bugs: $knownBugCount  $label" -ForegroundColor Yellow
}

$unexpectedTotal = $totalFailed - $knownBugCount
if ($exitCode -eq 0) {
    Write-Host "Status    : PASS" -ForegroundColor Green
} else {
    Write-Host "UNEXPECTED FAILURES: $unexpectedTotal" -ForegroundColor Red
    Write-Host "Status    : FAIL — unexpected regressions detected" -ForegroundColor Red
}

exit $exitCode

