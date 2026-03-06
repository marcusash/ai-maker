# AI Maker: Setup Script
# Installs and configures GitHub CLI and WorkIQ for use with AI Maker.
# Run this after the initial software install if things weren't set up.
# Location: C:\Github\ai-maker\scripts\setup.ps1

$LogFile = "C:\AIMaker\logs\setup.log"
$ConfigFile = "$env:USERPROFILE\.copilot\config.json"

function Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    if ($Level -eq "ERROR") { Write-Host $line -ForegroundColor Red }
    elseif ($Level -eq "WARN") { Write-Host $line -ForegroundColor Yellow }
    else { Write-Host $line }
}

function Step {
    param([int]$Num, [string]$Title)
    Write-Host ""
    Write-Host "  Step ${Num}: $Title" -ForegroundColor Cyan
    param([string]$Message = "Press Enter to continue...")
    Write-Host ""
    Write-Host "  $Message" -ForegroundColor Yellow
    Read-Host
}

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

New-Item -ItemType Directory -Path "C:\AIMaker\logs" -Force | Out-Null
New-Item -ItemType Directory -Path "C:\AIMaker\scripts" -Force | Out-Null

Log "=== AI Maker Setup ==="
Write-Host ""
Write-Host "  AI Maker: Setup" -ForegroundColor Yellow
Write-Host "  =========================="
Write-Host ""
Write-Host "  This script sets up GitHub CLI and WorkIQ for AI Maker."
Write-Host "  You will be prompted to log in to GitHub and Microsoft 365."
Write-Host "  Keep a browser window accessible."
Write-Host ""

# ─────────────────────────────────────────────────────────────
# Step 1: Verify base prerequisites
# ─────────────────────────────────────────────────────────────
Step 1 "Verify base prerequisites"

$hard = @("node", "npm", "git")
$hardMissing = @()
foreach ($cmd in $hard) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "  [OK]  $cmd" -ForegroundColor Green
        Log "PREREQ OK: $cmd at $($found.Source)"
    } else {
        Write-Host "  [MISSING] $cmd not found on PATH" -ForegroundColor Red
        Log "PREREQ MISSING: $cmd" "ERROR"
        $hardMissing += $cmd
    }
}

if ($hardMissing.Count -gt 0) {
    Write-Host ""
    Write-Host "  Missing required tools: $($hardMissing -join ', ')" -ForegroundColor Red
    Write-Host "  Install them via winget or the main pc-setup installer, then re-run this script." -ForegroundColor Red
    Log "Aborting: missing hard prerequisites $($hardMissing -join ', ')" "ERROR"
    exit 1
}

# ─────────────────────────────────────────────────────────────
# Step 2: Install GitHub CLI
# ─────────────────────────────────────────────────────────────
Step 2 "Install GitHub CLI"

$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    $ghVer = gh --version 2>&1 | Select-Object -First 1
    Write-Host "  [OK]  GitHub CLI already installed: $ghVer" -ForegroundColor Green
    Log "gh already installed: $ghVer"
} else {
    Write-Host "  GitHub CLI not found. Installing via winget..."
    winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
    Refresh-Path
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
        Write-Host "  [OK]  GitHub CLI installed." -ForegroundColor Green
        Log "gh installed via winget."
    } else {
        Write-Host "  Install may need a terminal restart. Trying to continue..." -ForegroundColor Yellow
        Log "gh not on PATH after winget install — may need restart" "WARN"
    }
}

# ─────────────────────────────────────────────────────────────
# Step 3: GitHub CLI authentication
# ─────────────────────────────────────────────────────────────
Step 3 "GitHub CLI authentication"

