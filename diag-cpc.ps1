# Agency CPC diagnostic
# Run on Cloud PC. Captures: env state, MSAL cache, current MCP config,
# tries the all-12-servers config, launches App, dumps logs, then reverts.

$ErrorActionPreference = 'Continue'
$out = "$env:TEMP\agency-cpc-diag-$(Get-Date -f yyyyMMdd-HHmmss).txt"
function W { param($s) $s | Tee-Object -FilePath $out -Append; "" | Tee-Object -FilePath $out -Append }
function H { W ("=" * 70); W $args[0]; W ("=" * 70) }

H "1. ENVIRONMENT"
W "Date: $(Get-Date)"
W "Host: $env:COMPUTERNAME"
W "User: $env:USERNAME"
W "OS: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)"
W "Cloud PC?: $(if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows365') {'YES'} else {'no/unknown'})"

H "2. MSAL CACHE STATE (top hypothesis)"
$msalDir = "$env:LOCALAPPDATA\.IdentityService"
if (Test-Path $msalDir) {
    W "Found: $msalDir"
    Get-ChildItem $msalDir -Force -EA Silent | Select Name,Length,LastWriteTime | Format-Table -A | Out-String | ForEach-Object { W $_ }
} else { W "MISSING: $msalDir  (this is the smoking gun if write tools fail)" }

$webAccountDir = "$env:LOCALAPPDATA\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy"
W "WAM broker plugin: $(if (Test-Path $webAccountDir) {'present'} else {'MISSING'})"

H "3. AGENCY VERSION + CONFIG"
$agency = (Get-Command agency -EA Silent).Source
W "agency.exe: $agency"
if ($agency) { agency --version 2>&1 | Out-String | ForEach-Object { W $_ } }
$mcpCfg = "$env:USERPROFILE\.copilot\m-mcp-servers.json"
W "MCP config: $mcpCfg"
if (Test-Path $mcpCfg) {
    $cfg = Get-Content $mcpCfg -Raw
    W "--- current config ---"
    W $cfg
    $servers = ($cfg | ConvertFrom-Json).servers
    W "Server count: $($servers.PSObject.Properties.Count)"
}

H "4. EXISTING AGENCY LOGS (last 3 sessions)"
$logRoot = "$env:LOCALAPPDATA\agency\logs"
if (Test-Path $logRoot) {
    $sessions = Get-ChildItem $logRoot -Directory | Sort LastWriteTime -Desc | Select -First 3
    foreach ($s in $sessions) {
        W "--- session: $($s.Name) ($($s.LastWriteTime)) ---"
        $procLogs = Get-ChildItem $s.FullName -Filter 'process-*.log' -EA Silent
        foreach ($p in $procLogs) {
            W ">>> $($p.Name) (last 30 lines):"
            Get-Content $p.FullName -Tail 30 -EA Silent | ForEach-Object { W "    $_" }
        }
    }
} else { W "No agency log root found at $logRoot" }

H "5. TOKEN BROKER STATE"
$tbDir = "$env:LOCALAPPDATA\Microsoft\TokenBroker"
W "TokenBroker cache: $(if (Test-Path $tbDir) {'present'} else {'MISSING'})"
if (Test-Path $tbDir) { Get-ChildItem $tbDir -Recurse -EA Silent | Measure-Object | ForEach-Object { W "  files: $($_.Count)" } }

H "6. NETWORK REACHABILITY (Graph + login)"
foreach ($u in @('https://graph.microsoft.com/v1.0/$metadata','https://login.microsoftonline.com/common/oauth2/v2.0/authorize')) {
    try {
        $r = Invoke-WebRequest $u -Method Head -UseBasicParsing -TimeoutSec 5 -EA Stop
        W "$u -> $($r.StatusCode)"
    } catch { W "$u -> FAIL: $($_.Exception.Message)" }
}

H "7. CONDITIONAL ACCESS HINT"
$dsregOut = & dsregcmd /status 2>&1 | Out-String
$dsregOut -split "`r?`n" | Where-Object { $_ -match 'AzureAdJoined|EnterpriseJoined|DomainJoined|TenantName|TenantId|WamDefaultSet|AzureAdPrt|AzureAdPrtUpdateTime|AzureAdPrtExpiryTime' } | ForEach-Object { W $_ }

H "8. SUMMARY"
W "Diagnostic file: $out"
W ""
W "NEXT: open the file, paste back to FP. If section 2 says MSAL MISSING,"
W "the cheapest test is: open https://outlook.office.com in Edge, sign in,"
W "then retry agency gh-app. That seeds the broker."

Write-Host ""
Write-Host "DONE. File: $out" -ForegroundColor Cyan
Write-Host "Run: notepad `"$out`"  to view, then paste contents back to FP." -ForegroundColor Yellow
