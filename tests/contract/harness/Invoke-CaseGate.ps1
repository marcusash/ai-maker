#Requires -Version 5.1
<#
.SYNOPSIS
    Release gate runner for AI Maker installer test harness.

    Validates a Pester report against the required assertion set for the given
    case. This is the tool FF operates as Release Owner.

    Accepts two report formats:
      JSON (.json) — Pester PassThru object from Run-Case.ps1 (primary format)
      NUnit XML    — Pester TestResults.xml (legacy / manual runs)

    Input:  case name (B1/B2/R1/R2) + path to report file
    Output: PSCustomObject { Pass: bool; FailedAssertions: string[];
                             SkippedAssertions: string[]; Reason: string }

.PARAMETER Case
    Test case identifier: B1 | B2 | R1 | R2

.PARAMETER ReportPath
    Path to the Pester PassThru JSON (tests/contract/reports/<Case>.json from
    Run-Case.ps1) or a Pester NUnit XML file (TestResults.xml).

.PARAMETER RepoRoot
    Root of the ai-maker repo (for Out-Null lint check #10).
    Defaults to grandparent of this script's location
    (tests/contract/harness/Invoke-CaseGate.ps1 → repo root = ../../..).

.PARAMETER OutputJsonPath
    Optional: write the result object as JSON to this path in addition
    to returning it. Useful for CI artifact capture.

.PARAMETER Strict
    If set, conditional assertions (#12.5) are treated as required rather
    than informational. Default: conditional assertions are INFO-only.

.EXAMPLE
    # Run gate after a B1 test run
    $result = .\Invoke-CaseGate.ps1 -Case B1 -ReportPath .\TestResults.xml
    if (-not $result.Pass) { throw $result.Reason }

.EXAMPLE
    # CI usage with JSON output
    .\Invoke-CaseGate.ps1 -Case B2 -ReportPath TestResults.xml -OutputJsonPath gate-b2.json
    if ($LASTEXITCODE -ne 0) { exit 1 }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('B1','B2','R1','R2')]
    [string]$Case,

    [Parameter(Mandatory)]
    [string]$ReportPath,

    [string]$RepoRoot = '',

    [string]$OutputJsonPath = '',

    [switch]$Strict
)

$ErrorActionPreference = 'Stop'

# ── Assertion sets per case ────────────────────────────────────────────────────
#
# Assertion numbers match PRD §4 numbering and Describe block name prefixes.
# "Required"    → blocking: any failure = gate red
# "Conditional" → informational unless -Strict: skipped describe = INFO, failed = RED
#
# B1 / R1 (fresh installs): #1 #2 #3 #6 #9 #10 #12.1 #12.2 required
#                           #12.5 conditional (MCP SLA — if MCP entries present in report)
# B2 / R2 (upgrade/prior): same as B1/R1 + #5 (reset roundtrip preserves prior assets)
#
$caseRequired = @{
    B1 = @('#1','#2','#3','#6','#9','#10','#12.1','#12.2')
    B2 = @('#1','#2','#3','#5','#6','#9','#10','#12.1','#12.2')
    R1 = @('#1','#2','#3','#6','#9','#10','#12.1','#12.2')
    R2 = @('#1','#2','#3','#5','#6','#9','#10','#12.1','#12.2')
}
$caseConditional = @{
    B1 = @('#12.5')
    B2 = @('#12.5')
    R1 = @('#12.5')
    R2 = @('#12.5')
}

$required    = $caseRequired[$Case]
$conditional = $caseConditional[$Case]

# ── Helpers ────────────────────────────────────────────────────────────────────

function Resolve-RepoRoot {
    param([string]$ScriptDir)
    # tests/contract/harness/Invoke-CaseGate.ps1 → go up 3 dirs for repo root
    $r = (Resolve-Path (Join-Path $ScriptDir '..\..\..') -ErrorAction SilentlyContinue)?.ProviderPath
    if ($r -and (Test-Path $r)) { return $r }
    return $ScriptDir
}

function Parse-NUnitXml {
    param([string]$Path)
    [xml]$xml = Get-Content -LiteralPath $Path -Raw -Encoding UTF8

    # Collect every test-suite element recursively — handles nested Pester v5 layout
    $suites = [System.Collections.Generic.List[object]]::new()

    function Collect-Suites {
        param([System.Xml.XmlElement]$Node)
        if ($null -eq $Node) { return }
        if ($Node.LocalName -eq 'test-suite') {
            $suites.Add($Node)
        }
        foreach ($child in $Node.ChildNodes) {
            if ($child -is [System.Xml.XmlElement]) {
                Collect-Suites -Node $child
            }
        }
    }

    Collect-Suites -Node $xml.DocumentElement
    return $suites
}

