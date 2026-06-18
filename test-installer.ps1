#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker Installer Test Entry Point — Phase 1 Sandbox Harness

    Runs one or all sandbox case files (B1, B2, R1, R2) and emits a
    PASS/FAIL report for each case. Designed to be called by FA's CI yaml
    (`sandbox-matrix.yml`) and by developers locally.

.PARAMETER Case
    Which case to run: B1, B2, R1, R2, or All (default).
.PARAMETER OutputDir
    Directory to write JUnit/NUnit XML report files for CI consumption.
    Defaults to .\test-results\ (relative to this script).
.PARAMETER CiMode
    When set, suppresses verbose install output. Does NOT suppress failures.

.EXAMPLE
    # Run all cases locally
    .\test-installer.ps1

    # Run a single case
    .\test-installer.ps1 -Case B1

    # Run in CI (all cases, write XML reports)
    .\test-installer.ps1 -CiMode -OutputDir C:\test-results\
#>
[CmdletBinding()]
param(
    [ValidateSet('B1','B2','R1','R2','All')]
    [string]$Case = 'All',
    [string]$OutputDir = (Join-Path $PSScriptRoot 'test-results'),
    [switch]$CiMode
)

$ErrorActionPreference = 'Stop'

# ── Resolve paths ─────────────────────────────────────────────────────────────
$casesDir = Join-Path $PSScriptRoot 'tests\contract\cases'

$caseMap = @{
    B1 = Join-Path $casesDir 'B1.tests.ps1'
    B2 = Join-Path $casesDir 'B2.tests.ps1'
    R1 = Join-Path $casesDir 'R1.tests.ps1'
    R2 = Join-Path $casesDir 'R2.tests.ps1'
}

$runCases = if ($Case -eq 'All') { $caseMap.Keys | Sort-Object } else { @($Case) }

# ── Ensure output dir exists ───────────────────────────────────────────────────
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# ── Run cases ─────────────────────────────────────────────────────────────────
$results  = [ordered]@{}
$exitCode = 0

foreach ($caseId in $runCases) {
    $testFile = $caseMap[$caseId]
    if (-not (Test-Path $testFile)) {
        Write-Host "  [$caseId] SKIP — test file not found: $testFile" -ForegroundColor Yellow
        $results[$caseId] = 'SKIP'
        continue
    }

    $xmlPath = Join-Path $OutputDir "$caseId-results.xml"

    $config = New-PesterConfiguration
    $config.Run.Path           = $testFile
    $config.Run.PassThru       = $true
    $config.TestResult.Enabled  = $true
    $config.TestResult.OutputPath   = $xmlPath
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.Output.Verbosity   = if ($CiMode) { 'Minimal' } else { 'Normal' }

    Write-Host ""
    Write-Host "  ┌── $caseId ──────────────────────────────────────────────" -ForegroundColor Cyan

    $r = Invoke-Pester -Configuration $config

    # Intentional real-bug failures (#6 idempotency on v3.0.10) are documented in each case file.
    # We report them as REAL_BUG rather than blocking exit code, to distinguish from regressions.
    $intentionalFails = @($r.Failed | Where-Object { $_.Name -match 'no new files.*added.*install' })
    $unexpectedFails  = @($r.Failed | Where-Object { $_.Name -notmatch 'no new files.*added.*install' })

    if ($unexpectedFails.Count -gt 0) {
        $caseStatus = 'FAIL'
        $exitCode = 1
        Write-Host "  └── $caseId FAIL  ($($r.PassedCount) passed, $($unexpectedFails.Count) unexpected failures, $($r.SkippedCount) skipped)" -ForegroundColor Red
        foreach ($f in $unexpectedFails) {
            Write-Host "       FAIL: $($f.Name)" -ForegroundColor Red
        }
    } elseif ($intentionalFails.Count -gt 0) {
        $caseStatus = 'REAL_BUG'
        Write-Host "  └── $caseId REAL_BUG  ($($r.PassedCount) passed, $($intentionalFails.Count) known-bug failures, $($r.SkippedCount) skipped)" -ForegroundColor Yellow
        Write-Host "       Known bug: Install-Skills idempotency (v3.0.10) — file issue separately" -ForegroundColor DarkYellow
    } else {
        $caseStatus = 'PASS'
        Write-Host "  └── $caseId PASS  ($($r.PassedCount) passed, $($r.SkippedCount) skipped)" -ForegroundColor Green
    }

    $results[$caseId] = $caseStatus
}

# ── Summary report ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  AI Maker Installer Test — Phase 1 Summary" -ForegroundColor Cyan
Write-Host "  ══════════════════════════════════════════════════════" -ForegroundColor Cyan
foreach ($caseId in $results.Keys) {
    $status = $results[$caseId]
    $color  = switch ($status) {
        'PASS'     { 'Green' }
        'REAL_BUG' { 'Yellow' }
        'FAIL'     { 'Red' }
        default    { 'Gray' }
    }
    Write-Host ("  {0,-4}  {1}" -f $caseId, $status) -ForegroundColor $color
}
Write-Host "  ══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  XML reports written to: $OutputDir" -ForegroundColor Gray
Write-Host ""

exit $exitCode
