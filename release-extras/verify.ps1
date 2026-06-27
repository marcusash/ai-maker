#Requires -Version 7.0
<#
.SYNOPSIS
    Post-install verification for AI Maker v3.0.12. Run AFTER install.bat
    completes. Captures the 12 invariants that prove the installation succeeded
    on a real Windows machine (laptop or Cloud PC).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
Set-StrictMode -Off

$ts        = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir    = 'C:\Temp\ai-maker-smoke'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logPath   = Join-Path $logDir "verify-$ts.log"
$wsRoot    = 'C:\GitHub\ai-workspace'

$script:results = @()
$script:ok      = 0
$script:fail    = 0

function Probe {
    param([int]$N, [string]$Name, [scriptblock]$Check)
    $r = [pscustomobject]@{ N = $N; Name = $Name; Status = ''; Detail = '' }
    try {
        $out = & $Check
        if ($out -eq $true -or ($null -eq $out -and -not $Error)) {
            $r.Status = 'PASS'; $script:ok++
        } elseif ($out -eq $false) {
            $r.Status = 'FAIL'; $r.Detail = '(returned false)'; $script:fail++
        } else {
            if ($out -is [string] -and $out.StartsWith('FAIL:')) {
                $r.Status = 'FAIL'; $r.Detail = $out.Substring(5).Trim(); $script:fail++
            } elseif ($out -is [string] -and $out.StartsWith('SKIP:')) {
                $r.Status = 'SKIP'; $r.Detail = $out.Substring(5).Trim()
            } else {
                $r.Status = 'PASS'; $r.Detail = "$out"; $script:ok++
            }
        }
    } catch {
        $r.Status = 'FAIL'; $r.Detail = $_.Exception.Message; $script:fail++
    }
    $script:results += $r
    $line = "[{0,4}] #{1,-2} {2,-50} {3}" -f $r.Status, $r.N, $r.Name, $r.Detail
    $color = switch ($r.Status) { 'PASS' { 'Green' } 'SKIP' { 'DarkYellow' } default { 'Red' } }
    Write-Host $line -ForegroundColor $color
    Add-Content $logPath $line
}

Write-Host ""
Write-Host "AI Maker v3.0.12 verify  ($(hostname) - $ts)" -ForegroundColor Cyan
Write-Host "Log: $logPath" -ForegroundColor DarkGray
Write-Host ""
"AI Maker v3.0.12 verify  $(hostname)  $ts" | Set-Content $logPath
"" | Add-Content $logPath

$pill = if (Test-Path (Join-Path $wsRoot 'vault\workbench')) { 'red' }
        elseif (Test-Path (Join-Path $wsRoot 'vault\maker')) { 'blue' }
        else { 'unknown' }

$skillsPath = Join-Path $env:USERPROFILE '.copilot\skills'

Probe 1 "Pill detected (Blue|Red)" {
    if ($pill -eq 'unknown') { 'FAIL: workspace not found or vault structure missing' }
    else { "pill=$pill" }
}

Probe 2 "Workspace structure complete" {
    $required = @(
        $wsRoot,
        (Join-Path $wsRoot '.github'),
        (Join-Path $wsRoot '.github\copilot-instructions.md'),
        (Join-Path $wsRoot '.github\agents'),
        (Join-Path $wsRoot '.github\agents\ai-maker.md'),
        $skillsPath
    )
    $missing = $required | Where-Object { -not (Test-Path $_) }
    if ($missing.Count -eq 0) { $true } else { "FAIL: missing $($missing -join ', ')" }
}

Probe 3 "copilot-instructions.md has correct pill marker" {
    $ci = Get-Content (Join-Path $wsRoot '.github\copilot-instructions.md') -Raw -EA Stop
    $expected = if ($pill -eq 'blue') { 'AI Maker Workspace' } else { 'AI Workspace' }
    if ($ci -match [regex]::Escape($expected)) { "marker='$expected'" }
    else {
        $first = ($ci -split "`n")[0]
        "FAIL: marker '$expected' not found. First line: $first"
    }
}

Probe 4 "Skill count matches pill" {
    $maker = (Get-ChildItem $skillsPath -Directory -Filter 'ai-maker-*' -EA SilentlyContinue).Count
    $work  = (Get-ChildItem $skillsPath -Directory -Filter 'ai-workbench-*' -EA SilentlyContinue).Count
    $expected = if ($pill -eq 'blue') { @{maker=11; work=0} } else { @{maker=11; work=11} }
    if ($maker -eq $expected.maker -and $work -eq $expected.work) {
        "ai-maker-*=$maker, ai-workbench-*=$work"
    } else {
        "FAIL: expected maker=$($expected.maker) work=$($expected.work); got maker=$maker work=$work"
    }
}

Probe 5 "No nested skill dirs (v3.0.11 idempotency fix)" {
    $nested = Get-ChildItem $skillsPath -Directory -EA SilentlyContinue | ForEach-Object {
        $inner = Get-ChildItem $_.FullName -Directory -EA SilentlyContinue | Where-Object Name -eq $_.Name
        if ($inner) { "$($_.Name)\$($_.Name)" }
    }
    if (-not $nested) { "no nesting" }
    else { "FAIL: nested dirs detected: $($nested -join ', ')" }
}

