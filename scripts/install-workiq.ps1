# WorkIQ Plugin Installer
# Called by install.ps1. Can also be run standalone.

$ErrorActionPreference = "Continue"

function Write-Step($msg) { Write-Host "`n[WorkIQ] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  FAIL: $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "  WARN: $msg" -ForegroundColor Yellow }

# -----------------------------------------------------------------------
# STEP 1: Install @microsoft/workiq npm package
# -----------------------------------------------------------------------
Write-Step "Installing @microsoft/workiq npm package"

$workiqCheck = npm list -g @microsoft/workiq 2>&1
if ($workiqCheck -match "workiq@") {
    $ver = (npm list -g @microsoft/workiq 2>&1 | Select-String "workiq@").ToString().Trim()
    Write-OK "Already installed: $ver"
} else {
    Write-Warn "Installing @microsoft/workiq..."
    npm install -g @microsoft/workiq 2>&1 | Select-Object -Last 3 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "npm install failed for @microsoft/workiq"
        exit 1
    }
    Write-OK "@microsoft/workiq installed"
}

# -----------------------------------------------------------------------
# STEP 2: Write MCP config so gh copilot picks up WorkIQ automatically
# -----------------------------------------------------------------------
Write-Step "Configuring WorkIQ as MCP server for GitHub Copilot"

$mcpDir  = "$env:APPDATA\GitHub Copilot"
$mcpPath = "$mcpDir\mcp.json"

if (-not (Test-Path $mcpDir)) { New-Item -ItemType Directory -Force -Path $mcpDir | Out-Null }

# Preserve any existing MCP entries, just add/overwrite the workiq entry
$existing = @{ mcpServers = @{} }
if (Test-Path $mcpPath) {
    try { $existing = Get-Content $mcpPath -Raw | ConvertFrom-Json -AsHashtable } catch {}
    if (-not $existing.mcpServers) { $existing.mcpServers = @{} }
}

$existing.mcpServers.workiq = @{
    command = "npx"
    args    = @("-y", "@microsoft/workiq", "mcp")
}

$existing | ConvertTo-Json -Depth 10 | Set-Content -Path $mcpPath -Encoding UTF8
Write-OK "MCP config: $mcpPath"

# -----------------------------------------------------------------------
# STEP 3: Confirm workiq CLI is on PATH
# -----------------------------------------------------------------------
Write-Step "Verifying WorkIQ CLI"

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
$wiq = Get-Command workiq -ErrorAction SilentlyContinue
if ($wiq) {
    Write-OK "workiq CLI available: $($wiq.Source)"
} else {
    Write-Warn "workiq not on PATH yet -- restart terminal after install."
}

Write-Host ""
Write-Host "  WorkIQ is ready." -ForegroundColor Green
Write-Host "  On first use, a browser will open for Microsoft login (one-time per machine)." -ForegroundColor Yellow
Write-Host "  After login, ask AI Maker: 'What are my meetings today?' to verify." -ForegroundColor Yellow
exit 0