$ghAuth = gh auth status 2>&1 | Out-String
if ($ghAuth -match "Logged in") {
    $account = "unknown"
    if ($ghAuth -match "account (\S+)") { $account = $Matches[1] }
    if ($account -ne "unknown") {
        Write-Host "  [OK]  Already logged in as $account" -ForegroundColor Green
        Log "gh already authenticated as $account"
    } else {
        Write-Host "  Logged in but account name not resolved. Re-authenticating..."
        gh auth login --web --git-protocol https
        Log "gh re-auth triggered (unknown account)"
    }
} else {
    Write-Host "  Not logged in. A browser window will open for GitHub login." -ForegroundColor Cyan
    Write-Host "  Follow the prompts in the browser, then return here." -ForegroundColor Gray
    gh auth login --web --git-protocol https
    $ghAuth = gh auth status 2>&1 | Out-String
    if ($ghAuth -match "Logged in") {
        $account = "unknown"
        if ($ghAuth -match "account (\S+)") { $account = $Matches[1] }
        Write-Host "  [OK]  Logged in as $account" -ForegroundColor Green
        Log "gh authenticated as $account"
    } else {
        Write-Host "  WARNING: GitHub auth status unclear after login." -ForegroundColor Yellow
        Log "gh auth status unclear after login" "WARN"
    }
}

# ─────────────────────────────────────────────────────────────
# Step 4: GitHub Copilot CLI extension
# ─────────────────────────────────────────────────────────────
Step 4 "GitHub Copilot CLI extension"

$ghExtensions = gh extension list 2>&1 | Out-String
if ($ghExtensions -match "copilot") {
    Write-Host "  [OK]  gh copilot extension already installed." -ForegroundColor Green
    Log "gh copilot extension already installed"
} else {
    Write-Host "  Installing gh copilot extension..."
    gh extension install github/gh-copilot 2>&1 | Out-Null
    $ghExtensions = gh extension list 2>&1 | Out-String
    if ($ghExtensions -match "copilot") {
        Write-Host "  [OK]  gh copilot extension installed." -ForegroundColor Green
        Log "gh copilot extension installed"
    } else {
        Write-Host "  WARNING: Extension install may have failed. Check above." -ForegroundColor Yellow
        Log "gh copilot extension install result unclear" "WARN"
    }
}

# ─────────────────────────────────────────────────────────────
# Step 5: Install WorkIQ
# ─────────────────────────────────────────────────────────────
Step 5 "Install WorkIQ"

$wiq = Get-Command workiq -ErrorAction SilentlyContinue
if ($wiq) {
    $wiqVer = workiq version 2>&1 | Select-Object -First 1
    Write-Host "  [OK]  WorkIQ already installed: $wiqVer" -ForegroundColor Green
    Log "WorkIQ already installed: $wiqVer"
} else {
    Write-Host "  Installing WorkIQ via npm..."
    npm install -g @microsoft/workiq
    if ($LASTEXITCODE -eq 0) {
        Refresh-Path
        Write-Host "  [OK]  WorkIQ installed." -ForegroundColor Green
        Log "WorkIQ installed via npm."
    } else {
        Write-Host "  WorkIQ install failed. Check npm output above." -ForegroundColor Red
        Log "WorkIQ npm install failed." "ERROR"
        exit 1
    }
}

# ─────────────────────────────────────────────────────────────
# Step 6: Accept WorkIQ EULA
# ─────────────────────────────────────────────────────────────
Step 6 "Accept WorkIQ EULA"

$eulaResult = workiq accept-eula 2>&1
$eulaStr = $eulaResult -join " "
if ($LASTEXITCODE -eq 0 -or $eulaStr -match "accepted|already") {
    Write-Host "  [OK]  EULA accepted." -ForegroundColor Green
    Log "WorkIQ EULA accepted."
} else {
    Write-Host "  EULA result: $eulaStr" -ForegroundColor Yellow
    Write-Host "  If this looks like an error, run: workiq accept-eula" -ForegroundColor Yellow
    Log "EULA result: $eulaStr" "WARN"
}

# ─────────────────────────────────────────────────────────────
# Step 7: WorkIQ Microsoft 365 authentication
# ─────────────────────────────────────────────────────────────
Step 7 "WorkIQ Microsoft 365 authentication"

