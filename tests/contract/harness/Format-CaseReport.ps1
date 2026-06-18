#Requires -Version 5.1
<#
.SYNOPSIS
  Compatibility wrapper for the canonical Format-CaseReport function.
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

$modulePath = Join-Path $PSScriptRoot 'AIMakerTestLib.psm1'
Import-Module $modulePath -Force

Format-CaseReport @PSBoundParameters
