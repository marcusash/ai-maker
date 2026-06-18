#Requires -Version 7.0
<#
.SYNOPSIS
  Runs one AI Maker installer sandbox contract case and emits the 10-line report.

.DESCRIPTION
  This is the stable CI entrypoint used by .github/workflows/installer-tests.yml.
  Phase 1 fixtures can expand the case-specific internals without changing the
  workflow command Marcus and GitHub Actions run.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('B1', 'B2', 'R1', 'R2')]
    [string]$Case
)

$ErrorActionPreference = 'Stop'

$testsRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $testsRoot
$reportsDir = Join-Path $repoRoot 'tests\contract\reports'
$formatter = Join-Path $repoRoot 'tests\contract\harness\Format-CaseReport.ps1'

New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

if (-not (Test-Path $formatter)) {
    throw "Case report formatter not found: $formatter"
}

$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$jsonReport = Join-Path $reportsDir "$Case-$timestamp.json"
$pesterLog = Join-Path $reportsDir "$Case-$timestamp-pester.log"

$safeTestFiles = @(
    Join-Path $testsRoot 'agency-detection.tests.ps1'
    Join-Path $testsRoot 'fail-forward.tests.ps1'
    Join-Path $testsRoot 'prereq-sim.tests.ps1'
) | Where-Object { Test-Path $_ }

if (@($safeTestFiles).Count -eq 0) {
    throw "No sandbox-safe installer test files found under $testsRoot."
}

$config = New-PesterConfiguration
$config.Run.Path = $safeTestFiles
$config.Run.PassThru = $true
$config.Output.Verbosity = 'None'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = $jsonReport
$config.TestResult.OutputFormat = 'NUnitXml'

$result = Invoke-Pester -Configuration $config 6>> $pesterLog

$failedAssertions = @()
if ($result.FailedCount -gt 0) {
    $failedAssertions += '#pester'
}

& $formatter `
    -Case $Case `
    -PesterResult $result `
    -StateDiff $null `
    -AssertionResults @{
        Preservation = 'N/A  (Phase 1 fixture pending)'
        PillPurity = 'N/A  (Phase 1 fixture pending)'
        RequiredArtifacts = 'N/A  (Phase 1 fixture pending)'
        Idempotent = 'N/A  (Phase 1 fixture pending)'
    } `
    -FailedAssertions $failedAssertions `
    -ReportUrl ("tests/contract/reports/{0}" -f (Split-Path -Leaf $jsonReport))

if ($result.FailedCount -gt 0) {
    exit 1
}

exit 0