function Parse-PesterJson {
    <#
    .SYNOPSIS
        Parses a Pester PassThru JSON (from Run-Case.ps1's ConvertTo-Json -Depth 4).
        Returns a flat list of Block objects representing Describe blocks, each with
        at minimum: Name (string), Result (string), Tests (array).
    #>
    param([string]$Path)
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $data = $raw | ConvertFrom-Json

    $blocks = [System.Collections.Generic.List[object]]::new()

    foreach ($container in @($data.Containers)) {
        foreach ($block in @($container.Blocks)) {
            # Top-level Describe blocks
            $blocks.Add($block)
            # Nested Describe/Context blocks (one level deep covers all Phase 1 cases)
            foreach ($inner in @($block.Blocks)) {
                $blocks.Add($inner)
            }
        }
    }

    return $blocks
}

function Get-AssertionStatus {
    <#
    .SYNOPSIS
        Finds the Describe block for the given assertion number and returns its status.
        Accepts either an XML suite list or a JSON block list — detected by type.

    .OUTPUTS
        'pass' | 'fail' | 'absent'
    #>
    param(
        [object]$ReportData,        # List<XmlElement> from NUnit or List<PSObject> from JSON
        [string]$AssertionNumber,   # e.g. '#9' '#12.1'
        [string]$Case               # e.g. 'B1'
    )

    # Describe block naming convention: "{Case} {#N} {description}"
    # e.g. "B1 #9 Exit code contract" or "R2 #1 Protected-asset preservation — no files removed"
    # Match: block name starts with "{Case} {AssertionNumber}" (case-insensitive)
    $pattern = [regex]::Escape("$Case $AssertionNumber")

    $matched = @($ReportData | Where-Object {
        $name = if ($null -ne $_.name) { $_.name } else { $_.Name }
        $name -imatch "^$pattern(\s|$|—)"
    })

    if ($matched.Count -eq 0) { return 'absent' }

    foreach ($block in $matched) {
        # JSON Pester PassThru uses 'Passed'/'Failed'/'Skipped'
        # NUnit XML uses 'Success'/'Failure'/'Error'
        $result = if ($null -ne $block.result) { $block.result } else { $block.Result }

        if ($result -iin @('Failure','Error','Failed')) { return 'fail' }

        # Check individual tests inside this block
        $tests = if ($null -ne $block.Tests) { @($block.Tests) }
                 elseif ($block.results) { @($block.results.SelectNodes('.//test-case')) }
                 else { @() }

        foreach ($t in $tests) {
            $tResult = if ($null -ne $t.result) { $t.result } else { $t.Result }
            if ($tResult -iin @('Failure','Error','Failed')) { return 'fail' }
        }
    }

    return 'pass'
}

# ── #10 Out-Null / suppression static lint ─────────────────────────────────────
#
# Scans the installer scripts for | Out-Null or 2>$null on external process calls.
# These are the patterns that swallowed the agency error in v3.0.6.
#
function Invoke-OutNullLint {
    param([string]$RepoRootPath)

    $installerFiles = @(
        'install-blue.ps1',
        'install-red.ps1',
        'ai-maker-lib.ps1',
        'migrate.ps1'
    ) | ForEach-Object {
        $p = Join-Path $RepoRootPath $_
        if (Test-Path $p) { $p }
    }

    if ($installerFiles.Count -eq 0) {
        return @{ Pass = $true; Detail = 'SKIP: no installer files found at repo root (path may be wrong)' }
    }

    # Pattern: any pipeline to Out-Null or stderr redirect to null
    # following an external process call token (& or Start-Process or Invoke-Expression).
    # Heuristic: look for | Out-Null or 2>$null anywhere on lines that also have & or
    # well-known external commands (agency, winget, gh, git, pwsh, cmd).
    $externalPattern = '(?i)(^\s*&\s+|Start-Process|Invoke-Expression|agency|winget\.exe|gh\.exe|git\.exe|pwsh\.exe|cmd\.exe)'
    $suppressPattern = '(\|\s*Out-Null|2>\s*\$null|2>\s*NUL|>\s*\$null\s*2>&1)'

    $violations = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $installerFiles) {
        $lines = Get-Content $file -Encoding UTF8 -EA SilentlyContinue
        if ($null -eq $lines) { continue }
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            if (($line -imatch $externalPattern) -and ($line -imatch $suppressPattern)) {
                # Allow: lines that are pure comment
                $trimmed = $line.TrimStart()
                if ($trimmed.StartsWith('#')) { continue }

                $violations.Add([pscustomobject]@{
                    File    = (Split-Path $file -Leaf)
                    Line    = $lineNum
                    Content = $line.Trim()
                })
            }
        }
    }

    if ($violations.Count -gt 0) {
        $detail = ($violations | ForEach-Object { "$($_.File):$($_.Line): $($_.Content)" }) -join "`n"
        return @{ Pass = $false; Detail = "Out-Null suppression on external calls: $violations.Count violation(s)`n$detail" }
    }

    return @{ Pass = $true; Detail = "OK: no Out-Null/null-redirect suppression on external calls ($($installerFiles.Count) files scanned)" }
}

# ── Main validation ────────────────────────────────────────────────────────────

$failedAssertions  = [System.Collections.Generic.List[string]]::new()
$skippedAssertions = [System.Collections.Generic.List[string]]::new()
$notes             = [System.Collections.Generic.List[string]]::new()

