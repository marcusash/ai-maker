<#
.SYNOPSIS
    Stop all running agent sessions (agency copilot processes).
.DESCRIPTION
    Terminates any running agency copilot processes.
    Safe to run at end of day or when switching tasks.
#>

$agencyProcs = Get-Process -Name "agency" -ErrorAction SilentlyContinue
$nodeProcs   = Get-WmiObject Win32_Process -Filter "CommandLine LIKE '%agency copilot%'" -ErrorAction SilentlyContinue

if (-not $agencyProcs -and -not $nodeProcs) {
    Write-Host "  No active agency sessions found." -ForegroundColor Gray
    exit 0
}

Write-Host "  Stopping agent sessions..." -ForegroundColor Yellow

foreach ($p in $agencyProcs) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Write-Host "  Stopped: agency (PID $($p.Id))" -ForegroundColor Green
}

foreach ($p in $nodeProcs) {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Host "  Stopped: node/agency (PID $($p.ProcessId))" -ForegroundColor Green
}

Write-Host "  All agent sessions stopped." -ForegroundColor Green
