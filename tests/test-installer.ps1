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

$config = Join-Path $PSScriptRoot "AIMakerTests.psd1"
Invoke-Pester -Configuration (New-PesterConfiguration -Hashtable (Import-PowerShellDataFile $config))
