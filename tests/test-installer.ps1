#Requires -Version 5.1
<#
.SYNOPSIS
    AI Maker installer regression harness — entry point.

    Stdout is exactly 10 lines (Format-CaseReport). Pester chatter and install
    script Write-Host output are captured into <OutputDir>/<Case>-raw.log.

    Exit 0 if the case passes; 1 if any assertion fails (excluding tests
    tagged 'RealBug-v3010', which are the known-fail v3.0.10 idempotency
    regression that ships pre-tagged until v3.0.11 lands).

.PARAMETER Case
    Test case to run: B1 | B2 | R1 | R2.
.PARAMETER IncludeKnownBugs
    Include assertions tagged 'RealBug-v3010' (default: excluded).
.PARAMETER OutputDir
    Directory for per-case raw log + JSON result + report. Defaults to
    tests/contract/reports/.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('B1','B2','R1','R2')]
    [string]$Case,

    [switch]$IncludeKnownBugs,

    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

if (-not $OutputDir) {
    $OutputDir = Join-Path $PSScriptRoot 'contract\reports'
}
$null = New-Item -ItemType Directory -Force -Path $OutputDir

$rawLog     = Join-Path $OutputDir "$Case-raw.log"
$reportFile = Join-Path $OutputDir "$Case-report.txt"

# Clear prior artifacts for a clean run
Remove-Item $rawLog,$reportFile -ErrorAction SilentlyContinue

$runner = Join-Path $PSScriptRoot 'contract\harness\Run-Case.ps1'

$childArgs = @(
    '-NoLogo','-NoProfile','-File',$runner,
    '-Case',$Case,
    '-OutputDir',$OutputDir,
    '-ReportFile',$reportFile
)
if ($IncludeKnownBugs) { $childArgs += '-IncludeKnownBugs' }

# Run the case in a child pwsh; pipe ALL output streams to the raw log.
& pwsh @childArgs *>&1 | Out-File -FilePath $rawLog -Encoding utf8
$childExit = $LASTEXITCODE

if (Test-Path $reportFile) {
    Get-Content -Path $reportFile
} else {
    @(
        ('{0,-19} {1}' -f 'Case:', $Case),
        ('{0,-19} {1}' -f 'Result:', 'FAIL'),
        ('{0,-19} {1}' -f 'Assertions:', '0/0 pass'),
        ('{0,-19} {1}' -f 'Duration:', 'N/A'),
        ('{0,-19} {1}' -f 'Preservation:', 'N/A  (runner crashed)'),
        ('{0,-19} {1}' -f 'Pill Purity:', 'N/A  (runner crashed)'),
        ('{0,-19} {1}' -f 'Required Artifacts:', 'N/A  (runner crashed)'),
        ('{0,-19} {1}' -f 'Idempotent:', 'N/A  (runner crashed)'),
        ('{0,-19} {1}' -f 'Failed Assertions:', "runner-exit:$childExit; see $rawLog"),
        ('{0,-19} {1}' -f 'Report URL:', $rawLog)
    )
    if ($childExit -eq 0) { $childExit = 1 }
}

exit $childExit
