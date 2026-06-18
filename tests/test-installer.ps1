#Requires -Version 5.1
<#
.SYNOPSIS
    AI Maker installer regression harness entry point
.PARAMETER Case
    Test case to run: B1 (Blue fresh) | B2 (Blue upgrade) | R1 (Red fresh) | R2 (Red upgrade)
.PARAMETER Tag
    Pester tag filter. Default: Sandbox (skips VMOnly).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('B1','B2','R1','R2')]
    [string]$Case,

    [string]$Tag = 'Sandbox'
)

$ErrorActionPreference = 'Stop'
$env:AIMAKER_TEST_CASE = $Case

$caseFile = Join-Path $PSScriptRoot "contract\cases\$Case.tests.ps1"
if (-not (Test-Path $caseFile)) {
    Write-Error "No test file for case '$Case': $caseFile"
    exit 1
}

$baseConfig = Import-PowerShellDataFile (Join-Path $PSScriptRoot "contract\AIMakerTests.psd1")
$cfg = New-PesterConfiguration -Hashtable $baseConfig
# Run only the specified case (not all files in cases/ directory)
$cfg.Run.Path = $caseFile

Invoke-Pester -Configuration $cfg
