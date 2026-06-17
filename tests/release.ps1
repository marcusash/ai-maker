#Requires -Version 5.1
<#
.SYNOPSIS
  Cut a release the right way: preflight first, refuse to publish if anything
  fails. Replaces the manual "git tag; gh release create" dance.

.PARAMETER Version
  e.g. v3.0.10

.PARAMETER Notes
  Release notes string. Required for create.

.EXAMPLE
  .\tests\release.ps1 -Version v3.0.10 -Notes "Fixes scaffold bug"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Notes,
    [string]$Repo = 'marcusash/ai-maker'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    # Token hygiene — env var shadows keyring auth
    Remove-Item Env:GH_TOKEN -EA SilentlyContinue

    # 1. Preflight (no URL probe yet — release doesn't exist)
    Write-Host "`n>>> Running preflight..." -ForegroundColor Cyan
    & "$PSScriptRoot\preflight.ps1" -Version $Version
    if ($LASTEXITCODE -ne 0) { throw "Preflight failed. Fix issues before releasing." }

    # 2. Build asset bundles
    $stage = Join-Path $env:TEMP "ai-maker-release-$Version"
    Remove-Item $stage -Recurse -Force -EA 0
    New-Item $stage -ItemType Directory -Force | Out-Null

    $loose = @('install.bat','install-blue.ps1','install-red.ps1','migrate.ps1','ai-maker-lib.ps1','reset.bat','reset.ps1','restore-mcp.ps1','diag-cpc.ps1')
    foreach ($f in $loose) { Copy-Item (Join-Path $root $f) $stage }

    Compress-Archive -Path (Join-Path $root 'agents\*') -DestinationPath (Join-Path $stage 'agents.zip') -Force
    Compress-Archive -Path (Join-Path $root 'skills\*') -DestinationPath (Join-Path $stage 'skills.zip') -Force

    Write-Host "`n>>> Staged $((Get-ChildItem $stage).Count) assets in $stage" -ForegroundColor Cyan

    # 3. Tag + push
    git tag $Version 2>&1 | Out-Host
    git push origin $Version 2>&1 | Out-Host

    # 4. Publish release
    $assets = (Get-ChildItem $stage | ForEach-Object { $_.FullName })
    & gh release create $Version -R $Repo -t "$Version" -n $Notes @assets

    # 5. Post-publish smoke
    Write-Host "`n>>> Post-publish URL probe..." -ForegroundColor Cyan
    & "$PSScriptRoot\preflight.ps1" -Version $Version -ProbeUrls
    if ($LASTEXITCODE -ne 0) { throw "Post-publish probe failed — release exists but URLs are broken." }

    Write-Host "`n[OK] $Version published and validated." -ForegroundColor Green
}
finally {
    Pop-Location
}
