# AI Maker Installer
# Usage: irm https://raw.githubusercontent.com/marcusash/ai-maker/main/bootstrap.ps1 | iex
# Or:    pwsh -ExecutionPolicy Bypass -File install.ps1

param(
    [switch]$SkipPrereqs,
    [switch]$TestOnly
)

$ErrorActionPreference = "Continue"
$WORKSPACE     = "C:\AIMaker"
$SCRIPT_DIR    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sourceRepoUrl = "https://github.com/marcusash/ai-maker"
$sourceTempDir = Join-Path $env:TEMP "ai-maker-src"
$results       = [ordered]@{}

# Warn if running as Administrator - gh extensions install to the elevated user profile
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host ""
    Write-Host "  WARNING: Running as Administrator. gh extensions install to the admin" -ForegroundColor Yellow
    Write-Host "  profile, not your normal user profile. Copilot CLI may not be available" -ForegroundColor Yellow
    Write-Host "  after install. Run this installer from a normal (non-admin) terminal." -ForegroundColor Yellow
    Write-Host ""
}

function Write-Step($msg) { Write-Host "`n[AI Maker] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  FAIL: $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "  WARN: $msg" -ForegroundColor Yellow }
function Refresh-Path     { $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") }
function Test-Cmd($cmd)   { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# Winget gate - install automatically if missing
if (-not (Test-Cmd winget)) {
    Write-Host ""
    Write-Host "  winget not found. Installing App Installer automatically..." -ForegroundColor Yellow
    $ProgressPreference = 'SilentlyContinue'
    try {
        # VCLibs dependency - skip if already installed (any version)
        if (-not (Get-AppxPackage -Name "Microsoft.VCLibs.140.00.UWPDesktop" -ErrorAction SilentlyContinue)) {
            Write-Host "  Installing VC++ runtime dependency..." -ForegroundColor Gray
            $vcLibs = "$env:TEMP\vclibs.appx"
            Invoke-WebRequest "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vcLibs -UseBasicParsing
            Add-AppxPackage $vcLibs -ErrorAction Stop
        }

        # UI Xaml dependency - skip if already installed (any version)
        if (-not (Get-AppxPackage -Name "Microsoft.UI.Xaml.2.8" -ErrorAction SilentlyContinue)) {
            Write-Host "  Installing UI Xaml dependency..." -ForegroundColor Gray
            $xaml = "$env:TEMP\ui-xaml.appx"
            Invoke-WebRequest "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx" -OutFile $xaml -UseBasicParsing
            Add-AppxPackage $xaml -ErrorAction Stop
        }

        # Winget itself
        Write-Host "  Installing winget..." -ForegroundColor Gray
        $pkg = "$env:TEMP\winget.msixbundle"
        Invoke-WebRequest "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $pkg -UseBasicParsing
        Add-AppxPackage $pkg -ErrorAction Stop

        Refresh-Path
        if (Test-Cmd winget) {
            Write-OK "winget installed successfully"
        } else {
            throw "winget still not found after install"
        }
    } catch {
        Write-Host ""
        Write-Host "  STOP: Could not auto-install winget: $_" -ForegroundColor Red
        Write-Host "  Install manually: https://aka.ms/getwinget  then re-run." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

function Get-SourceFiles {
    Write-Host "  Downloading AI Maker source files..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $sourceTempDir -ErrorAction SilentlyContinue
    git clone $sourceRepoUrl $sourceTempDir --depth 1 --quiet 2>&1 | Out-Null
    return (Test-Path (Join-Path $sourceTempDir "scripts\canvas.ps1"))
}

function Install-Prereq {
    param([string]$Name, [string]$Cmd, [string]$WingetId, [string]$FailMsg)
    if (-not (Test-Cmd $Cmd)) {
        Write-Warn "$Name not found. Installing via winget..."
        # Try user scope first (no UAC), fall back to machine scope if package doesn't support it
        winget install $WingetId --source winget --scope user --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            winget install $WingetId --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        }
        Refresh-Path
    }
    if (Test-Cmd $Cmd) {
        $allVer = & $Cmd --version 2>&1
        $ver    = $allVer | Select-Object -First 1
        Write-OK "$Name $ver"
        return "PASS: $ver"
    }
    Write-Fail "$Name install failed. $FailMsg"
    return "FAIL"
}

# -----------------------------------------------------------------------
# STEP 1: Prerequisites
# -----------------------------------------------------------------------
Write-Step "Checking prerequisites"

# Always re-clone when running from a temp path so re-runs get the latest scripts
$runningFromTemp = $SCRIPT_DIR -like "*\Temp\*" -or $SCRIPT_DIR -like "*/tmp/*"
$needsSourceClone = $runningFromTemp -or -not (Test-Path (Join-Path $SCRIPT_DIR "canvas.ps1"))

if (-not $SkipPrereqs) {
    $results["node"] = Install-Prereq -Name "Node.js" -Cmd "node" -WingetId "OpenJS.NodeJS.LTS" -FailMsg "Install manually from https://nodejs.org then re-run."
    $results["git"]  = Install-Prereq -Name "Git"     -Cmd "git"  -WingetId "Git.Git"           -FailMsg ""

    if ($results["git"] -like "PASS*" -and $needsSourceClone) {
        if (Get-SourceFiles) {
            $SCRIPT_DIR = Join-Path $sourceTempDir "scripts"
            Write-OK "AI Maker source files ready"
        } else {
            Write-Warn "Could not download source files from $sourceRepoUrl. Some steps may fail."
        }
    }

    $results["gh"]   = Install-Prereq -Name "GitHub CLI"     -Cmd "gh"   -WingetId "GitHub.cli"            -FailMsg ""
    $results["pwsh"] = Install-Prereq -Name "PowerShell 7"   -Cmd "pwsh" -WingetId "Microsoft.PowerShell"  -FailMsg "Install manually from https://aka.ms/powershell then re-run."
}

$REPO_ROOT = Split-Path -Parent $SCRIPT_DIR

# -----------------------------------------------------------------------
# STEP 2: GitHub Authentication
# -----------------------------------------------------------------------
Write-Step "Checking GitHub authentication"

if (-not (Test-Cmd gh)) {
    Write-Fail "gh CLI not available - skipping auth check"
    $results["gh-auth"] = "FAIL: gh not installed"
} else {
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "GitHub auth active"
        $results["gh-auth"] = "PASS"
    } else {
        Write-Warn "Not logged in to GitHub. Launching browser login..."
        gh auth login --web --git-protocol https
        $results["gh-auth"] = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" }
    }
}

# -----------------------------------------------------------------------
# STEP 3: Copilot CLI
# -----------------------------------------------------------------------
Write-Step "Checking Copilot CLI"

function Test-CopilotBinary { [bool](Get-Command copilot -ErrorAction SilentlyContinue) }

# gh copilot in gh 2.x is a built-in subcommand (not an extension).
# The standalone Copilot CLI binary (GitHub.Copilot) is the correct install target.
if (-not (Test-CopilotBinary)) {
    Write-Warn "Installing Copilot CLI via winget..."
    winget install GitHub.Copilot --source winget --scope user --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    Refresh-Path
}

if (Test-CopilotBinary) {
    $copilotVer = (copilot --version 2>&1 | Select-Object -First 1) -replace "GitHub Copilot CLI ",""
    Write-OK "Copilot CLI $copilotVer ready"
    $results["copilot-ext"] = "PASS"
} else {
    Write-Fail "Copilot CLI not found after install. Run: winget install GitHub.Copilot"
    $results["copilot-ext"] = "FAIL"
}

# -----------------------------------------------------------------------
# STEP 4: WorkIQ
# -----------------------------------------------------------------------
Write-Step "Installing WorkIQ plugin"
$workiqScript = "$SCRIPT_DIR\install-workiq.ps1"
if (Test-Path $workiqScript) {
    $wiqSuccess = $false
    try { & $workiqScript; $wiqSuccess = ($LASTEXITCODE -eq 0) } catch {}
    $results["workiq"] = if ($wiqSuccess) { "PASS" } else { "FAIL (see above)" }
} else {
    Write-Fail "install-workiq.ps1 not found at $workiqScript"
    $results["workiq"] = "FAIL: install script missing"
}

# -----------------------------------------------------------------------
# STEP 5: Workspace
# -----------------------------------------------------------------------
Write-Step "Creating AI Maker workspace at $WORKSPACE"

foreach ($dir in @("$WORKSPACE\.github\skills", "$WORKSPACE\logs", "$WORKSPACE\scripts", "$WORKSPACE\canvas")) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

function Copy-Doc {
    param([string]$Src, [string]$Dst, [string]$Label)
    if (Test-Path $Src) {
        Copy-Item -Path $Src -Destination $Dst -Force
        Write-OK "$Label installed"
        return $true
    }
    Write-Warn "$Label not found at $Src - skipping"
    return $false
}

if (Copy-Doc "$REPO_ROOT\docs\copilot-instructions.md" "$WORKSPACE\.github\copilot-instructions.md" "Persona") {
    # Also write to AGENTS.md in workspace root so Copilot CLI picks it up regardless of CWD
    Copy-Item "$REPO_ROOT\docs\copilot-instructions.md" "$WORKSPACE\AGENTS.md" -Force
    Write-OK "AGENTS.md installed (Copilot CLI persona root)"
    $results["persona"] = "PASS"
} else {
    $results["persona"] = "FAIL: source file missing"
}

$skillFiles = Get-ChildItem "$REPO_ROOT\docs\skills\*.md" -ErrorAction SilentlyContinue
if ($skillFiles) {
    $skillFiles | Copy-Item -Destination "$WORKSPACE\.github\skills\" -Force
    $skillCount = @(Get-ChildItem "$WORKSPACE\.github\skills\").Count
    Write-OK "Skills: $skillCount files installed"
    $results["skills"] = "PASS"
} else {
    Write-Warn "No skill files found - skipping"
    $results["skills"] = "WARN: no skill files found"
}

Copy-Doc "$REPO_ROOT\docs\onboarding-interview.md" "$WORKSPACE\onboarding-interview.md" "Onboarding interview" | Out-Null

# -----------------------------------------------------------------------
# STEP 6: Canvas
# -----------------------------------------------------------------------
Write-Step "Setting up Canvas"

$canvasSrc = "$SCRIPT_DIR\canvas.ps1"
if (Test-Path $canvasSrc) {
    Copy-Item -Path $canvasSrc -Destination "$WORKSPACE\scripts\canvas.ps1" -Force
    Write-OK "Canvas script installed"
    $results["canvas"] = "PASS"
} else {
    Write-Fail "canvas.ps1 not found at $canvasSrc"
    $results["canvas"] = "FAIL: canvas.ps1 missing"
}
# Copy launch script to workspace so the desktop shortcut has a permanent target
Copy-Doc "$SCRIPT_DIR\launch.ps1" "$WORKSPACE\scripts\launch.ps1" "Launch script" | Out-Null

# Copy icon to workspace so the shortcut can find it permanently
$assetDest = "$WORKSPACE\.github\assets"
New-Item -ItemType Directory -Force -Path $assetDest | Out-Null
$iconSrc = "$REPO_ROOT\assets\ai-maker.ico"
if (Test-Path $iconSrc) {
    Copy-Item -Path $iconSrc -Destination "$assetDest\ai-maker.ico" -Force
    Write-OK "Icon installed"
}

Copy-Doc "$REPO_ROOT\docs\getting-started.html" "$WORKSPACE\canvas\getting-started.html" "Getting started guide" | Out-Null

# -----------------------------------------------------------------------
# STEP 7: Vault
# -----------------------------------------------------------------------
Write-Step "Setting up Vault"

foreach ($d in @("how-to","proposals","references","decisions")) {
    New-Item -ItemType Directory -Force -Path "$WORKSPACE\vault\$d" | Out-Null
}

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
$decisionsIndex = @"
# Decisions Index

One line per decision. Date and summary.

| Date | Decision |
|------|---------|
"@
[System.IO.File]::WriteAllText("$WORKSPACE\vault\README.md", $vaultReadme, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText("$WORKSPACE\vault\decisions\index.md", $decisionsIndex, [System.Text.UTF8Encoding]::new($false))

Write-OK "Vault ready at $WORKSPACE\vault\"
$results["vault"] = "PASS"

# -----------------------------------------------------------------------
# STEP 8: Desktop Shortcut
# -----------------------------------------------------------------------
Write-Step "Creating desktop shortcut"
$shortcutScript = "$SCRIPT_DIR\create-shortcut.ps1"
if (Test-Path $shortcutScript) {
    & $shortcutScript -WorkspacePath $WORKSPACE -ScriptDir "$WORKSPACE\scripts"
    $results["shortcut"] = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" }
} else {
    Write-Fail "create-shortcut.ps1 not found at $shortcutScript"
    $results["shortcut"] = "FAIL: script missing"
}

# -----------------------------------------------------------------------
# STEP 9: Verification Tests
# -----------------------------------------------------------------------
Write-Step "Running verification tests"
$testScript = "$SCRIPT_DIR\test.ps1"
if (Test-Path $testScript) {
    & $testScript -WorkspacePath $WORKSPACE
    $results["tests"] = if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" }
} else {
    Write-Warn "test.ps1 not found - skipping verification"
    $results["tests"] = "SKIP: test script missing"
}

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
    } elseif ($val -like "WARN*") {
        Write-Host "  $key : $val" -ForegroundColor Yellow
    } else {
        Write-Host "  $key : $val" -ForegroundColor Red
        $allPassed = $false
    }
}

if ($allPassed) {
    Write-Host "`n  READY. Double-click 'AI Maker' on the desktop to start." -ForegroundColor Green
} else {
    Write-Host "`n  Some steps failed. Fix the FAIL items above, then re-run:" -ForegroundColor Red
    Write-Host "  irm https://raw.githubusercontent.com/marcusash/ai-maker/main/bootstrap.ps1 | iex" -ForegroundColor Yellow
    exit 1
}