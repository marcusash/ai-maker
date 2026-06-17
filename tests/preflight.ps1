#Requires -Version 5.1
<#
.SYNOPSIS
  Release preflight for AI Maker. Runs every check that should have caught
  v3.0.7 / v3.0.8 / v3.0.9 install bugs before they shipped.

.DESCRIPTION
  Hard-fails if anything is wrong. Designed to gate `gh release create`.

  Checks performed:
    1. PowerShell parse — every .ps1 in the source tree must parse
    2. Version consistency — no stragglers from prior versions
    3. Asset manifest — every required artifact exists in working tree
    4. Scaffold parity — New-WorkspaceScaffold's create-dir list and
       verify-paths list agree on Blue vs Red (the v3.0.8 bug)
    5. URL probe — every release URL referenced in source returns 200
       (only when -ProbeUrls is passed; needs the release published already)
    6. WhatIf dry-run — install-blue.ps1 -WhatIf and install-red.ps1 -WhatIf
       must complete without error

.PARAMETER Version
  The version to validate (e.g. v3.0.10). Defaults to whatever string the
  current install.bat uses.

.PARAMETER ProbeUrls
  Probe live release URLs. Off by default so you can run preflight before
  publishing. Turn on for post-publish smoke.

.EXAMPLE
  .\tests\preflight.ps1
  .\tests\preflight.ps1 -Version v3.0.10
  .\tests\preflight.ps1 -ProbeUrls       # post-publish smoke
#>
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$ProbeUrls
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = @()
$checks   = 0

function Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green;  $script:checks++ }
function Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red;    $script:checks++; $script:failures += $msg }
function Section($title) { Write-Host "`n=== $title ===" -ForegroundColor Cyan }

# Auto-detect version from install.bat if not provided
if (-not $Version) {
    $bat = Get-Content (Join-Path $root 'install.bat') -Raw
    if ($bat -match 'releases/download/(v\d+\.\d+\.\d+)/') { $Version = $Matches[1] }
    else { throw "Could not auto-detect version from install.bat. Pass -Version." }
}
Write-Host "Preflight for $Version" -ForegroundColor Yellow
Write-Host "Source root: $root" -ForegroundColor DarkGray

# ── 1. PowerShell parse ──────────────────────────────────────────────────
Section "1. PowerShell syntax"
Get-ChildItem $root -Recurse -Filter *.ps1 -EA 0 |
    Where-Object { $_.FullName -notmatch '\\(node_modules|\.git)\\' } |
    ForEach-Object {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            Fail "$($_.Name): $($errors[0].Message) at line $($errors[0].Extent.StartLineNumber)"
        }
        else {
            Pass "$($_.Name)"
        }
    }

# ── 2. Version consistency ───────────────────────────────────────────────
Section "2. Version consistency ($Version everywhere)"
$verFiles = @('install.bat','install-blue.ps1','install-red.ps1','migrate.ps1','ai-maker-lib.ps1','index.html','pro/index.html','docs/migration-guide.html')
foreach ($rel in $verFiles) {
    $f = Join-Path $root $rel
    if (-not (Test-Path $f)) { continue }
    $content = Get-Content $f -Raw
    # Find all v3.x.x references
    $found = [regex]::Matches($content, 'v3\.0\.\d+') | ForEach-Object { $_.Value } | Select-Object -Unique
    $stragglers = $found | Where-Object { $_ -ne $Version }
    if ($stragglers) {
        Fail "$rel has stale version refs: $($stragglers -join ', ') (expected $Version)"
    }
    else {
        Pass "$rel"
    }
}

# ── 3. Asset manifest ────────────────────────────────────────────────────
Section "3. Required asset files present in working tree"
$required = @(
    'install.bat','install-blue.ps1','install-red.ps1','migrate.ps1',
    'ai-maker-lib.ps1','reset.bat','reset.ps1','restore-mcp.ps1','diag-cpc.ps1'
)
foreach ($r in $required) {
    if (Test-Path (Join-Path $root $r)) { Pass $r }
    else { Fail "Missing required asset: $r" }
}
# agents/ and skills/ source dirs (zipped at release time)
foreach ($d in @('agents','skills')) {
    $p = Join-Path $root $d
    if ((Test-Path $p) -and (Get-ChildItem $p -EA 0).Count -gt 0) { Pass "$d/ has content" }
    else { Fail "$d/ missing or empty (would zip to empty $d.zip)" }
}