Write-Host ""
Write-Host "  WorkIQ needs to authenticate with your Microsoft 365 account." -ForegroundColor Cyan
Write-Host "  A browser window will open. Sign in with your work account." -ForegroundColor Gray
Write-Host "  After signing in, come back here." -ForegroundColor Gray
Pause-ForUser "Press Enter to open the Microsoft 365 login..."

Write-Host "  Running WorkIQ... waiting for auth and results..."
Write-Host ""
$authResult = workiq ask -q "What are my meetings today?" 2>&1
Write-Host $authResult

$authStr = $authResult -join " "
if ($authStr -match "EULA|eula") {
    Write-Host ""
    Write-Host "  EULA prompt appeared. Running accept-eula and retrying..." -ForegroundColor Yellow
    workiq accept-eula 2>&1 | Out-Null
    $authResult = workiq ask -q "What are my meetings today?" 2>&1
    Write-Host $authResult
    $authStr = $authResult -join " "
}

if ($authStr -match "error|failed|unauthorized|unauthenticated" -and $authStr -notmatch "no meetings|no events|0 meetings|empty") {
    Write-Host ""
    Write-Host "  Auth may have issues. Check the output above." -ForegroundColor Yellow
    Write-Host "  If you see a calendar result (even empty), auth succeeded." -ForegroundColor Gray
    Log "WorkIQ auth result unclear: $authStr" "WARN"
} else {
    Write-Host ""
    Write-Host "  [OK]  WorkIQ authentication complete." -ForegroundColor Green
    Log "WorkIQ auth complete."
}

# ─────────────────────────────────────────────────────────────
# Step 8: Register WorkIQ as MCP server
# ─────────────────────────────────────────────────────────────
Step 8 "Register WorkIQ as MCP server"

