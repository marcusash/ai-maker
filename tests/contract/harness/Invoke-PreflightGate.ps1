#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker release pre-flight gate. Runs 10 invariants before tagging.

.DESCRIPTION
    Enforces every regression vector identified in the v3.0.0-v3.0.10 release
    cycle (FP postmortem) plus the Install-Skills idempotency fix landing in
    v3.0.11. Exits 0 if all gates pass, 1 on first failure. Designed to be
    the LAST step before `git tag v3.0.X`.

    Gates:
      G1  Harness — all 4 cases PASS exit 0 against vendored SUT
      G2  SHELL env var line present in install-blue.ps1 + install-red.ps1
      G3  Velopack 'app-*' glob probe present in install-blue.ps1 + install-red.ps1
      G4  MCP registers ONLY workiq + bluebird (no M365 surface enumeration)
      G5  Install-Skills uses idempotent copy pattern (the v3.0.11 fix)
      G6  Blue Purity — no workbench/red-pill leaks in Blue artifacts
      G7  URL coherence — all release URLs point at the right repo + tag
      G8  Lib version string matches expected release tag
      G9  install.bat layout — flat (no installers/ path dependency)
      G10 Skills count matches lib expectation (11 maker + 11 workbench = 22)

.PARAMETER Tag
    Release tag being prepared (e.g. 'v3.0.11'). Used for URL + version checks.

.PARAMETER SutVersion
    Vendored SUT version to validate against (e.g. 'v3.0.11'). Defaults to
    sandbox-pinned version.

.PARAMETER Verbose
    Show detailed per-gate output.

.EXAMPLE
    pwsh tests\contract\harness\Invoke-PreflightGate.ps1 -Tag v3.0.11
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Tag,
    [string]$SutVersion = 'v3.0.11',
    [string]$Repo = 'marcusash_microsoft/ai-maker'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

$script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$script:SutRoot  = Join-Path $script:RepoRoot "tests\contract\fixtures\sut\$SutVersion"
$script:Failures = @()

function Test-Gate {
    param([string]$Id, [string]$Name, [scriptblock]$Check)
    Write-Host -NoNewline ("  {0,-4} {1,-65} " -f $Id, $Name)
    try {
        $result = & $Check
        if ($result -eq $true -or $null -eq $result) {
            Write-Host '[PASS]' -ForegroundColor Green
            return $true
        } else {
            Write-Host '[FAIL]' -ForegroundColor Red
            Write-Host "        -> $result" -ForegroundColor DarkRed
            $script:Failures += "$Id $Name :: $result"
            return $false
        }
    } catch {
        Write-Host '[FAIL]' -ForegroundColor Red
        Write-Host "        -> $($_.Exception.Message)" -ForegroundColor DarkRed
        $script:Failures += "$Id $Name :: $($_.Exception.Message)"
        return $false
    }
}

Write-Host ""
Write-Host "=== AI Maker pre-flight gate — preparing $Tag against $Repo ===" -ForegroundColor Cyan
Write-Host "SUT root: $script:SutRoot" -ForegroundColor DarkGray
Write-Host ""

# ──────────────────────────────────────────────────────────────────────
# G1: Harness all 4 cases PASS exit 0
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G1' "Harness: B1/B2/R1/R2 all PASS exit 0 (vendored $SutVersion)" {
    $cases = 'B1','B2','R1','R2'
    $failed = @()
    foreach ($c in $cases) {
        $null = pwsh -NoProfile -File (Join-Path $script:RepoRoot 'tests\test-installer.ps1') -Case $c 2>&1
        if ($LASTEXITCODE -ne 0) { $failed += "$c (exit $LASTEXITCODE)" }
    }
    if ($failed.Count -eq 0) { $true } else { "Cases failed: $($failed -join ', ')" }
}