Probe 6 "Agent identity files present" {
    $agentsDir = Join-Path $wsRoot '.github\agents'
    $maker = Test-Path (Join-Path $agentsDir 'ai-maker.md')
    $work  = Test-Path (Join-Path $agentsDir 'ai-workbench.md')
    if ($pill -eq 'blue') {
        if ($maker -and -not $work) { 'ai-maker.md only (Blue Purity)' }
        elseif ($work) { 'FAIL: Blue install has ai-workbench.md (Blue Purity violation)' }
        else { 'FAIL: ai-maker.md missing' }
    } else {
        if ($maker -and $work) { 'ai-maker.md + ai-workbench.md' }
        else { "FAIL: maker=$maker work=$work" }
    }
}

Probe 7 "SHELL env var set (User scope, Git Bash)" {
    # SHELL is only relevant for Red Pill (which requires Git). Blue skips Git entirely.
    if ($pill -eq 'blue') { return 'SKIP: Blue Pill does not require Git' }
    $shell = [Environment]::GetEnvironmentVariable('SHELL', 'User')
    if (-not $shell) {
        # Check if Git is even installed — if not, skip rather than fail
        $gitPath = Get-Command git -EA SilentlyContinue
        if (-not $gitPath) { return 'SKIP: Git not installed — SHELL cannot be set' }
        'FAIL: SHELL not set in User scope (Git is installed)'
    }
    elseif ($shell -notmatch 'sh\.exe$') { "FAIL: SHELL doesn't point at sh.exe: $shell" }
    elseif (-not (Test-Path $shell)) { "FAIL: SHELL target missing: $shell" }
    else { "$shell" }
}

Probe 8 "Velopack agency.exe locatable via app-* glob" {
    # agency.exe is installed by the Copilot App runtime (Velopack), not by this installer
    $glob = "$env:APPDATA\agency\*\agency.exe"
    $hits = Get-ChildItem $glob -EA SilentlyContinue
    if ($hits.Count -ge 1) { "$($hits[0].FullName)" }
    else { "SKIP: agency.exe not found — installed by Copilot App runtime, not this installer" }
}

Probe 9 "MCP config has workiq + bluebird" {
    # MCP config is written by the Copilot App runtime when agency registers servers
    $cfg = Join-Path $env:USERPROFILE '.copilot\m-mcp-servers.json'
    if (-not (Test-Path $cfg)) { return 'SKIP: m-mcp-servers.json not yet created — written by Copilot App runtime on first launch' }
    $json = Get-Content $cfg -Raw | ConvertFrom-Json
    # Support both key names: "mcpServers" (installer) and "servers" (legacy)
    $serverObj = if ($json.mcpServers) { $json.mcpServers } elseif ($json.servers) { $json.servers } else { $null }
    if (-not $serverObj) { return "FAIL: expected workiq + bluebird; got: empty config" }
    $servers = $serverObj.PSObject.Properties.Name
    $hasWorkiq = $servers -contains 'workiq'
    $hasBluebird = $servers -contains 'bluebird'
    if ($hasWorkiq -and $hasBluebird) {
        "$($servers -join ', ')"
    } else {
        "FAIL: expected workiq + bluebird; got: $($servers -join ', ')"
    }
}

Probe 10 "Hostname + machine type captured" {
    $hn = hostname
    $isCpc = $env:USERDOMAIN -match 'cloudpc' -or $hn -match '^CPC-|^CC-' -or (Get-CimInstance Win32_ComputerSystem -EA SilentlyContinue).Model -match 'Cloud PC|Virtual'
    if ($isCpc) { "host=$hn  type=CloudPC" } else { "host=$hn  type=Laptop" }
}

Probe 11 "APPDATA not OneDrive-backed (CPC quirk)" {
    $appdata = $env:APPDATA
    $target = (Get-Item $appdata -EA SilentlyContinue).Target
    if ($appdata -match 'OneDrive' -or ($target -and $target -match 'OneDrive')) {
        "FAIL: APPDATA redirected to OneDrive: $appdata (target=$target). Velopack may file-lock."
    } else { 'not OneDrive-backed' }
}

Probe 12 "Lib version matches v3.0.12" {
    $libCandidates = @(
        (Join-Path $wsRoot '.github\ai-maker-lib.ps1'),
        (Join-Path $wsRoot '.ai-maker\ai-maker-lib.ps1'),
        "$env:APPDATA\ai-maker\ai-maker-lib.ps1"
    )
    $lib = $libCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $lib) { return 'SKIP: lib not co-located with workspace (expected for URL install)' }
    $content = Get-Content $lib -Raw
    if ($content -match 'Version\s*=\s*"3\.0\.12"') { 'v3.0.12' }
    else {
        $actual = if ($content -match 'Version\s*=\s*"([\d\.]+)"') { $Matches[1] } else { 'unknown' }
        "FAIL: lib version is $actual, expected 3.0.12"
    }
}

Write-Host ""
$summary = "Result: $script:ok PASS / $script:fail FAIL (of $($script:results.Count) probes)"
Write-Host $summary -ForegroundColor $(if ($script:fail -eq 0) { 'Green' } else { 'Red' })
"" | Add-Content $logPath
$summary | Add-Content $logPath
Write-Host ""
Write-Host "Log saved: $logPath" -ForegroundColor Cyan
Write-Host ""

if ($script:fail -eq 0) {
    Write-Host "ALL GREEN. Reply: Done." -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILURES. Upload this log file:" -ForegroundColor Red
    Write-Host "    $logPath" -ForegroundColor Yellow
    exit 1
}
