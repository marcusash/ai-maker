# AI Maker Installer
# Run as Administrator on the team leader's machine.
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1

param(
    [switch]$SkipPrereqs,
    [switch]$TestOnly
)

$ErrorActionPreference = "Continue"
$WORKSPACE = "C:\AIMaker"
$ICON_URL  = "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$REPO_ROOT  = Resolve-Path "$SCRIPT_DIR\.."

function Write-Step($msg) { Write-Host "`n[AI Maker] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  FAIL: $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "  WARN: $msg" -ForegroundColor Yellow }

$results = [ordered]@{}

# -----------------------------------------------------------------------
# STEP 1: Prerequisites
# -----------------------------------------------------------------------
Write-Step "Checking prerequisites"

function Test-Command($cmd) { Get-Command $cmd -ErrorAction SilentlyContinue }

if (-not $SkipPrereqs) {

    # Node.js
    if (-not (Test-Command "node")) {
        Write-Warn "Node.js not found. Installing via winget..."
        winget install OpenJS.NodeJS.LTS --source winget --silent --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    if (Test-Command "node") {
        $nodeVer = node --version
        Write-OK "Node.js $nodeVer"
        $results["node"] = "PASS: $nodeVer"
    } else {
        Write-Fail "Node.js install failed. Install manually from https://nodejs.org then re-run."
        $results["node"] = "FAIL"
    }

    # Git
    if (-not (Test-Command "git")) {
        Write-Warn "Git not found. Installing via winget..."
        winget install Git.Git --source winget --silent --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    if (Test-Command "git") {
        $gitVer = git --version
        Write-OK $gitVer
        $results["git"] = "PASS: $gitVer"
    } else {
        Write-Fail "Git install failed."
        $results["git"] = "FAIL"
    }

    # GitHub CLI
    if (-not (Test-Command "gh")) {
        Write-Warn "GitHub CLI not found. Installing via winget..."
        winget install GitHub.cli --source winget --silent --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    if (Test-Command "gh") {
        $ghVer = gh --version | Select-Object -First 1
        Write-OK $ghVer
        $results["gh"] = "PASS: $ghVer"
    } else {
        Write-Fail "GitHub CLI install failed."
        $results["gh"] = "FAIL"
    }

    # PowerShell 7 (pwsh) -- required by GitHub Copilot CLI to run shell commands
    if (-not (Test-Command "pwsh")) {
        Write-Warn "PowerShell 7 not found. Installing via winget..."
        winget install Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    if (Test-Command "pwsh") {
        $pwshVer = pwsh --version
        Write-OK "PowerShell $pwshVer"
        $results["pwsh"] = "PASS: $pwshVer"
    } else {
        Write-Fail "PowerShell 7 install failed. Install manually from https://aka.ms/powershell then re-run."
        $results["pwsh"] = "FAIL"
    }
}

# -----------------------------------------------------------------------
# STEP 2: GitHub Authentication
# -----------------------------------------------------------------------
Write-Step "Checking GitHub authentication"

$authStatus = gh auth status 2>&1
$authOk = $LASTEXITCODE -eq 0
if ($authOk) {
    Write-OK "GitHub auth active"
    $results["gh-auth"] = "PASS"
} else {
    Write-Warn "Not logged in to GitHub. Launching browser login..."
    gh auth login --web --git-protocol https
    $results["gh-auth"] = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" }
}

# -----------------------------------------------------------------------
# STEP 3: GitHub Copilot CLI Extension
# -----------------------------------------------------------------------
Write-Step "Installing GitHub Copilot CLI extension"

$copilotHelp = gh copilot --help 2>&1
if ($LASTEXITCODE -eq 0 -or ($copilotHelp -match "copilot")) {
    Write-OK "Copilot CLI available (built-in in gh 2.x+)"
    $results["copilot-ext"] = "PASS"
} else {
    # Older gh versions need the extension installed
    gh extension install github/gh-copilot --force 2>&1 | Out-Null
    $copilotHelp2 = gh copilot --help 2>&1
    if ($LASTEXITCODE -eq 0 -or ($copilotHelp2 -match "copilot")) {
        Write-OK "Copilot extension installed"
        $results["copilot-ext"] = "PASS"
    } else {
        Write-Fail "Copilot CLI not available"
        $results["copilot-ext"] = "FAIL"
    }
}

# -----------------------------------------------------------------------
# STEP 4: WorkIQ Plugin
# -----------------------------------------------------------------------
Write-Step "Installing WorkIQ plugin"
& "$SCRIPT_DIR\install-workiq.ps1"
$results["workiq"] = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL (see above)" }

# -----------------------------------------------------------------------
# STEP 5: Workspace
# -----------------------------------------------------------------------
Write-Step "Creating AI Maker workspace at $WORKSPACE"

New-Item -ItemType Directory -Force -Path "$WORKSPACE\.github" | Out-Null
New-Item -ItemType Directory -Force -Path "$WORKSPACE\logs" | Out-Null
New-Item -ItemType Directory -Force -Path "$WORKSPACE\scripts" | Out-Null

# Copy copilot-instructions.md (the persona)
$src = "$REPO_ROOT\docs\ai-maker\copilot-instructions.md"
$dst = "$WORKSPACE\.github\copilot-instructions.md"
Copy-Item -Path $src -Destination $dst -Force
Write-OK "Persona installed: $dst"
$results["persona"] = "PASS"

# Copy all skill files into .github\skills\ so the agent can load them
New-Item -ItemType Directory -Force -Path "$WORKSPACE\.github\skills" | Out-Null
Get-ChildItem "$REPO_ROOT\docs\ai-maker\skills\*.md" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination "$WORKSPACE\.github\skills\$($_.Name)" -Force
}
Write-OK "Skills installed: $WORKSPACE\.github\skills\ ($((Get-ChildItem "$WORKSPACE\.github\skills\").Count) files)"
$results["skills"] = "PASS"

# Copy onboarding interview reference
Copy-Item -Path "$REPO_ROOT\docs\ai-maker\onboarding-interview.md" -Destination "$WORKSPACE\" -Force
Write-OK "Onboarding interview: $WORKSPACE\onboarding-interview.md"

# -----------------------------------------------------------------------
# STEP 6: Canvas
# -----------------------------------------------------------------------
Write-Step "Setting up Canvas"

New-Item -ItemType Directory -Force -Path "$WORKSPACE\canvas" | Out-Null
Copy-Item -Path "$SCRIPT_DIR\canvas.ps1" -Destination "$WORKSPACE\scripts\canvas.ps1" -Force
Copy-Item -Path "$REPO_ROOT\docs\ai-maker\getting-started.html" -Destination "$WORKSPACE\canvas\getting-started.html" -Force
Write-OK "Canvas script: $WORKSPACE\scripts\canvas.ps1"
Write-OK "Canvas folder: $WORKSPACE\canvas\"
$results["canvas"] = "PASS"

# -----------------------------------------------------------------------
# STEP 7: Vault
# -----------------------------------------------------------------------
Write-Step "Setting up Vault"

@("how-to","proposals","references","decisions") | ForEach-Object {
    New-Item -ItemType Directory -Force -Path "$WORKSPACE\vault\$_" | Out-Null
}

# Create vault README
$vaultReadme = @"
# Vault

Your working memory. Max 20 items. Only the things that matter most.

| Folder | What goes here |
|--------|---------------|
| how-to\ | Step-by-step guides you will run again |
| proposals\ | Documents waiting for your decision |
| references\ | Things you look up repeatedly |
| decisions\ | Final decisions, written down |

Tell AI Maker: "save this to the vault" or "remember this."
Always shows you the full path when it saves something here.
"@
[System.IO.File]::WriteAllText("$WORKSPACE\vault\README.md", $vaultReadme, [System.Text.UTF8Encoding]::new($false))

# Create decisions index
$decisionsIndex = @"
# Decisions Index

One line per decision. Date and summary.

| Date | Decision |
|------|---------|
"@
[System.IO.File]::WriteAllText("$WORKSPACE\vault\decisions\index.md", $decisionsIndex, [System.Text.UTF8Encoding]::new($false))

Write-OK "Vault: $WORKSPACE\vault\"
$results["vault"] = "PASS"

# -----------------------------------------------------------------------
# STEP 8: Desktop Shortcut
# -----------------------------------------------------------------------
Write-Step "Creating desktop shortcut"
& "$SCRIPT_DIR\create-shortcut.ps1" -WorkspacePath $WORKSPACE -ScriptDir $SCRIPT_DIR
$results["shortcut"] = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" }

# -----------------------------------------------------------------------
# STEP 9: Verification Tests
# -----------------------------------------------------------------------
Write-Step "Running verification tests"
& "$SCRIPT_DIR\test.ps1" -WorkspacePath $WORKSPACE
$results["tests"] = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" }

# -----------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor White
Write-Host "  AI Maker Install Summary" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White
$allPassed = $true
foreach ($key in $results.Keys) {
    $val = $results[$key]
    if ($val -like "PASS*") {
        Write-Host "  $key : $val" -ForegroundColor Green
    } else {
        Write-Host "  $key : $val" -ForegroundColor Red
        $allPassed = $false
    }
}

if ($allPassed) {
    Write-Host "`n  READY. Double-click 'AI Maker' on the desktop to start." -ForegroundColor Green
} else {
    Write-Host "`n  Some steps failed. Fix the FAIL items above and re-run." -ForegroundColor Red
    exit 1
}
