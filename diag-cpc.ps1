# Agency CPC diagnostic
# Run on Cloud PC. Captures: env state, MSAL cache, current MCP config,
# tries the all-12-servers config, launches App, dumps logs, then reverts.

$ErrorActionPreference = 'Continue'
$out = "$env:TEMP\agency-cpc-diag-$(Get-Date -f yyyyMMdd-HHmmss).txt"
function Write-Diag { param([string]$s) $s | Tee-Object -FilePath $out -Append; "" | Tee-Object -FilePath $out -Append }
function Write-Section { param([string]$title) Write-Diag ("=" * 70); Write-Diag $title; Write-Diag ("=" * 70) }

Write-Section "1. ENVIRONMENT"
Write-Diag "Date: $(Get-Date)"
Write-Diag "Host: $env:COMPUTERNAME"
Write-Diag "User: $env:USERNAME"
Write-Diag "OS: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)"
Write-Diag "Cloud PC?: $(if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows365') {'YES'} else {'no/unknown'})"

Write-Section "2. MSAL CACHE STATE (top hypothesis)"
$msalDir = "$env:LOCALAPPDATA\.IdentityService"
if (Test-Path $msalDir) {
    Write-Diag "Found: $msalDir"
    Get-ChildItem $msalDir -Force -EA Silent | Select Name,Length,LastWriteTime | Format-Table -A | Out-String | ForEach-Object { Write-Diag $_ }
} else { Write-Diag "MISSING: $msalDir  (this is the smoking gun if write tools fail)" }

$webAccountDir = "$env:LOCALAPPDATA\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy"
Write-Diag "WAM broker plugin: $(if (Test-Path $webAccountDir) {'present'} else {'MISSING'})"

Write-Section "3. AGENCY VERSION + CONFIG"
$agency = (Get-Command agency -EA Silent).Source
Write-Diag "agency.exe: $agency"
if ($agency) { agency --version 2>&1 | Out-String | ForEach-Object { Write-Diag $_ } }
$mcpCfg = "$env:USERPROFILE\.copilot\m-mcp-servers.json"
Write-Diag "MCP config path: $mcpCfg"
Write-Diag "MCP config exists: $(Test-Path $mcpCfg)"
if (Test-Path $mcpCfg) {
    $cfg = Get-Content $mcpCfg -Raw
    Write-Diag "--- current config ---"
    Write-Diag $cfg
    try {
        $servers = ($cfg | ConvertFrom-Json).servers
        Write-Diag "Server count: $($servers.PSObject.Properties.Count)"
    } catch { Write-Diag "JSON parse failed: $_" }
}

Write-Section "4. EXISTING AGENCY LOGS (last 3 sessions)"
$logRoot = "$env:LOCALAPPDATA\agency\logs"
if (Test-Path $logRoot) {
    $sessions = Get-ChildItem $logRoot -Directory | Sort LastWriteTime -Desc | Select -First 3
    foreach ($s in $sessions) {
        Write-Diag "--- session: $($s.Name) ($($s.LastWriteTime)) ---"
        $procLogs = Get-ChildItem $s.FullName -Filter 'process-*.log' -EA Silent
        foreach ($p in $procLogs) {
            Write-Diag ">>> $($p.Name) (last 30 lines):"
            Get-Content $p.FullName -Tail 30 -EA Silent | ForEach-Object { Write-Diag "    $_" }
        }
    }
} else { Write-Diag "No agency log root found at $logRoot" }

Write-Section "5. TOKEN BROKER STATE"
$tbDir = "$env:LOCALAPPDATA\Microsoft\TokenBroker"
Write-Diag "TokenBroker cache: $(if (Test-Path $tbDir) {'present'} else {'MISSING'})"
if (Test-Path $tbDir) { Get-ChildItem $tbDir -Recurse -EA Silent | Measure-Object | ForEach-Object { Write-Diag "  files: $($_.Count)" } }

Write-Section "6. NETWORK REACHABILITY (Graph + login)"
foreach ($u in @('https://graph.microsoft.com/v1.0/$metadata','https://login.microsoftonline.com/common/oauth2/v2.0/authorize')) {
    try {
        $r = Invoke-WebRequest $u -Method Head -UseBasicParsing -TimeoutSec 5 -EA Stop
        Write-Diag "$u -> $($r.StatusCode)"
    } catch { Write-Diag "$u -> FAIL: $($_.Exception.Message)" }
}

Write-Section "7. CONDITIONAL ACCESS HINT"
$dsregOut = & dsregcmd /status 2>&1 | Out-String
$dsregOut -split "`r?`n" | Where-Object { $_ -match 'AzureAdJoined|EnterpriseJoined|DomainJoined|TenantName|TenantId|WamDefaultSet|AzureAdPrt|AzureAdPrtUpdateTime|AzureAdPrtExpiryTime' } | ForEach-Object { Write-Diag $_ }

Write-Section "8. SUMMARY"
Write-Diag "Diagnostic file: $out"

Write-Host ""
Write-Host "DONE. File: $out" -ForegroundColor Cyan
Write-Host "Run: notepad `"$out`"  to view, then paste contents back to FP." -ForegroundColor Yellow
