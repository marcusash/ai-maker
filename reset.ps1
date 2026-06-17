<#
.SYNOPSIS
    AI Maker v3 — Reset (wipe previous install for clean re-test)
.DESCRIPTION
    Removes all AI Maker artifacts so you can test from scratch.
    Does NOT uninstall the Copilot App or PowerShell 7.
#>

Write-Host ""
Write-Host "  AI Maker v3 — Reset" -ForegroundColor Yellow
Write-Host "  ====================" -ForegroundColor Yellow
Write-Host ""

$items = @(
    @{ Path = (Join-Path $env:USERPROFILE ".copilot\skills\ai-maker-*"); Desc = "AI Maker skills" }
    @{ Path = (Join-Path $env:USERPROFILE ".copilot\skills\ai-workbench-*"); Desc = "AI Workbench skills" }
    @{ Path = ("C:\GitHub\ai-workspace"); Desc = "Workspace folder" }
    @{ Path = (Join-Path $env:USERPROFILE ".copilot\ai-maker"); Desc = "Transaction log" }
)

foreach ($item in $items) {
    $targets = Get-Item $item.Path -ErrorAction SilentlyContinue
    if ($targets) {
        foreach ($t in $targets) {
            Remove-Item $t.FullName -Recurse -Force
            Write-Host "  Removed: $($t.FullName)" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  (not found) $($item.Desc)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "  Done. Run .\run.ps1 for a clean install." -ForegroundColor Green
Write-Host ""

