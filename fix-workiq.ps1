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

Write-Section "3. Register full M365 MCP server set"
Write-Host "Adding: mail, teams, planner, calendar, sharepoint, onedrive, m365-copilot, m365-user, word, graph" -ForegroundColor Gray

$obj = if (Test-Path $cfg) { Get-Content $cfg -Raw | ConvertFrom-Json } else { [pscustomobject]@{ servers = @{} } }
if (-not $obj.servers) { $obj | Add-Member -NotePropertyName servers -NotePropertyValue ([pscustomobject]@{}) -Force }

$serverSet = @(
    'workiq','bluebird',
    'mail','teams','planner','calendar',
    'sharepoint','onedrive','m365-copilot','m365-user',
    'word','graph'
)
foreach ($name in $serverSet) {
    $entry = [pscustomobject]@{
        command = $agency
        args    = @('mcp', $name)
        tools   = @('*')
    }
    if ($obj.servers.PSObject.Properties.Name -contains $name) {
        $obj.servers.$name = $entry
    } else {
        $obj.servers | Add-Member -NotePropertyName $name -NotePropertyValue $entry -Force
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path $cfg) | Out-Null
$json = $obj | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($cfg, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "`nUpdated config:" -ForegroundColor Green
Get-Content $cfg -Raw

Write-Section "4. Auth note"
Write-Host "EntraID token injection happens automatically on first MCP call." -ForegroundColor Yellow
Write-Host "When you ask AI maker to read mail/calendar, a browser sign-in pops the first time." -ForegroundColor Yellow
Write-Host "No CLI login needed." -ForegroundColor Yellow

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
