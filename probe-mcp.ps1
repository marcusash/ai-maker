# probe-mcp.ps1 — Try starting Agency M365 MCP servers directly to capture real errors

$ErrorActionPreference = 'Continue'
$agency = "$env:APPDATA\agency\CurrentVersion\agency.exe"
if (-not (Test-Path $agency)) { Write-Host "agency.exe missing at $agency" -F Red; return }

function Probe-Server($name) {
    Write-Host "`n=== Probing: agency mcp $name ===" -F Cyan
    $out  = [System.IO.Path]::GetTempFileName()
    $err  = [System.IO.Path]::GetTempFileName()
    $p = Start-Process -FilePath $agency -ArgumentList @('mcp', $name, '--transport', 'http', '--port', '0') `
            -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -WindowStyle Hidden -EA SilentlyContinue
    if (-not $p) { Write-Host "FAILED to start process" -F Red; return }
    Start-Sleep 6
    $running = -not $p.HasExited
    if ($running) {
        Write-Host "STATUS: server started OK (PID $($p.Id), still running)" -F Green
        Stop-Process -Id $p.Id -Force -EA SilentlyContinue
    } else {
        Write-Host "STATUS: server EXITED (code $($p.ExitCode))" -F Yellow
    }
    Write-Host "--- stdout ---" -F Gray
    Get-Content $out -EA SilentlyContinue | Select -First 30
    Write-Host "--- stderr ---" -F Gray
    Get-Content $err -EA SilentlyContinue | Select -First 30
    Remove-Item $out, $err -EA SilentlyContinue
}

Write-Host "Agency: $agency" -F Gray
& $agency --version

# Probe each server individually so we can see which fail
foreach ($n in @('workiq','calendar','mail','teams','planner','m365-copilot','graph','bluebird')) {
    Probe-Server $n
}

Write-Host "`n=== Latest Agency log ===" -F Cyan
$logRoot = "$env:USERPROFILE\.agency\logs"
if (Test-Path $logRoot) {
    $latest = Get-ChildItem $logRoot -Directory | Sort LastWriteTime -Desc | Select -First 1
    if ($latest) {
        Write-Host "Log dir: $($latest.FullName)" -F Gray
        Get-ChildItem $latest.FullName -File | Sort LastWriteTime -Desc | Select -First 3 | ForEach-Object {
            Write-Host "`n--- $($_.Name) (last 30 lines) ---" -F Gray
            Get-Content $_.FullName -Tail 30 -EA SilentlyContinue
        }
    }
} else {
    Write-Host "No log dir at $logRoot" -F Yellow
}

Write-Host "`n=== EntraID / MSAL cache state ===" -F Cyan
$msal = "$env:LOCALAPPDATA\.IdentityService\msalcache.bin"
if (Test-Path $msal) {
    $sz = (Get-Item $msal).Length
    Write-Host "msalcache.bin: $sz bytes (presence = some auth has happened)" -F Green
} else {
    Write-Host "NO msalcache.bin — may indicate no Entra auth has occurred" -F Yellow
}

Write-Host "`n=== Done. Send screenshot of any RED/YELLOW status above. ===" -F Green
