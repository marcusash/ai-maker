# AI Maker Post-Install Verification
# Usage: test.ps1 [-WorkspacePath C:\AIMaker]
# Exit 0 = all passed, 1 = one or more failed.

param([string]$WorkspacePath = "C:\AIMaker")

$ErrorActionPreference = "Continue"
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$passed  = 0
$failed  = 0
$results = [System.Collections.Generic.List[hashtable]]::new()

function Test-Case {
    param([string]$Name, [scriptblock]$Test)
    try {
        $result = & $Test
        if ($result -like "PASS*") { $script:passed++; $results.Add(@{ name = $Name; status = "PASS"; detail = $result }) }
        else                        { $script:failed++; $results.Add(@{ name = $Name; status = "FAIL"; detail = $result }) }
    } catch {
        $script:failed++
        $results.Add(@{ name = $Name; status = "FAIL"; detail = $_.Exception.Message })
    }
}

Write-Host "`n[AI Maker Tests] Running post-install verification..." -ForegroundColor Cyan

Test-Case "T01: Node.js available" {
    $v = node --version 2>&1
    if ($LASTEXITCODE -eq 0 -and $v -match "v\d+") { return "PASS: $v" }
    return "FAIL: node not found"
}

Test-Case "T02: Git available" {
    $v = git --version 2>&1
    if ($LASTEXITCODE -eq 0) { return "PASS: $v" }
    return "FAIL: git not found"
}

Test-Case "T03: gh CLI available" {
    $v = gh --version 2>&1
    if ($LASTEXITCODE -eq 0) { return "PASS: $($v | Select-Object -First 1)" }
    return "FAIL: gh not found"
}

Test-Case "T04: GitHub auth active" {
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { return "PASS" }
    return "FAIL: not authenticated. Run: gh auth login"
}

Test-Case "T05: Copilot CLI available" {
    gh copilot --version 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { return "PASS" }
    return "FAIL: gh copilot not available. Run: gh extension install github/gh-copilot"
}

Test-Case "T06: WorkIQ configured" {
    $check = npm list -g @microsoft/workiq 2>&1
    if ($check -match "workiq") { return "PASS" }
    $mcpPath = "$env:APPDATA\GitHub Copilot\mcp.json"
    if (Test-Path $mcpPath) {
        $mcp = Get-Content $mcpPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($mcp.mcpServers.workiq) { return "PASS (via MCP config)" }
    }
    return "FAIL: workiq not found. Run: npm install -g @microsoft/workiq"
}

Test-Case "T07: Workspace directory" {
    if (Test-Path $WorkspacePath) { return "PASS: $WorkspacePath" }
    return "FAIL: $WorkspacePath not found. Re-run install."
}

Test-Case "T08: Persona file present" {
    $f = "$WorkspacePath\.github\copilot-instructions.md"
    if (Test-Path $f) { return "PASS: $((Get-Item $f).Length) bytes" }
    return "FAIL: $f not found"
}

Test-Case "T09: Persona has required sections" {
    $f = "$WorkspacePath\.github\copilot-instructions.md"
    $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return "FAIL: file empty or missing" }
    $required = @("First Session Protocol", "Hard Rules", "Skills", "WorkIQ", "Profile Management")
    $missing = $required | Where-Object { $content -notmatch $_ }
    if ($missing.Count -eq 0) { return "PASS: all $($required.Count) sections present" }
    return "FAIL: missing sections: $($missing -join ', ')"
}

Test-Case "T10: No em dashes in persona" {
    $f = "$WorkspacePath\.github\copilot-instructions.md"
    $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return "FAIL: file empty or missing" }
    $count = ([regex]::Matches($content, "[\u2014\u2013]")).Count
    if ($count -eq 0) { return "PASS" }
    return "FAIL: $count em dash(es) found - breaks PS5.1 if used in scripts"
}

Test-Case "T11: Desktop shortcut" {
    $s = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "AI Maker.lnk")
    if (Test-Path $s) { return "PASS: $s" }
    return "FAIL: shortcut not found at $s"
}

Test-Case "T12: Launch script syntax" {
    $f = "$script:ScriptDir\launch.ps1"
    if (-not (Test-Path $f)) { return "FAIL: launch.ps1 not found at $f" }
    $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$errs) | Out-Null
    if ($errs.Count -eq 0) { return "PASS" }
    return "FAIL: $($errs.Count) syntax error(s) in launch.ps1"
}

Test-Case "T13: Onboarding interview in workspace" {
    $f = "$WorkspacePath\onboarding-interview.md"
    if (Test-Path $f) { return "PASS" }
    return "FAIL: onboarding-interview.md missing from $WorkspacePath"
}

Test-Case "T14: Logs directory writable" {
    $logDir = "$WorkspacePath\logs"
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $testFile = "$logDir\.write-test"
    try {
        [System.IO.File]::WriteAllText($testFile, "test")
        Remove-Item $testFile -Force
        return "PASS"
    } catch {
        return "FAIL: cannot write to $logDir"
    }
}

# -----------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor White
Write-Host "  AI Maker Test Results: $passed passed, $failed failed" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White

foreach ($r in $results) {
    $color = if ($r.status -eq "PASS") { "Green" } else { "Red" }
    Write-Host "  [$($r.status)] $($r.name)" -ForegroundColor $color
    if ($r.status -eq "FAIL") { Write-Host "         $($r.detail)" -ForegroundColor DarkRed }
}

if ($failed -eq 0) {
    Write-Host "`n  ALL TESTS PASSED. AI Maker is ready." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n  $failed test(s) failed. Fix the issues above, then re-run:" -ForegroundColor Red
    Write-Host "  irm https://raw.githubusercontent.com/marcusash/ai-maker/main/bootstrap.ps1 | iex" -ForegroundColor Yellow
    exit 1
}