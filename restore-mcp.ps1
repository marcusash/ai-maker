$cfg = "$env:USERPROFILE\.copilot\m-mcp-servers.json"
$agency = "$env:APPDATA\agency\CurrentVersion\agency.exe"

Write-Host "Reverting MCP config to workiq + bluebird only..." -ForegroundColor Yellow

$obj = Get-Content $cfg -Raw | ConvertFrom-Json
$keep = @('filesystem','playwright','workiq','bluebird')
$new = [pscustomobject]@{}
foreach ($p in $obj.servers.PSObject.Properties) {
    if ($keep -contains $p.Name) {
        $new | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
    }
}
$obj.servers = $new

$json = $obj | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($cfg, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Done. Hard-restarting Copilot App..." -ForegroundColor Green
Get-Process | ?{ $_.Name -match "Copilot|github-copilot|agency" } | Stop-Process -Force -EA SilentlyContinue
Start-Sleep 5
Start-Process $agency -ArgumentList 'gh-app'
Write-Host "App relaunched. workiq read-path should be back." -ForegroundColor Green
