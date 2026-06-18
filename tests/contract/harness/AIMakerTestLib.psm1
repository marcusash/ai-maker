function Get-CaseReportPropertyValue {
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

function Format-CaseStatusLine {
    param(
        [Parameter(Mandatory)][string]$Label,
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$DefaultDetail
    )

    if ($null -eq $Value) {
        return ('{0,-19} N/A  ({1})' -f ($Label + ':'), $DefaultDetail)
    }

    if ($Value -is [string]) {
        return ('{0,-19} {1}' -f ($Label + ':'), $Value)
    }

    if ($Value -is [bool]) {
        $status = if ($Value) { 'PASS' } else { 'FAIL' }
        return ('{0,-19} {1}' -f ($Label + ':'), $status)
    }

    return ('{0,-19} {1}' -f ($Label + ':'), ([string]$Value))
}

function Test-CaseStateDiffEmpty {
    param([AllowNull()][object]$Diff)

    if ($null -eq $Diff) { return $null }

    foreach ($name in @('Added', 'Removed', 'Changed')) {
        $value = Get-CaseReportPropertyValue -InputObject $Diff -Names @($name)
        if ($null -ne $value -and @($value).Count -gt 0) {
            return $false
        }
    }

    return $true
}

function Format-CaseReport {
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

    $failedCount = Get-CaseReportPropertyValue -InputObject $PesterResult -Names @('FailedCount', 'Failed', 'FailedTestsCount')
    $passedCount = Get-CaseReportPropertyValue -InputObject $PesterResult -Names @('PassedCount', 'Passed', 'PassedTestsCount')
    $totalCount = Get-CaseReportPropertyValue -InputObject $PesterResult -Names @('TotalCount', 'Total', 'TotalTestsCount')
    $duration = Get-CaseReportPropertyValue -InputObject $PesterResult -Names @('Duration', 'Time', 'Elapsed')

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
        $diffEmpty = Test-CaseStateDiffEmpty -Diff $StateDiff
        if ($null -eq $diffEmpty) { 'N/A  (no state diff supplied)' }
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
        (Format-CaseStatusLine -Label 'Preservation' -Value $preservationValue -DefaultDetail 'no state diff supplied'),
        (Format-CaseStatusLine -Label 'Pill Purity' -Value $pillPurityValue -DefaultDetail 'not evaluated'),
        (Format-CaseStatusLine -Label 'Required Artifacts' -Value $requiredArtifactsValue -DefaultDetail 'not evaluated'),
        (Format-CaseStatusLine -Label 'Idempotent' -Value $idempotentValue -DefaultDetail 'not evaluated'),
        ('{0,-19} {1}' -f 'Failed Assertions:', $failedText),
        ('{0,-19} {1}' -f 'Report URL:', $ReportUrl)
    )

    if ($lines.Count -ne 10) {
        throw "Format-CaseReport internal error: expected 10 lines, got $($lines.Count)."
    }

    $lines
}

Export-ModuleMember -Function Format-CaseReport
