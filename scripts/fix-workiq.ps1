# fix-workiq.ps1 — Diagnose and repair WorkIQ / M365 MCP wiring on the Copilot App
# Run from regular pwsh on the Cloud PC (NOT inside the Copilot App).

$ErrorActionPreference = 'Continue'
$cfg = "$env:USERPROFILE\.copilot\m-mcp-servers.json"

function Write-Section($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }

Write-Section "1. Current MCP config"
if (Test-Path $cfg) {
    Write-Host "Path: $cfg" -ForegroundColor Gray
    Get-Content $cfg -Raw
} else {
    Write-Host "NO MCP CONFIG at $cfg — will re-create below." -ForegroundColor Yellow
}

Write-Section "2. Agency CLI"
function Resolve-Agency {
    $candidates = @(
        (Get-Command agency.exe -EA SilentlyContinue).Source,
        "$env:APPDATA\agency\CurrentVersion\agency.exe",
        "$env:LOCALAPPDATA\Microsoft\agency\agency.exe",
        "$env:LOCALAPPDATA\agency\CurrentVersion\agency.exe"
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}
$agency = Resolve-Agency
if (-not $agency) {
    Write-Host "agency.exe NOT FOUND. Installing via aka.ms/PathInstaller..." -ForegroundColor Yellow
    iex "& { $(irm https://aka.ms/InstallTool.ps1) } agency"
    $agency = Resolve-Agency
}
if (-not $agency) {
    Write-Host "FATAL: agency still not found after install. Aborting." -ForegroundColor Red
    return
}
Write-Host "agency: $agency" -ForegroundColor Green
& $agency --version

Write-Section "3. Re-register workiq + bluebird MCP servers"
$lib = "$env:USERPROFILE\.ai-maker\ai-maker-lib.ps1"
if (-not (Test-Path $lib)) {
    # Try common alternate location
    $alt = "$env:LOCALAPPDATA\ai-maker\ai-maker-lib.ps1"
    if (Test-Path $alt) { $lib = $alt }
}
if (Test-Path $lib) {
    . $lib
    Register-AgencyMcpServers
    Write-Host "`nUpdated config:" -ForegroundColor Green
    Get-Content $cfg -Raw
} else {
    Write-Host "ai-maker-lib.ps1 not found — falling back to manual config write" -ForegroundColor Yellow
    $obj = if (Test-Path $cfg) { Get-Content $cfg -Raw | ConvertFrom-Json } else { [pscustomobject]@{ mcpServers = @{} } }
    if (-not $obj.mcpServers) { $obj | Add-Member -NotePropertyName mcpServers -NotePropertyValue @{} -Force }
    $obj.mcpServers | Add-Member -NotePropertyName workiq  -NotePropertyValue @{ command = $agency; args = @('mcp','workiq')  } -Force
    $obj.mcpServers | Add-Member -NotePropertyName bluebird -NotePropertyValue @{ command = $agency; args = @('mcp','bluebird') } -Force
    New-Item -ItemType Directory -Force -Path (Split-Path $cfg) | Out-Null
    $obj | ConvertTo-Json -Depth 10 | Set-Content -Path $cfg -Encoding utf8
    Get-Content $cfg -Raw
}

Write-Section "4. Sign in to workiq (M365 / Entra)"
Write-Host "Discovering Agency auth surface..." -ForegroundColor Yellow
Write-Host "`n--- agency --help ---" -ForegroundColor Gray
& $agency --help 2>&1
Write-Host "`n--- agency auth --help ---" -ForegroundColor Gray
& $agency auth --help 2>&1
Write-Host "`n--- agency login --help ---" -ForegroundColor Gray
& $agency login --help 2>&1
Write-Host "`n--- agency mcp --help ---" -ForegroundColor Gray
& $agency mcp --help 2>&1
Write-Host "`n--- agency mcp workiq --help ---" -ForegroundColor Gray
& $agency mcp workiq --help 2>&1
Write-Host "`nScreenshot the above and send to FP — we need to find the correct auth subcommand." -ForegroundColor Yellow

Write-Section "5. Restart Copilot App"
Get-Process "GitHub Copilot*" -EA SilentlyContinue | ForEach-Object {
    Write-Host "Stopping PID $($_.Id) — $($_.ProcessName)" -ForegroundColor Gray
    Stop-Process -Id $_.Id -Force
}
Start-Sleep 3
Write-Host "Relaunching via agency gh-app..." -ForegroundColor Gray
Start-Process -FilePath $agency -ArgumentList 'gh-app'

Write-Section "Done"
Write-Host "When the app reopens, in AI maker ask:" -ForegroundColor Green
Write-Host "  'List my next 5 meetings'" -ForegroundColor White
Write-Host "If it still says no M365 access, paste the output above (steps 1-3) back to FP." -ForegroundColor Gray
