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
$agency = (Get-Command agency.exe -EA SilentlyContinue).Source
if (-not $agency) {
    $fb = "$env:LOCALAPPDATA\Microsoft\agency\agency.exe"
    if (Test-Path $fb) { $agency = $fb }
}
if (-not $agency) {
    Write-Host "agency.exe NOT FOUND. Re-installing..." -ForegroundColor Yellow
    iex "& { $(irm https://aka.ms/InstallTool.ps1) } agency"
    $agency = (Get-Command agency.exe -EA SilentlyContinue).Source
}
Write-Host "agency: $agency"
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
Write-Host "A browser window will open for Microsoft sign-in. Use your @microsoft.com account." -ForegroundColor Yellow
& $agency mcp workiq --login

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
