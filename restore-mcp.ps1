$cfg = "$env:USERPROFILE\.copilot\m-mcp-servers.json"
$agency = "$env:APPDATA\agency\CurrentVersion\agency.exe"

Write-Host "Backing up current config..." -ForegroundColor Yellow
$bak = "$cfg.bak.$(Get-Date -f yyyyMMddHHmmss)"
Copy-Item $cfg $bak -EA Silent
Write-Host "  saved: $bak" -ForegroundColor Gray

Write-Host "Writing canonical clean config (workiq + bluebird only)..." -ForegroundColor Yellow

$canonical = @{
    mcpServers = @{
        workiq = @{
            command = $agency
            args    = @('mcp','workiq')
        }
        bluebird = @{
            command = $agency
            args    = @('mcp','bluebird')
        }
    }
} | ConvertTo-Json -Depth 10

[System.IO.File]::WriteAllText($cfg, $canonical, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Wrote: $cfg" -ForegroundColor Green
Get-Content $cfg | Write-Host -ForegroundColor Gray

Write-Host "`nHard-restarting Copilot App + Agency..." -ForegroundColor Yellow
Get-Process | ?{ $_.Name -match "Copilot|github-copilot|agency" } | Stop-Process -Force -EA SilentlyContinue
Start-Sleep 3
Start-Process $agency -ArgumentList 'gh-app'
Write-Host "Done. App should relaunch in a few seconds." -ForegroundColor Green
Write-Host "`nNow open the App and run:" -ForegroundColor Cyan
Write-Host "  /tools  (or ask the agent: 'list every MCP tool you can see')" -ForegroundColor Cyan
Write-Host "Paste the tool list back to FP." -ForegroundColor Cyan