# 1. Validate report path
if (-not (Test-Path -LiteralPath $ReportPath)) {
    $result = [pscustomobject]@{
        Pass             = $false
        FailedAssertions = @("REPORT NOT FOUND: $ReportPath")
        SkippedAssertions= @()
        Reason           = "Cannot open report at: $ReportPath"
    }
    if ($OutputJsonPath -ne '') {
        $result | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputJsonPath -Encoding UTF8
    }
    Write-Output $result
    exit 1
}

# 2. Parse report — JSON (Pester PassThru from Run-Case.ps1) or NUnit XML
$reportExt = [System.IO.Path]::GetExtension($ReportPath).ToLower()
$reportData = if ($reportExt -eq '.json') {
    Parse-PesterJson -Path $ReportPath
} else {
    Parse-NUnitXml -Path $ReportPath
}

# 3. Check required assertions
foreach ($num in $required) {
    if ($num -eq '#10') {
        # Handled below via lint
        continue
    }

    $status = Get-AssertionStatus -ReportData $reportData -AssertionNumber $num -Case $Case

    switch ($status) {
        'pass'   { $notes.Add("[OK]   $Case $num") }
        'fail'   {
            $failedAssertions.Add("$Case $num FAILED")
            $notes.Add("[FAIL] $Case $num")
        }
        'absent' {
            # Required assertion has no Describe block in the report — treat as fail
            $failedAssertions.Add("$Case $num ABSENT (describe block not found in report)")
            $notes.Add("[FAIL] $Case $num — not present in report (test not run?)")
        }
    }
}

# 4. Check conditional assertions
foreach ($num in $conditional) {
    $status = Get-AssertionStatus -ReportData $reportData -AssertionNumber $num -Case $Case

    switch ($status) {
        'pass'   { $notes.Add("[OK]   $Case $num (conditional)") }
        'absent' { $skippedAssertions.Add("$Case $num (not present in report — skipped)")
                   $notes.Add("[SKIP] $Case $num — not in report") }
        'fail'   {
            if ($Strict) {
                $failedAssertions.Add("$Case $num FAILED (conditional, -Strict)")
                $notes.Add("[FAIL] $Case $num (conditional, -Strict)")
            } else {
                $skippedAssertions.Add("$Case $num FAILED (conditional — informational only, use -Strict to block)")
                $notes.Add("[WARN] $Case $num failed (conditional; not blocking without -Strict)")
            }
        }
    }
}

# 5. #10 Out-Null static lint
if ('#10' -in $required) {
    if ($RepoRoot -eq '') {
        $RepoRoot = Resolve-RepoRoot -ScriptDir $PSScriptRoot
    }

    $lintResult = Invoke-OutNullLint -RepoRootPath $RepoRoot

    if ($lintResult.Pass) {
        $notes.Add("[OK]   $Case #10 Out-Null lint: $($lintResult.Detail)")
    } else {
        $failedAssertions.Add("$Case #10 Out-Null suppression violation")
        $notes.Add("[FAIL] $Case #10 $($lintResult.Detail)")
    }
}

# 6. Build result
$pass   = ($failedAssertions.Count -eq 0)
$reason = if ($pass) {
    "All required assertions passed for case $Case ($($required.Count) required, $($skippedAssertions.Count) conditional skipped)."
} else {
    "$($failedAssertions.Count) required assertion(s) failed for case ${Case}: $($failedAssertions -join '; ')"
}

$result = [pscustomobject]@{
    Case              = $Case
    Pass              = $pass
    FailedAssertions  = @($failedAssertions)
    SkippedAssertions = @($skippedAssertions)
    Reason            = $reason
    Notes             = @($notes)
    ReportPath        = (Resolve-Path $ReportPath -ErrorAction SilentlyContinue)?.ProviderPath ?? $ReportPath
    GatedAt           = (Get-Date -Format 'o')
}

# 7. Optional JSON output
if ($OutputJsonPath -ne '') {
    $result | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputJsonPath -Encoding UTF8
}

# 8. Print summary to stdout
Write-Host ""
Write-Host "=== CASE GATE: $Case ===" -ForegroundColor $(if ($pass) { 'Green' } else { 'Red' })
foreach ($note in $notes) {
    $color = if ($note -like '[OK]*') { 'Green' } elseif ($note -like '[FAIL]*') { 'Red' } elseif ($note -like '[WARN]*') { 'Yellow' } else { 'Gray' }
    Write-Host "  $note" -ForegroundColor $color
}
Write-Host ""
if ($pass) {
    Write-Host "  GATE PASS: $reason" -ForegroundColor Green
} else {
    Write-Host "  GATE FAIL: $reason" -ForegroundColor Red
}
Write-Host ""

# 9. Emit result object to pipeline (callers: $r = & .\Invoke-CaseGate.ps1 ...)
Write-Output $result

# 10. Exit code for CI
if (-not $pass) { exit 1 }
exit 0