# ──────────────────────────────────────────────────────────────────────
# G2: SHELL env var line in install-blue/red.ps1 (FP v3.0.4 scar)
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G2' "SHELL env-var line present in install-blue.ps1 + install-red.ps1" {
    $blue = Get-Content (Join-Path $script:SutRoot 'install-blue.ps1') -Raw
    $red  = Get-Content (Join-Path $script:SutRoot 'install-red.ps1')  -Raw
    $pattern = 'SetEnvironmentVariable\("SHELL"'
    $blueOk = $blue -match $pattern
    $redOk  = $red  -match $pattern
    if ($blueOk -and $redOk) { $true }
    elseif (-not $blueOk) { "install-blue.ps1 missing SHELL SetEnvironmentVariable call" }
    else { "install-red.ps1 missing SHELL SetEnvironmentVariable call" }
}

# ──────────────────────────────────────────────────────────────────────
# G3: Velopack app-* glob probe (FP v3.0.5 scar)
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G3' "Velopack 'app-*' glob probe in install-blue.ps1 + install-red.ps1" {
    $blue = Get-Content (Join-Path $script:SutRoot 'install-blue.ps1') -Raw
    $red  = Get-Content (Join-Path $script:SutRoot 'install-red.ps1')  -Raw
    $pattern = 'APPDATA\\agency\\\*\\agency\.exe|APPDATA.*agency.*\*.*agency\.exe'
    if (($blue -match $pattern) -and ($red -match $pattern)) { $true }
    else { "Velopack glob probe missing or not matching expected pattern" }
}

# ──────────────────────────────────────────────────────────────────────
# G4: MCP register ONLY workiq + bluebird (FP v3.0.6 scar)
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G4' "MCP registration limited to workiq + bluebird (no M365 surfaces)" {
    $lib = Get-Content (Join-Path $script:SutRoot 'ai-maker-lib.ps1') -Raw
    # Look in Register-AgencyMcpServers function for forbidden surface names
    $regFuncStart = ($lib | Select-String 'function Register-AgencyMcpServers').Matches[0].Index
    if (-not $regFuncStart) { return "Register-AgencyMcpServers function not found" }
    $regFuncSlice = $lib.Substring($regFuncStart, [Math]::Min(8000, $lib.Length - $regFuncStart))
    $forbidden = 'mail','teams','planner','calendar','sharepoint','onedrive','m365-copilot','m365-user','word','graph'
    $leaks = @()
    foreach ($s in $forbidden) {
        # Match args = @("mcp", "<surface>") patterns
        if ($regFuncSlice -match "args\s*=\s*@\(['""]mcp['""]\s*,\s*['""]${s}['""]\s*\)") {
            $leaks += $s
        }
    }
    if ($leaks.Count -eq 0) { $true } else { "Forbidden M365 MCP surfaces registered: $($leaks -join ', ')" }
}

# ──────────────────────────────────────────────────────────────────────
# G5: Install-Skills uses idempotent copy pattern (v3.0.11 fix)
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G5' "Install-Skills uses idempotent copy pattern (no nested-dir bug)" {
    $lib = Get-Content (Join-Path $script:SutRoot 'ai-maker-lib.ps1') -Raw
    # The fix uses Join-Path $folder.FullName '*' — the bug used $folder.FullName directly
    $hasFix = $lib -match "Copy-Item\s+\(Join-Path\s+\`$folder\.FullName\s+'\*'\)\s+\`$targetPath\s+-Recurse\s+-Force"
    $hasBug = $lib -match "Copy-Item\s+\`$folder\.FullName\s+\`$targetPath\s+-Recurse\s+-Force"
    if ($hasFix -and -not $hasBug) { $true }
    elseif ($hasBug) { "v3.0.10 idempotency bug pattern still present" }
    else { "Install-Skills patch pattern not found (regression risk)" }
}

# ──────────────────────────────────────────────────────────────────────
# G6: Blue Purity — no workbench/red-pill leaks in Blue agent files
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G6' "Blue Purity — Blue mock-content has zero workbench/red-pill leaks" {
    $blueFile = Join-Path $script:RepoRoot 'tests\contract\fixtures\shared\mock-content\agents\copilot-instructions.blue.md'
    $makerFile = Join-Path $script:RepoRoot 'tests\contract\fixtures\shared\mock-content\agents\ai-maker.md'
    $leaks = @()
    foreach ($f in @($blueFile, $makerFile)) {
        if (-not (Test-Path $f)) { continue }
        $content = Get-Content $f -Raw
        # Match \bworkbench\b | red-pill | install-red
        $m = [regex]::Matches($content, '\bworkbench\b|red[- ]pill|install-red', 'IgnoreCase')
        if ($m.Count -gt 0) {
            $leaks += "$([System.IO.Path]::GetFileName($f)) has $($m.Count) leaks: $(($m.Value | Select-Object -Unique) -join ', ')"
        }
    }
    if ($leaks.Count -eq 0) { $true } else { "Leaks found: $($leaks -join '; ')" }
}