# ── 4. Scaffold parity (the v3.0.8 bug) ──────────────────────────────────
Section "4. Scaffold create-dir vs verify-paths parity"
$lib = Get-Content (Join-Path $root 'ai-maker-lib.ps1') -Raw
# Extract Blue and Red dir lists from $dirs and $requiredPaths
$blueDirs   = ([regex]::Matches($lib, '(?s)# Blue.*?\$dirs\s*=\s*@\((.*?)\)') | Select -First 1).Groups[1].Value
$redDirs    = ([regex]::Matches($lib, '(?s)\$Pill -eq "red".*?\$dirs\s*=\s*@\((.*?)\)') | Select -First 1).Groups[1].Value
$requiredPaths = ([regex]::Matches($lib, '(?s)\$requiredPaths\s*=\s*@\((.*?)\)') | Select -First 1).Groups[1].Value

$workbenchInBlue = ($blueDirs -match 'workbench') -or ($requiredPaths -match 'workbench(?![^)]*\$Pill -eq "red")')
$workbenchInRed  = $redDirs -match 'workbench'

if (-not $workbenchInBlue -and $workbenchInRed) {
    Pass "Blue scaffold does NOT require vault\workbench; Red does"
}
else {
    if ($workbenchInBlue) { Fail "Blue scaffold incorrectly requires vault\workbench (the v3.0.8 bug)" }
    if (-not $workbenchInRed) { Fail "Red scaffold missing vault\workbench" }
}

# ── 5. WhatIf dry-run ────────────────────────────────────────────────────
Section "5. WhatIf dry-run of installers"
foreach ($script in @('install-blue.ps1','install-red.ps1')) {
    $p = Join-Path $root $script
    if (-not (Test-Path $p)) { continue }
    try {
        # Run in a child PowerShell so it can't pollute current session
        $tmpWs = Join-Path $env:TEMP "preflight-$(Get-Random)"
        $out = & powershell -NoProfile -Command "& '$p' -WhatIf -WorkspacePath '$tmpWs' 2>&1" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Fail "$script -WhatIf exit $LASTEXITCODE — last line: $(($out | Select -Last 1))"
        }
        else {
            Pass "$script -WhatIf clean"
        }
        Remove-Item $tmpWs -Recurse -Force -EA 0
    }
    catch {
        Fail "$script -WhatIf threw: $($_.Exception.Message)"
    }
}

# ── 6. URL probe (post-publish only) ─────────────────────────────────────
if ($ProbeUrls) {
    Section "6. Live URL probe"
    $urls = @()
    Get-ChildItem $root -Recurse -Include *.bat,*.ps1,*.html -EA 0 |
        Where-Object { $_.FullName -notmatch '\\(node_modules|\.git)\\' } |
        ForEach-Object {
            $c = Get-Content $_.FullName -Raw
            $matches = [regex]::Matches($c, "https://github\.com/marcusash/ai-maker/releases/download/$([regex]::Escape($Version))/[A-Za-z0-9._-]+")
            foreach ($m in $matches) { $urls += $m.Value }
            # Also probe github.io site URLs
            $matches2 = [regex]::Matches($c, "https://marcusash\.github\.io/ai-maker/[A-Za-z0-9._/-]+")
            foreach ($m in $matches2) { $urls += $m.Value }
        }
    $urls = $urls | Sort -Unique
    foreach ($u in $urls) {
        try {
            $r = Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 15 -EA Stop
            if ($r.StatusCode -eq 200) { Pass $u }
            else { Fail "$u → HTTP $($r.StatusCode)" }
        }
        catch {
            Fail "$u → $($_.Exception.Message)"
        }
    }
}

# ── Summary ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
if ($failures.Count -eq 0) {
    Write-Host "PREFLIGHT PASSED  ($checks checks)" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "PREFLIGHT FAILED  ($($failures.Count) of $checks checks)" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
