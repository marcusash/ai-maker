# AI Maker Post-Install Verification Tests
# Runs after install.ps1. Can also be run standalone to verify health.
# Usage: test.ps1 [-WorkspacePath C:\AIMaker]
# Exit code: 0 = all passed, 1 = one or more failed.

param(
    [string]$WorkspacePath = "C:\AIMaker"
)

$ErrorActionPreference = "Continue"
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$passed  = 0
$failed  = 0
$results = [System.Collections.Generic.List[hashtable]]::new()

function Test-Case {
    param([string]$Name, [scriptblock]$Test)
    try {
        $result = & $Test
        if ($result -eq $true -or ($result -is [string] -and $result -match "PASS")) {
            $script:passed++
            $results.Add(@{ name = $Name; status = "PASS"; detail = "$result" })
        } else {
            $script:failed++
            $results.Add(@{ name = $Name; status = "FAIL"; detail = "$result" })
        }
    } catch {
        $script:failed++
        $results.Add(@{ name = $Name; status = "FAIL"; detail = $_.Exception.Message })
    }
}

Write-Host "`n[AI Maker Tests] Running post-install verification..." -ForegroundColor Cyan

# T01: Node.js is installed and on PATH
Test-Case "T01: Node.js available" {
    $v = node --version 2>&1
    if ($LASTEXITCODE -eq 0 -and $v -match "v\d+") { return "PASS: $v" }
    return "FAIL: node not found"
}

# T02: Git is installed and on PATH
Test-Case "T02: Git available" {
    $v = git --version 2>&1
    if ($LASTEXITCODE -eq 0) { return "PASS: $v" }
    return "FAIL: git not found"
}

# T03: GitHub CLI is installed and on PATH
Test-Case "T03: gh CLI available" {
    $v = (gh --version 2>&1 | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0) { return "PASS: $v" }
    return "FAIL: gh not found"
}

# T04: GitHub auth is active
Test-Case "T04: GitHub auth active" {
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { return "PASS" }
    return "FAIL: not authenticated to GitHub. Run: gh auth login"
}

# T05: Copilot CLI available (built-in in gh 2.x+ or as extension)
Test-Case "T05: Copilot CLI extension" {
    $help = gh copilot --help 2>&1
    if ($LASTEXITCODE -eq 0 -or ($help -match "copilot")) { return "PASS" }
    return "FAIL: gh copilot not available. Run: gh extension install github/gh-copilot"
}

# T06: WorkIQ npm package installed
Test-Case "T06: WorkIQ npm package" {
    $check = npm list -g @microsoft/workiq 2>&1
    if ($check -match "workiq") { return "PASS" }
    # Check if MCP config exists as fallback
    $mcpPath = "$env:APPDATA\GitHub Copilot\mcp.json"
    if (Test-Path $mcpPath) {
        $mcp = Get-Content $mcpPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($mcp.mcpServers.workiq) { return "PASS (MCP config)" }
    }
    return "FAIL: workiq not found. Run: npm install -g @microsoft/workiq"
}

# T07: Workspace directory exists
Test-Case "T07: Workspace directory" {
    if (Test-Path $WorkspacePath) { return "PASS: $WorkspacePath" }
    return "FAIL: $WorkspacePath not found"
}

# T08: copilot-instructions.md (persona) exists
Test-Case "T08: Persona file present" {
    $f = "$WorkspacePath\.github\copilot-instructions.md"
    if (Test-Path $f) {
        $size = (Get-Item $f).Length
        return "PASS: $f ($size bytes)"
    }
    return "FAIL: $f not found"
}

# T09: copilot-instructions.md has required sections
Test-Case "T09: Persona has required sections" {
    $f = "$WorkspacePath\.github\copilot-instructions.md"
    $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
    $required = @("First Session Protocol", "Hard Rules", "Skills", "WorkIQ", "Profile Management")
    $missing = $required | Where-Object { $content -notmatch $_ }
    if ($missing.Count -eq 0) { return "PASS: all $($required.Count) required sections present" }
    return "FAIL: missing sections: $($missing -join ', ')"
}

# T10: No em dashes in persona file
Test-Case "T10: No em dashes in persona" {
    $f = "$WorkspacePath\.github\copilot-instructions.md"
    $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return "FAIL: copilot-instructions.md not found or empty" }
    $emDashes = ([regex]::Matches($content, "[\u2014\u2013]")).Count
    if ($emDashes -eq 0) { return "PASS" }
    return "FAIL: $emDashes em dash(es) found in copilot-instructions.md"
}

# T11: Desktop shortcut exists
Test-Case "T11: Desktop shortcut" {
    $s = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "AI Maker.lnk")
    if (Test-Path $s) { return "PASS: $s" }
    return "FAIL: shortcut not found at $s"
}

# T12: Launch script exists and is valid PowerShell syntax
Test-Case "T12: Launch script syntax" {
    $f = "$script:ScriptDir\launch.ps1"
    if (-not (Test-Path $f)) { return "FAIL: launch.ps1 not found" }
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$errors) | Out-Null
    if ($errors.Count -eq 0) { return "PASS" }
    return "FAIL: $($errors.Count) syntax error(s) in launch.ps1"
}

# T13: gh copilot command responds
Test-Case "T13: Copilot CLI responds" {
    $help = gh copilot --help 2>&1 | Select-Object -First 1
    if ($LASTEXITCODE -eq 0 -or $help -match "copilot") { return "PASS" }
    return "FAIL: gh copilot --help failed"
}

# T14: Onboarding interview file in workspace
Test-Case "T14: Onboarding interview in workspace" {
    $f = "$WorkspacePath\onboarding-interview.md"
    if (Test-Path $f) { return "PASS" }
    return "FAIL: onboarding-interview.md not in workspace"
}

# T15: Logs directory writable
Test-Case "T15: Logs directory writable" {
    $logDir = "$WorkspacePath\logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
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
    if ($r.status -eq "FAIL") {
        Write-Host "         $($r.detail)" -ForegroundColor DarkRed
    }
}

if ($failed -eq 0) {
    Write-Host "`n  ALL TESTS PASSED. AI Maker is ready." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n  $failed test(s) failed. Fix the issues above and re-run install.ps1." -ForegroundColor Red
    exit 1
}
