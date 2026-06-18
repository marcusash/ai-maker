#Requires -Version 5.1
<#
.SYNOPSIS
  Formats one installer contract case result as the exact 10-line report Marcus reads.

.DESCRIPTION
  Accepts a Pester result object, a state diff object from Compare-StateManifest,
  and a case name. The formatter intentionally emits exactly 10 lines in a stable
  order so CI can artifact and validate it without parsing full Pester output.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Case,

    [Parameter(Mandatory)]
    [AllowNull()]
    [object]$PesterResult,

    [Parameter()]
    [AllowNull()]
    [object]$StateDiff,

    [Parameter()]
    [hashtable]$AssertionResults = @{},

    [Parameter()]
    [string[]]$FailedAssertions = @(),

    [Parameter()]
    [string]$ReportUrl = "tests/contract/reports/$Case.json"
)

function Get-PropertyValue {
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string[]]$Names
    )

    if ($null -eq $InputObject) { return $null }

    foreach ($name in $Names) {
        if ($InputObject -is [hashtable] -and $InputObject.ContainsKey($name)) {
            return $InputObject[$name]
        }

        $property = $InputObject.PSObject.Properties[$name]
        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $null
}

function Format-StatusLine {
    param(
        [Parameter(Mandatory)][string]$Label,
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$DefaultDetail
    )

    if ($null -eq $Value) {
        return ('{0,-19} N/A  ({1})' -f ($Label + ':'), $DefaultDetail)
    }

    if ($Value -is [string]) {
        if ($Value -match '^(PASS|FAIL|N/A)\b') {
            return ('{0,-19} {1}' -f ($Label + ':'), $Value)
        }

        return ('{0,-19} {1}' -f ($Label + ':'), $Value)
    }

    if ($Value -is [bool]) {
        $status = if ($Value) { 'PASS' } else { 'FAIL' }
        return ('{0,-19} {1}' -f ($Label + ':'), $status)
    }

    return ('{0,-19} {1}' -f ($Label + ':'), ([string]$Value))
}

function Test-StateDiffEmpty {
    param([AllowNull()][object]$Diff)

    if ($null -eq $Diff) { return $null }

    foreach ($name in @('Added', 'Removed', 'Changed')) {
        $value = Get-PropertyValue -InputObject $Diff -Names @($name)
        if ($null -ne $value -and @($value).Count -gt 0) {
            return $false
        }
    }

    return $true
}

$failedCount = Get-PropertyValue -InputObject $PesterResult -Names @('FailedCount', 'Failed', 'FailedTestsCount')
$passedCount = Get-PropertyValue -InputObject $PesterResult -Names @('PassedCount', 'Passed', 'PassedTestsCount')
$totalCount = Get-PropertyValue -InputObject $PesterResult -Names @('TotalCount', 'Total', 'TotalTestsCount')
$duration = Get-PropertyValue -InputObject $PesterResult -Names @('Duration', 'Time', 'Elapsed')

if ($null -eq $failedCount) { $failedCount = 0 }
if ($null -eq $passedCount) { $passedCount = 0 }
if ($null -eq $totalCount) { $totalCount = [int]$passedCount + [int]$failedCount }

$result = if ([int]$failedCount -eq 0 -and @($FailedAssertions).Count -eq 0) { 'PASS' } else { 'FAIL' }
$assertions = '{0}/{1} pass' -f $passedCount, $totalCount

if ($duration -is [TimeSpan]) {
    $durationText = '{0:n1}s' -f $duration.TotalSeconds
}
elseif ($null -ne $duration -and "$duration" -ne '') {
    $durationText = [string]$duration
}
else {
    $durationText = 'N/A'
}

$preservationValue = if ($AssertionResults.ContainsKey('Preservation')) {
    $AssertionResults['Preservation']
}
else {
    $diffEmpty = Test-StateDiffEmpty -Diff $StateDiff
    if ($null -eq $diffEmpty) { 'N/A' }
    elseif ($diffEmpty) { 'PASS  (no protected-zone diffs)' }
    else { 'FAIL  (protected-zone diffs found)' }
}

$pillPurityValue = if ($AssertionResults.ContainsKey('PillPurity')) { $AssertionResults['PillPurity'] } else { $null }
$requiredArtifactsValue = if ($AssertionResults.ContainsKey('RequiredArtifacts')) { $AssertionResults['RequiredArtifacts'] } else { $null }
$idempotentValue = if ($AssertionResults.ContainsKey('Idempotent')) { $AssertionResults['Idempotent'] } else { $null }
$failedText = if (@($FailedAssertions).Count -gt 0) { ($FailedAssertions -join ', ') } else { '-' }

$lines = @(
    ('{0,-19} {1}' -f 'Case:', $Case),
    ('{0,-19} {1}' -f 'Result:', $result),
    ('{0,-19} {1}' -f 'Assertions:', $assertions),
    ('{0,-19} {1}' -f 'Duration:', $durationText),
    (Format-StatusLine -Label 'Preservation' -Value $preservationValue -DefaultDetail 'no state diff supplied'),
    (Format-StatusLine -Label 'Pill Purity' -Value $pillPurityValue -DefaultDetail 'not evaluated'),
    (Format-StatusLine -Label 'Required Artifacts' -Value $requiredArtifactsValue -DefaultDetail 'not evaluated'),
    (Format-StatusLine -Label 'Idempotent' -Value $idempotentValue -DefaultDetail 'not evaluated'),
    ('{0,-19} {1}' -f 'Failed Assertions:', $failedText),
    ('{0,-19} {1}' -f 'Report URL:', $ReportUrl)
)

if ($lines.Count -ne 10) {
    throw "Format-CaseReport internal error: expected 10 lines, got $($lines.Count)."
}

$lines | ForEach-Object { Write-Output $_ }