if (-not (Test-Path $ConfigFile)) {
    $configDir = Split-Path $ConfigFile
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    '{}' | Set-Content -Path $ConfigFile
    Log "Created new config at $ConfigFile"
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

if (-not $config.PSObject.Properties["mcpServers"]) {
    $config | Add-Member -MemberType NoteProperty -Name "mcpServers" -Value ([PSCustomObject]@{})
}

$workiqMcp = [PSCustomObject]@{ command = "workiq"; args = @("mcp") }
$config.mcpServers | Add-Member -MemberType NoteProperty -Name "workiq" -Value $workiqMcp -Force

# Add C:\AIMaker to trusted_folders if not present
if (-not $config.PSObject.Properties["trusted_folders"]) {
    $config | Add-Member -MemberType NoteProperty -Name "trusted_folders" -Value @("C:\AIMaker")
} elseif (@($config.trusted_folders) -notcontains "C:\AIMaker") {
    $config.trusted_folders = @($config.trusted_folders) + "C:\AIMaker"
}

$config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigFile -Encoding UTF8
Write-Host "  [OK]  WorkIQ registered as MCP server." -ForegroundColor Green
Write-Host "  [OK]  C:\AIMaker added to trusted folders." -ForegroundColor Green
Log "WorkIQ MCP registered. trusted_folders updated. Config: $ConfigFile"

# ─────────────────────────────────────────────────────────────
# Step 9: Final verification
# ─────────────────────────────────────────────────────────────
Step 9 "Final verification"

Write-Host ""
Write-Host "  Running: workiq ask -q `"What are my meetings today?`""
$verifyResult = workiq ask -q "What are my meetings today?" 2>&1
Write-Host $verifyResult

$verifyStr = $verifyResult -join " "
if ($verifyStr -match "^error|^failed|unauthorized" -and $verifyStr -notmatch "no meetings|no events|0 meetings|empty") {
    Write-Host ""
    Write-Host "  Something may still be wrong. Review output above." -ForegroundColor Yellow
    Log "Verification result unclear: $verifyStr" "WARN"
} else {
    Write-Host ""
    Write-Host "  [OK]  WorkIQ verified." -ForegroundColor Green
    Log "Verification passed."
}

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  =========================="
Write-Host "  AI Maker Setup Complete" -ForegroundColor Green
Write-Host "  =========================="
Write-Host ""
Write-Host "  GitHub CLI:  authenticated"
Write-Host "  gh copilot:  extension installed"
Write-Host "  WorkIQ:      configured and authenticated"
Write-Host "  MCP server:  registered in Copilot CLI config"
Write-Host ""
Write-Host "  Config: $ConfigFile"
Write-Host "  Log:    $LogFile"
Write-Host ""
Write-Host "  You can now start AI Maker. Run start.ps1 from pc-setup," -ForegroundColor Gray
Write-Host "  or double-click the 'AI Agents' shortcut on your desktop." -ForegroundColor Gray
Write-Host ""

Log "=== AI Maker Setup complete ==="

$LogFile = "C:\AIMaker\logs\setup.log"
$ConfigFile = "$env:USERPROFILE\.copilot\config.json"

function Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    if ($Level -eq "ERROR") { Write-Host $line -ForegroundColor Red }
    elseif ($Level -eq "WARN") { Write-Host $line -ForegroundColor Yellow }
    else { Write-Host $line }
}

function Step {
    param([int]$Num, [string]$Title)
    Write-Host ""
    Write-Host "  Step ${Num}: $Title" -ForegroundColor Cyan
    Write-Host ("  " + "-" * 48)
    Log "Step $Num started: $Title"
}

New-Item -ItemType Directory -Path "C:\AIMaker\logs" -Force | Out-Null

Log "=== AI Maker WorkIQ Setup ==="
Write-Host ""
Write-Host "  AI Maker: WorkIQ Setup" -ForegroundColor Yellow
Write-Host "  ======================="
Write-Host ""
Write-Host "  This script completes WorkIQ and MCP configuration."
Write-Host "  Step 4 requires a browser login. Keep a browser window accessible."
Write-Host ""

# Step 1: Verify prerequisites
Step 1 "Verify prerequisites"

$prereqs = @("node", "npm", "git", "gh", "workiq")
$missing = @()
foreach ($cmd in $prereqs) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "  [OK]  $cmd at $($found.Source)"
        Log "  PREREQ OK: $cmd at $($found.Source)"
    } else {
        Write-Host "  [MISSING] $cmd not found on PATH" -ForegroundColor Red
        Log "  PREREQ MISSING: $cmd" "WARN"
        $missing += $cmd
    }
}

if ($missing -contains "workiq") {
    Step 2 "Install WorkIQ"
    Write-Host "  Installing WorkIQ via npm..."
    npm install -g @microsoft/workiq
    if ($LASTEXITCODE -ne 0) {
        Log "WorkIQ npm install failed." "ERROR"
        Write-Host ""
        Write-Host "  Install failed. Check npm output above." -ForegroundColor Red
        exit 1
    }
    Log "WorkIQ installed via npm."
} else {
    $wiqVer = workiq version 2>&1 | Select-Object -First 1
    Write-Host ""
    Write-Host "  [OK]  WorkIQ already installed: $wiqVer"
    Log "WorkIQ already installed: $wiqVer"
    Write-Host ""
    Write-Host "  Step 2: Install WorkIQ -- skipped (already installed)"
    Log "Step 2 skipped: WorkIQ already installed."
}

$nonWorkiq = $missing | Where-Object { $_ -ne "workiq" }
if ($nonWorkiq.Count -gt 0) {
    Log "Missing prerequisites: $($nonWorkiq -join ', ')" "ERROR"
    Write-Host ""
    Write-Host "  Missing required tools: $($nonWorkiq -join ', ')" -ForegroundColor Red
    Write-Host "  Run the main install.ps1 first to install prerequisites." -ForegroundColor Red
    exit 1
}

# Step 3: Accept EULA
Step 3 "Accept WorkIQ EULA"

$eulaResult = workiq accept-eula 2>&1
$eulaStr = $eulaResult -join " "
if ($eulaStr -match "already accepted|success|accepted") {
    Write-Host "  [OK]  EULA accepted."
    Log "EULA accepted."
} elseif ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK]  EULA accepted."
    Log "EULA accepted (exit 0)."
} else {
    Write-Host "  EULA output: $eulaStr" -ForegroundColor Yellow
    Log "EULA result: $eulaStr" "WARN"
}

# Step 4: Authenticate
Step 4 "Authenticate with Microsoft 365"
Write-Host ""
Write-Host "  A browser window will open for Microsoft device code login." -ForegroundColor Yellow
Write-Host "  Complete the login in your browser, then return here." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Press Enter to open the browser auth prompt..."
Read-Host

Write-Host "  Running: workiq ask -q `"What are my meetings today?`""
Write-Host "  (Complete browser auth if prompted, then wait for results...)"
Write-Host ""

$authResult = workiq ask -q "What are my meetings today?" 2>&1
$authStr = $authResult -join " "
Write-Host $authResult

if ($authStr -match "error|failed|unauthorized|unauthenticated" -and $authStr -notmatch "no meetings|no events|0 meetings") {
    Log "Auth may have failed: $authStr" "WARN"
    Write-Host ""
    Write-Host "  Auth result unclear. Check above for any error messages." -ForegroundColor Yellow
    Write-Host "  If you see results from your calendar, auth succeeded."
} else {
    Log "Auth step complete. WorkIQ returned results."
    Write-Host ""
    Write-Host "  [OK]  Authentication looks good." -ForegroundColor Green
}

# Step 5: Register WorkIQ as MCP server
Step 5 "Register WorkIQ as MCP server"

if (-not (Test-Path $ConfigFile)) {
    $configDir = Split-Path $ConfigFile
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    '{}' | Set-Content -Path $ConfigFile
    Log "Created new config at $ConfigFile"
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

if (-not $config.PSObject.Properties["mcpServers"]) {
    $config | Add-Member -MemberType NoteProperty -Name "mcpServers" -Value @{}
}

$workiqMcp = [PSCustomObject]@{
    command = "workiq"
    args    = @("mcp")
}

$config.mcpServers | Add-Member -MemberType NoteProperty -Name "workiq" -Value $workiqMcp -Force

$config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigFile -Encoding UTF8
Write-Host "  [OK]  WorkIQ registered as MCP server in $ConfigFile"
Log "WorkIQ MCP server registered in $ConfigFile."

# Also add C:\AIMaker to trusted_folders if not present
if ($config.PSObject.Properties["trusted_folders"]) {
    $tf = @($config.trusted_folders)
    if ($tf -notcontains "C:\\AIMaker") {
        $tf += "C:\\AIMaker"
        $config.trusted_folders = $tf
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $ConfigFile -Encoding UTF8
        Write-Host "  [OK]  Added C:\AIMaker to trusted_folders."
        Log "Added C:\AIMaker to trusted_folders."
    }
}

# Step 6: Verify
Step 6 "Verify full chain"
Write-Host ""
Write-Host "  Running: workiq ask -q `"What are my meetings today?`""
$verifyResult = workiq ask -q "What are my meetings today?" 2>&1
Write-Host $verifyResult

$verifyStr = $verifyResult -join " "
if ($verifyStr -match "error|failed|unauthorized") {
    Log "Verification returned errors: $verifyStr" "WARN"
    Write-Host ""
    Write-Host "  Verification may have issues. Review output above." -ForegroundColor Yellow
} else {
    Log "Verification passed."
    Write-Host ""
    Write-Host "  [OK]  WorkIQ is working." -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "  ======================="
Write-Host "  Setup Complete" -ForegroundColor Green
Write-Host "  ======================="
Write-Host ""
Write-Host "  WorkIQ is configured. AI Maker will now use it automatically"
Write-Host "  when you ask about email, calendar, or Teams."
Write-Host ""
Write-Host "  Config: $ConfigFile"
Write-Host "  Log:    $LogFile"
Write-Host ""

Log "=== Setup complete ==="
