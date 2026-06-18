#Requires -Version 5.1
<#
.SYNOPSIS
    Inner runner: invoked by tests/test-installer.ps1 in a child pwsh process.
    All console chatter from install scripts goes to stdout (parent captures
    to log). Writes the 10-line Format-CaseReport output to -ReportFile.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('B1','B2','R1','R2')][string]$Case,
    [Parameter(Mandatory)][string]$OutputDir,
    [Parameter(Mandatory)][string]$ReportFile,
    [switch]$IncludeKnownBugs
)

$ErrorActionPreference = 'Stop'
$env:AIMAKER_TEST_CASE = $Case

$testsRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$caseFile  = Join-Path $testsRoot "contract\cases\$Case.tests.ps1"
$jsonOut   = Join-Path $OutputDir "$Case.json"

if (-not (Test-Path $caseFile)) {
    @(
        ('{0,-19} {1}' -f 'Case:', $Case),
        ('{0,-19} {1}' -f 'Result:', 'FAIL'),
        ('{0,-19} {1}' -f 'Assertions:', '0/0 pass'),
        ('{0,-19} {1}' -f 'Duration:', 'N/A'),
        ('{0,-19} {1}' -f 'Preservation:', 'N/A  (case file missing)'),
        ('{0,-19} {1}' -f 'Pill Purity:', 'N/A  (case file missing)'),
        ('{0,-19} {1}' -f 'Required Artifacts:', 'N/A  (case file missing)'),
        ('{0,-19} {1}' -f 'Idempotent:', 'N/A  (case file missing)'),
        ('{0,-19} {1}' -f 'Failed Assertions:', "missing-case-file:$caseFile"),
        ('{0,-19} {1}' -f 'Report URL:', $jsonOut)
    ) | Set-Content -Path $ReportFile -Encoding utf8
    exit 1
}

Import-Module Pester -MinimumVersion 5.5 -ErrorAction Stop

$baseConfig = Import-PowerShellDataFile (Join-Path $testsRoot 'contract\AIMakerTests.psd1')
$cfg = New-PesterConfiguration -Hashtable $baseConfig
$cfg.Run.Path         = $caseFile
$cfg.Run.PassThru     = $true
$cfg.Output.Verbosity = 'None'
if (-not $IncludeKnownBugs) {
    $cfg.Filter.ExcludeTag = 'RealBug-v3010'
}

$pesterResult = Invoke-Pester -Configuration $cfg

# Persist Pester result as JSON for diagnostics
try {
    $pesterResult | ConvertTo-Json -Depth 4 -WarningAction SilentlyContinue |
        Out-File -FilePath $jsonOut -Encoding utf8 -ErrorAction SilentlyContinue
} catch { }

# ---- Classify assertions into the 4 status lines Format-CaseReport expects ----
$allTests = @()
if ($pesterResult.Tests) { $allTests = @($pesterResult.Tests) }
elseif ($pesterResult.Containers) {
    foreach ($c in $pesterResult.Containers) {
        if ($c.Tests) { $allTests += @($c.Tests) }
        foreach ($b in @($c.Blocks)) {
            if ($b.Tests) { $allTests += @($b.Tests) }
            foreach ($bb in @($b.Blocks)) {
                if ($bb.Tests) { $allTests += @($bb.Tests) }
            }
        }
    }
}

$buckets = @{
    Preservation       = @('changed SHA256','protected zone','no pre-existing file','was removed after install','was removed after the second')
    PillPurity         = @('contamination','Pill Purity','pill identity','Workbench','Blue Pill','Red pill','Red-pill','workspace identity')
    RequiredArtifacts  = @('was written','was created','exists in workspace','exists in \.copilot','contains workiq','contains bluebird','SKILL\.md','agent identity','copilot-instructions','m-mcp-servers')
    Idempotent         = @('idempotent','second install','rerun returns','no new files','no files were removed','no files were changed','no content','no files removed','no files added')
}

function Get-BucketStatus {
    param([string]$bucket, $tests, $patternMap)
    $patterns = $patternMap[$bucket]
    $matching = @()
    foreach ($t in $tests) {
        $name = $t.ExpandedName; if (-not $name) { $name = $t.Name }
        foreach ($p in $patterns) { if ($name -match $p) { $matching += $t; break } }
    }
    if (@($matching).Count -eq 0) { return $null }
    $passed  = @($matching | Where-Object { $_.Result -eq 'Passed' }).Count
    $failed  = @($matching | Where-Object { $_.Result -eq 'Failed' }).Count
    $skipped = @($matching | Where-Object { $_.Result -eq 'Skipped' }).Count
    $notrun  = @($matching | Where-Object { $_.Result -eq 'NotRun' }).Count
    $ran     = @($matching).Count - $notrun
    if ($ran -eq 0) { return "N/A  (all excluded)" }
    if ($failed -gt 0) { "FAIL  ($failed/$ran failed)" }
    elseif ($passed -eq 0 -and $skipped -gt 0) { "N/A  ($skipped/$ran skipped)" }
    else { "PASS  ($passed/$ran)" }
}

$assertionResults = @{
    Preservation      = Get-BucketStatus 'Preservation' $allTests $buckets
    PillPurity        = Get-BucketStatus 'PillPurity' $allTests $buckets
    RequiredArtifacts = Get-BucketStatus 'RequiredArtifacts' $allTests $buckets
    Idempotent        = Get-BucketStatus 'Idempotent' $allTests $buckets
}

$failedAssertions = @()
foreach ($t in $allTests) {
    if ($t.Result -eq 'Failed') {
        $name = $t.ExpandedName; if (-not $name) { $name = $t.Name }
        $failedAssertions += $name
    }
}

$reportLines = & (Join-Path $testsRoot 'contract\harness\Format-CaseReport.ps1') `
    -Case $Case `
    -PesterResult $pesterResult `
    -AssertionResults $assertionResults `
    -FailedAssertions $failedAssertions `
    -ReportUrl ("tests/contract/reports/$Case.json")

$reportLines | Set-Content -Path $ReportFile -Encoding utf8

if ($pesterResult.FailedCount -gt 0) { exit 1 } else { exit 0 }