# ──────────────────────────────────────────────────────────────────────
# G7: URL coherence — install scripts point at right repo + tag
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G7' "URL coherence — install scripts + lib point at $Repo / $Tag" {
    $expectedUrl = "github.com/$Repo/releases/download/$Tag/"
    $scripts = 'install-blue.ps1','install-red.ps1','migrate.ps1','ai-maker-lib.ps1'
    $bad = @()
    foreach ($s in $scripts) {
        $content = Get-Content (Join-Path $script:SutRoot $s) -Raw
        $urls = [regex]::Matches($content, 'github\.com/[\w\-_]+/[\w\-_]+/releases/download/v[\d\.]+/')
        foreach ($u in $urls) {
            if ($u.Value -notmatch [regex]::Escape($expectedUrl)) {
                $bad += "$s : $($u.Value)"
            }
        }
    }
    if ($bad.Count -eq 0) { $true } else { "Stale URLs: $($bad -join '; ')" }
}

# ──────────────────────────────────────────────────────────────────────
# G8: Lib version string matches release tag
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G8' "Lib `$script:AIMakerConfig.Version matches release tag ($Tag)" {
    $expectedVer = $Tag -replace '^v',''
    $lib = Get-Content (Join-Path $script:SutRoot 'ai-maker-lib.ps1') -Raw
    if ($lib -match "Version\s+=\s+`"$([regex]::Escape($expectedVer))`"") { $true }
    else {
        $actual = if ($lib -match 'Version\s+=\s+"([\d\.]+)"') { $Matches[1] } else { 'unknown' }
        "Expected Version `"$expectedVer`", found `"$actual`""
    }
}

# ──────────────────────────────────────────────────────────────────────
# G9: install.bat at repo root references siblings (flat layout)
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G9' "install.bat references %~dp0install-*.ps1 (flat layout for release zip)" {
    $bat = Join-Path $script:RepoRoot 'install.bat'
    if (-not (Test-Path $bat)) { return "install.bat missing at repo root" }
    $content = Get-Content $bat -Raw
    if ($content -match '%~dp0install-blue\.ps1' -and $content -match '%~dp0install-red\.ps1') { $true }
    else { "install.bat doesn't reference flat-layout %~dp0install-blue.ps1 + install-red.ps1" }
}

# ──────────────────────────────────────────────────────────────────────
# G10: Skills count matches lib expectation (11 maker + 11 workbench = 22)
# ──────────────────────────────────────────────────────────────────────
Test-Gate 'G10' "Repo skills/ has 11 ai-maker-* + 11 ai-workbench-* dirs" {
    $skillsRoot = Join-Path $script:RepoRoot 'skills'
    if (-not (Test-Path $skillsRoot)) { return "skills/ dir missing at repo root" }
    $maker = (Get-ChildItem $skillsRoot -Directory -Filter 'ai-maker-*' -EA SilentlyContinue).Count
    $work  = (Get-ChildItem $skillsRoot -Directory -Filter 'ai-workbench-*' -EA SilentlyContinue).Count
    if ($maker -eq 11 -and $work -eq 11) { $true }
    else { "Expected 11+11, got $maker ai-maker-* + $work ai-workbench-*" }
}

# ──────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────
Write-Host ""
if ($script:Failures.Count -eq 0) {
    Write-Host "=== GATE PASS — 10/10 invariants satisfied. Safe to tag $Tag. ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== GATE FAIL — $($script:Failures.Count) of 10 invariants broken. DO NOT tag. ===" -ForegroundColor Red
    Write-Host ""
    foreach ($f in $script:Failures) { Write-Host "  $f" -ForegroundColor Red }
    Write-Host ""
    exit 1
}
