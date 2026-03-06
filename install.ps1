<#
.SYNOPSIS
    New PC setup: dev tools, GitHub, terminal themes, and AI agent workspaces.
.DESCRIPTION
    One-script installer for a new Windows machine. Installs dev tools,
    configures Git/GitHub, sets up Copilot CLI, applies Oh My Posh themes,
    and creates AI Maker + AI Workbench agent workspaces.

    FRESH MACHINE BOOTSTRAP (paste into Windows PowerShell as Admin):

      Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
      irm https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/pc-setup/main/install.ps1 -OutFile $env:TEMP\install.ps1
      powershell -ExecutionPolicy Bypass -File $env:TEMP\install.ps1

    OR if you already have Git:

      git clone https://github.com/YOUR_GITHUB_USERNAME/pc-setup C:\GitHub\pc-setup
      cd C:\GitHub\pc-setup
      powershell -ExecutionPolicy Bypass -File .\install.ps1
.NOTES
    Works with Windows PowerShell 5.1 (no pwsh required to start).
    Git, PowerShell 7, and all tools are installed by this script.
#>

param(
    [switch]$SkipApps,
    [switch]$SkipGit,
    [switch]$SkipThemes,
    [switch]$SkipRepos,
    [switch]$WhatIf
)

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Read-WTSettings {
    param([string]$Path)
    $raw = Get-Content $Path -Raw
    $lines = $raw -split "`n" | Where-Object { $_ -notmatch '^\s*//' -and $_ -notmatch '^\s*"\$' }
    $clean = ($lines -join "`n") -replace ',\s*([}\]])', '$1'
    return $clean | ConvertFrom-Json
}

function Install-WingetApp {
    param([string]$Id, [string]$Name)
    Write-Host "  $Name... " -NoNewline -ForegroundColor Gray
    $check = winget list --id $Id --accept-source-agreements 2>&1 | Out-String
    if ($check -match [regex]::Escape($Id)) {
        Write-Host "already installed" -ForegroundColor Green
    } elseif ($WhatIf) {
        Write-Host "would install" -ForegroundColor Yellow
    } else {
        winget install --id $Id -s winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        Refresh-Path
        Write-Host "installed" -ForegroundColor Green
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stepNum = 0
$totalSteps = 16
$failures = @()

function Step {
    param([string]$Title)
    $script:stepNum++
    $prefix = ""; if ($WhatIf) { $prefix = "[DRY RUN] " }
    Write-Host "`n[$script:stepNum/$totalSteps] $prefix$Title" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         AI Agent PC Setup            ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "  DRY RUN MODE: no changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

# ─────────────────────────────────────────────────────────────
# Step 0 — Pre-flight
# ─────────────────────────────────────────────────────────────

try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "  [OK]   Execution policy set to RemoteSigned" -ForegroundColor Green
    }
} catch { }

$psrlPaths = @(
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Modules\PSReadLine"),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Modules\PSReadLine"),
    (Join-Path $env:USERPROFILE "OneDrive - Microsoft\Documents\WindowsPowerShell\Modules\PSReadLine"),
    (Join-Path $env:USERPROFILE "OneDrive - Microsoft\Documents\PowerShell\Modules\PSReadLine")
)
foreach ($psrlPath in $psrlPaths) {
    if (Test-Path $psrlPath) {
        Get-ChildItem -Path $psrlPath -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
        Write-Host "  [OK]   Unblocked PSReadLine at $psrlPath" -ForegroundColor Green
    }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  [FAIL] winget not found. Install 'App Installer' from the Microsoft Store first." -ForegroundColor Red
    Write-Host "         https://aka.ms/getwinget" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "  Checking bootstrap prerequisites..." -ForegroundColor Cyan

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  Git not found. Installing..." -ForegroundColor Yellow
    winget install --id Microsoft.Git -s winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    Refresh-Path
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "  [OK]   Git installed" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Git install failed." -ForegroundColor Red
        $failures += "Git bootstrap"
    }
} else {
    Write-Host "  [OK]   Git found" -ForegroundColor Green
}

if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Write-Host "  PowerShell 7 not found. Installing..." -ForegroundColor Yellow
    winget install --id Microsoft.PowerShell -s winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    Refresh-Path
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Write-Host "  [OK]   PowerShell 7 installed" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] PowerShell 7 may require terminal restart" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [OK]   PowerShell 7 found" -ForegroundColor Green
}

if (-not $scriptDir -or -not (Test-Path (Join-Path $scriptDir ".git"))) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $pcSetupPath = "C:\GitHub\pc-setup"
        if (-not (Test-Path $pcSetupPath)) {
            Write-Host "  Cloning pc-setup repo..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Path "C:\GitHub" -Force -ErrorAction SilentlyContinue | Out-Null
            # The URL below will be updated once you push your repo to GitHub
            Write-Host "  [WARN] Run: git clone https://github.com/YOUR_GITHUB_USERNAME/pc-setup $pcSetupPath" -ForegroundColor Yellow
        } else {
            $scriptDir = $pcSetupPath
        }
    }
}

Write-Host ""

# ─────────────────────────────────────────────────────────────
# Step 1 — Collect user info
# ─────────────────────────────────────────────────────────────
Step "Collecting your information"

$configPath = Join-Path $scriptDir "user-config.ps1"
$SETUP_NAME = ""
$SETUP_GITHUB = ""
$SETUP_EMAIL = ""

if (Test-Path $configPath) {
    . $configPath
    Write-Host "  Found existing config: $SETUP_NAME ($SETUP_GITHUB)" -ForegroundColor Green
    $confirm = Read-Host "  Use this config? [Y/n]"
    if ($confirm -eq 'n' -or $confirm -eq 'N') {
        $SETUP_NAME = ""; $SETUP_GITHUB = ""; $SETUP_EMAIL = ""
    }
}

if (-not $SETUP_NAME) {
    Write-Host ""
    Write-Host "  This setup needs a few details about you." -ForegroundColor Cyan
    Write-Host ""

    do {
        $SETUP_NAME = Read-Host "  Your full name (e.g., Marcus Ash)"
    } while (-not $SETUP_NAME)

    do {
        $SETUP_GITHUB = Read-Host "  Your GitHub username (e.g., marcusash)"
    } while (-not $SETUP_GITHUB)

    $emailDefault = "$($SETUP_NAME.ToLower() -replace ' ', '')@microsoft.com"
    $emailInput = Read-Host "  Your work email [$emailDefault]"
    $SETUP_EMAIL = if ($emailInput) { $emailInput } else { $emailDefault }

    if (-not $WhatIf) {
        @"
# Auto-generated by install.ps1 — do not commit this file
`$SETUP_NAME   = "$SETUP_NAME"
`$SETUP_GITHUB = "$SETUP_GITHUB"
`$SETUP_EMAIL  = "$SETUP_EMAIL"
"@ | Set-Content $configPath -Encoding UTF8
        Write-Host ""
        Write-Host "  Config saved to $configPath" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  Name:   $SETUP_NAME" -ForegroundColor White
Write-Host "  GitHub: $SETUP_GITHUB" -ForegroundColor White
Write-Host "  Email:  $SETUP_EMAIL" -ForegroundColor White

# ─────────────────────────────────────────────────────────────
# Section 2 — Dev Tools
# ─────────────────────────────────────────────────────────────
if (-not $SkipApps) {

Step "Installing dev tools"

$devApps = @(
    @{ Id = "Microsoft.Git";              Name = "Git" },
    @{ Id = "GitHub.cli";                 Name = "GitHub CLI" },
    @{ Id = "GitHub.Copilot";             Name = "Copilot CLI" },
    @{ Id = "OpenJS.NodeJS.LTS";          Name = "Node.js (LTS)" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code" },
    @{ Id = "Microsoft.PowerShell";       Name = "PowerShell 7" }
)

foreach ($app in $devApps) { Install-WingetApp -Id $app.Id -Name $app.Name }

# ─────────────────────────────────────────────────────────────
# Section 3 — Productivity Apps
# ─────────────────────────────────────────────────────────────
Step "Installing productivity apps"

$prodApps = @(
    @{ Id = "Microsoft.WindowsTerminal";  Name = "Windows Terminal" },
    @{ Id = "cjpais.Handy";              Name = "Handy (Speech-to-Text)" }
)

foreach ($app in $prodApps) { Install-WingetApp -Id $app.Id -Name $app.Name }

# ─────────────────────────────────────────────────────────────
# Section 3b — Agency
# ─────────────────────────────────────────────────────────────
Step "Installing Agency (Agentic Engineering Platform)"

Write-Host "  Agency... " -NoNewline -ForegroundColor Gray
if (Get-Command agency -ErrorAction SilentlyContinue) {
    Write-Host "already installed" -ForegroundColor Green
} elseif ($WhatIf) {
    Write-Host "would install" -ForegroundColor Yellow
} else {
    $agencyInstalled = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $installScript = Invoke-RestMethod aka.ms/InstallTool.ps1
            $scriptBlock = [scriptblock]::Create($installScript)
            & $scriptBlock "agency"
            Refresh-Path
            if (Get-Command agency -ErrorAction SilentlyContinue) {
                Write-Host "installed" -ForegroundColor Green
                $agencyInstalled = $true
                break
            }
        } catch { }
        if ($attempt -lt 3) {
            Write-Host "retry ($attempt/3)... " -NoNewline -ForegroundColor Yellow
            Start-Sleep -Seconds (5 * $attempt)
        }
    }
    if (-not $agencyInstalled) {
        Write-Host "failed after 3 attempts" -ForegroundColor Red
        Write-Host "  Run manually: & ([scriptblock]::Create((irm aka.ms/InstallTool.ps1))) agency" -ForegroundColor Yellow
        $failures += "Agency install"
    }
}

Refresh-Path

} else {
    Step "Installing dev tools — SKIPPED (-SkipApps)"
    Step "Installing productivity apps — SKIPPED"
    Step "Installing Agency — SKIPPED"
}

# ─────────────────────────────────────────────────────────────
# Section 4 — Git Configuration
# ─────────────────────────────────────────────────────────────
if (-not $SkipGit) {

Step "Configuring Git"

$currentName = git config --global user.name 2>$null
$currentEmail = git config --global user.email 2>$null

if ($currentName -and $currentEmail) {
    Write-Host "  Already configured: $currentName <$currentEmail>" -ForegroundColor Green
} else {
    if (-not $WhatIf) {
        git config --global user.name $SETUP_NAME
        git config --global user.email $SETUP_EMAIL
    }
    Write-Host "  Set user: $SETUP_NAME <$SETUP_EMAIL>" -ForegroundColor Green
}

git config --global init.defaultBranch main 2>$null
Write-Host "  Default branch: main" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────
# Section 5 — GitHub CLI Authentication
# ─────────────────────────────────────────────────────────────
Step "Setting up GitHub CLI"

$ghAuth = gh auth status 2>&1 | Out-String
if ($ghAuth -match "Logged in") {
    $account = "unknown"; if ($ghAuth -match "account (\S+)") { $account = $Matches[1] }
    if ($account -eq "unknown") {
        Write-Host "  Logged in but username not resolved. Re-authenticating..." -ForegroundColor Yellow
        gh auth login --web --git-protocol https
        $ghAuth = gh auth status 2>&1 | Out-String
        $account = "unknown"; if ($ghAuth -match "account (\S+)") { $account = $Matches[1] }
    }
    if ($account -eq "unknown") {
        Write-Host "  WARNING: still showing as 'unknown'. Repo cloning may fail." -ForegroundColor Red
        $failures += "GitHub CLI auth (username unknown)"
    } else {
        Write-Host "  Already logged in as $account" -ForegroundColor Green
    }
} else {
    Write-Host "  Starting GitHub login (a browser window will open)..." -ForegroundColor Cyan
    Write-Host "  Follow the prompts in your browser to authenticate." -ForegroundColor Gray
    gh auth login --web --git-protocol https
    Write-Host ""
}

Write-Host "  Installing gh copilot extension... " -NoNewline
$ghExtensions = gh extension list 2>&1 | Out-String
if ($ghExtensions -match "copilot") {
    Write-Host "already installed" -ForegroundColor Green
} else {
    gh extension install github/gh-copilot 2>&1 | Out-Null
    Write-Host "installed" -ForegroundColor Green
}

} else {
    Step "Configuring Git — SKIPPED (-SkipGit)"
    Step "Setting up GitHub CLI — SKIPPED"
}

# ─────────────────────────────────────────────────────────────
# Section 6 — VS Code Extensions
# ─────────────────────────────────────────────────────────────
Step "Setting up VS Code extensions"

if (Get-Command code -ErrorAction SilentlyContinue) {
    $installed = code --list-extensions 2>$null | Out-String
    $extensions = @(
        @{ Id = "GitHub.copilot";      Name = "GitHub Copilot" },
        @{ Id = "GitHub.copilot-chat"; Name = "GitHub Copilot Chat" }
    )
    foreach ($ext in $extensions) {
        Write-Host "  $($ext.Name)... " -NoNewline -ForegroundColor Gray
        if ($installed -match $ext.Id) {
            Write-Host "already installed" -ForegroundColor Green
        } else {
            code --install-extension $ext.Id --force 2>&1 | Out-Null
            Write-Host "installed" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  VS Code not found in PATH — skipping. Restart terminal and re-run." -ForegroundColor Gray
}

# ─────────────────────────────────────────────────────────────
# Section 7 — Execution Policy
# ─────────────────────────────────────────────────────────────
Step "Verifying execution policy"

$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
Write-Host "  Execution policy: $currentPolicy" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────
# Section 8 — PSReadLine
# ─────────────────────────────────────────────────────────────
Step "Checking PSReadLine"

$psrlVersion = (Get-Module PSReadLine -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
if ($psrlVersion -lt [version]"2.1.0") {
    Write-Host "  PSReadLine $psrlVersion is too old, updating..." -ForegroundColor Yellow
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-Module PSReadLine -Force -SkipPublisherCheck -Scope CurrentUser
        $newVer = (Get-Module PSReadLine -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
        Write-Host "  Updated to $newVer" -ForegroundColor Green
    } catch {
        Write-Host "  WARNING: Could not update PSReadLine." -ForegroundColor Red
    }
} else {
    Write-Host "  PSReadLine $psrlVersion is OK" -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────
# Section 9 — Oh My Posh + Theme Picker
# ─────────────────────────────────────────────────────────────
if (-not $SkipThemes) {

Step "Setting up Oh My Posh + themes"

Write-Host "  Oh My Posh... " -NoNewline
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Write-Host "already installed ($(oh-my-posh version))" -ForegroundColor Green
} else {
    Install-WingetApp -Id "JanDeDobbeleer.OhMyPosh" -Name "Oh My Posh"
    Refresh-Path
}

Write-Host "  Installing Nerd Font (CascadiaCode)... " -NoNewline
$fontInstalled = $false
foreach ($flag in @("--user", "")) {
    if ($fontInstalled) { break }
    try {
        if ($flag) { $output = oh-my-posh font install CascadiaCode $flag 2>&1 | Out-String }
        else { $output = oh-my-posh font install CascadiaCode 2>&1 | Out-String }
        if ($output -match "Successfully") { $fontInstalled = $true }
    } catch {}
}
if ($fontInstalled) { Write-Host "installed" -ForegroundColor Green }
else { Write-Host "manual install needed: oh-my-posh font install CascadiaCode" -ForegroundColor Red }

# Theme picker
$themesPath = $null
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $themesPath = & oh-my-posh get shell-themes-path 2>$null
    if (-not $themesPath) { $themesPath = $env:POSH_THEMES_PATH }
}

Write-Host ""
Write-Host "  Choose a terminal theme:" -ForegroundColor Cyan
$themeChoices = @("dracula", "jandedobbeleer", "atomic", "nord", "pure")
for ($i = 0; $i -lt $themeChoices.Count; $i++) {
    Write-Host "    [$($i+1)] $($themeChoices[$i])"
}
Write-Host "    [Enter] dracula (default)"
Write-Host ""
$themeInput = Read-Host "  Enter number"
$selectedTheme = "dracula"
if ($themeInput -match '^\d+$') {
    $idx = [int]$themeInput - 1
    if ($idx -ge 0 -and $idx -lt $themeChoices.Count) {
        $selectedTheme = $themeChoices[$idx]
    }
}
Write-Host "  Selected: $selectedTheme" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────
# Section 10 — Shell Profiles
# ─────────────────────────────────────────────────────────────
Step "Configuring shell profiles"

$profileBlock = @"

# === PC-SETUP BEGIN ===
# GitHub Copilot CLI aliases
function ghcs { gh copilot suggest @args }
function ghce { gh copilot explain @args }

# Oh My Posh prompt theme
`$_ompTheme = "$selectedTheme"
`$_ompThemesPath = & oh-my-posh get shell-themes-path 2>`$null
if (-not `$_ompThemesPath) { `$_ompThemesPath = `$env:POSH_THEMES_PATH }
if (`$_ompThemesPath -and (Test-Path "`$_ompThemesPath\`$_ompTheme.omp.json")) {
    oh-my-posh init pwsh --config "`$_ompThemesPath\`$_ompTheme.omp.json" | Invoke-Expression
}
# === PC-SETUP END ===
"@

$docs = [Environment]::GetFolderPath("MyDocuments")
$profiles = @(
    (Join-Path $docs "PowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $docs "WindowsPowerShell\Microsoft.PowerShell_profile.ps1")
)

foreach ($p in $profiles) {
    $dir = Split-Path -Parent $p
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    $label = "PowerShell 7"; if ($p -match "WindowsPowerShell") { $label = "Windows PowerShell" }

    if (Test-Path $p) {
        $content = Get-Content $p -Raw
        if ($content -match 'PC-SETUP BEGIN') {
            $newContent = $content -replace '(?s)# === PC-SETUP BEGIN ===.*?# === PC-SETUP END ===', $profileBlock.Trim()
            if (-not $WhatIf) { Set-Content -Path $p -Value $newContent -Force }
            Write-Host "  $label profile - refreshed" -ForegroundColor Green
            continue
        }
    }

    if ($WhatIf) {
        Write-Host "  $label profile - would update" -ForegroundColor Yellow
    } else {
        Add-Content -Path $p -Value $profileBlock
        Write-Host "  $label profile - updated" -ForegroundColor Green
    }
}

} else {
    Step "Setting up Oh My Posh + themes — SKIPPED (-SkipThemes)"
    Step "Configuring shell profiles — SKIPPED"
}

# ─────────────────────────────────────────────────────────────
# Section 11 — Windows Terminal Profiles (AI Maker + AI Workbench)
# ─────────────────────────────────────────────────────────────
Step "Configuring Windows Terminal"

$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$wtSettings = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($wtSettings) {
    $settings = Read-WTSettings -Path $wtSettings

    $psCore = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"

    # Suppress application title so agent tabs keep their names
    if (-not $settings.profiles.defaults) {
        $settings.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    if (-not $settings.profiles.defaults.suppressApplicationTitle) {
        $settings.profiles.defaults | Add-Member -NotePropertyName "suppressApplicationTitle" -NotePropertyValue $true -Force
    }

    # Disable bell
    if ($settings.profiles.defaults.bellStyle -ne "none") {
        $settings.profiles.defaults | Add-Member -NotePropertyName "bellStyle" -NotePropertyValue "none" -Force
        Write-Host "  Terminal bell disabled" -ForegroundColor Green
    }

    # Add AI Maker profile (Yellow)
    $aiMakerGuid = "{a1f2e3d4-b5c6-7890-abcd-ef0123456789}"
    $aiWorkbenchGuid = "{b2e3f4a5-c6d7-8901-bcde-f01234567890}"

    $agentProfiles = @(
        @{ Guid = $aiMakerGuid;    Name = "AI Maker";    Color = "#FFCB05"; Dir = "C:\AIMaker" },
        @{ Guid = $aiWorkbenchGuid; Name = "AI Workbench"; Color = "#CE1126"; Dir = "C:\AIWorkbench" }
    )

    $existingGuids = @($settings.profiles.list | ForEach-Object { $_.guid })
    foreach ($ap in $agentProfiles) {
        if ($ap.Guid -notin $existingGuids) {
            $newProfile = [PSCustomObject]@{
                guid                    = $ap.Guid
                name                    = $ap.Name
                commandline             = "pwsh.exe -NoProfile"
                tabColor                = $ap.Color
                tabTitle                = $ap.Name
                suppressApplicationTitle = $true
                startingDirectory       = $ap.Dir
                hidden                  = $true
            }
            $settings.profiles.list += $newProfile
            Write-Host "  Added WT profile: $($ap.Name) ($($ap.Color))" -ForegroundColor Green
        } else {
            Write-Host "  WT profile already exists: $($ap.Name)" -ForegroundColor Gray
        }
    }

    # Set PS Core as default
    $settings.defaultProfile = $psCore

    # Ctrl+V paste binding (Handy compatibility)
    # Newer WT uses "actions", older versions use "keybindings"
    $bindingKey = if ($settings.PSObject.Properties["actions"]) { "actions" } else { "keybindings" }
    $existingBindings = $settings.PSObject.Properties[$bindingKey]
    $hasPaste = $false
    if ($existingBindings) {
        $hasPaste = ($settings.$bindingKey | Where-Object { $_.keys -eq "ctrl+v" }).Count -gt 0
    }
    if (-not $hasPaste) {
        $pasteBinding = [PSCustomObject]@{ id = "Terminal.PasteFromClipboard"; keys = "ctrl+v" }
        if (-not $existingBindings -or $settings.$bindingKey.Count -eq 0) {
            $settings | Add-Member -MemberType NoteProperty -Name $bindingKey -Value @($pasteBinding) -Force
        } else {
            $settings.$bindingKey += $pasteBinding
        }
        Write-Host "  Ctrl+V paste binding added (Handy compatibility)" -ForegroundColor Green
    }

    if (-not $WhatIf) {
        $settings | ConvertTo-Json -Depth 10 | Set-Content $wtSettings -Force
    }
    Write-Host "  Windows Terminal configured" -ForegroundColor Green
} else {
    Write-Host "  Windows Terminal settings not found — install WT first, then re-run" -ForegroundColor Yellow
}

# ─────────────────────────────────────────────────────────────
# Section 12 — Clone pc-setup Repo
# ─────────────────────────────────────────────────────────────
if (-not $SkipRepos) {

Step "Cloning pc-setup repo"

$pcSetupDest = "C:\GitHub\pc-setup"

if (Test-Path (Join-Path $pcSetupDest ".git")) {
    Write-Host "  pc-setup already exists at $pcSetupDest" -ForegroundColor Green
} elseif ($WhatIf) {
    Write-Host "  would copy setup files to $pcSetupDest, create GitHub repo, and push" -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Path $pcSetupDest -Force | Out-Null
    Copy-Item "$scriptDir\*" $pcSetupDest -Recurse -Force
    Set-Location $pcSetupDest
    git init | Out-Null
    git add -A | Out-Null
    git commit -m "Initial pc-setup" | Out-Null
    Write-Host "  Setup files copied to $pcSetupDest" -ForegroundColor Green

    # Create the GitHub repo and push
    $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghAvailable) {
        Write-Host "  Creating GitHub repo $SETUP_GITHUB/pc-setup..."
        gh repo create pc-setup --private --source . --remote origin --push 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Pushed to https://github.com/$SETUP_GITHUB/pc-setup" -ForegroundColor Green
        } else {
            Write-Host "  GitHub repo create failed — repo is local only at $pcSetupDest" -ForegroundColor Yellow
            Write-Host "  To push later: cd $pcSetupDest && gh repo create pc-setup --private --source . --push" -ForegroundColor Gray
        }
    } else {
        Write-Host "  gh CLI not available — repo is local only. Push manually after setup." -ForegroundColor Yellow
    }
    Set-Location $scriptDir
}

} else {
    Step "Cloning pc-setup repo — SKIPPED (-SkipRepos)"
}

# ─────────────────────────────────────────────────────────────
# Section 13 — AI Maker Workspace
# ─────────────────────────────────────────────────────────────
Step "Setting up AI Maker workspace"

$aiMakerDirs = @(
    "C:\AIMaker\.github\skills",
    "C:\AIMaker\docs",
    "C:\AIMaker\scripts",
    "C:\AIMaker\canvas",
    "C:\AIMaker\vault\how-to",
    "C:\AIMaker\vault\proposals",
    "C:\AIMaker\vault\references",
    "C:\AIMaker\vault\decisions",
    "C:\AIMaker\logs"
)
foreach ($d in $aiMakerDirs) {
    if (-not $WhatIf) { New-Item -ItemType Directory -Path $d -Force -ErrorAction SilentlyContinue | Out-Null }
}

# Copy agent instructions and skills from the repo
$aiMakerSource = Join-Path $scriptDir "agents\ai-maker"
if (Test-Path $aiMakerSource) {
    if (-not $WhatIf) {
        Copy-Item "$aiMakerSource\copilot-instructions.md" "C:\AIMaker\.github\copilot-instructions.md" -Force
        if (Test-Path "$aiMakerSource\skills") {
            Copy-Item "$aiMakerSource\skills\*" "C:\AIMaker\.github\skills\" -Force
        }
        if (Test-Path "$aiMakerSource\docs") {
            Copy-Item "$aiMakerSource\docs\*" "C:\AIMaker\docs\" -Force
        }
        if (Test-Path "$aiMakerSource\scripts") {
            Copy-Item "$aiMakerSource\scripts\*" "C:\AIMaker\scripts\" -Force
        }
    }
    Write-Host "  AI Maker workspace ready at C:\AIMaker" -ForegroundColor Green
    Write-Host "  Instructions and skills installed" -ForegroundColor Green
} else {
    Write-Host "  agents\ai-maker not found in repo — skipping file copy" -ForegroundColor Yellow
    $failures += "AI Maker: agents\ai-maker source not found"
}

# ─────────────────────────────────────────────────────────────
# Section 14 — AI Workbench Workspace
# ─────────────────────────────────────────────────────────────
Step "Setting up AI Workbench workspace"

$aiWorkbenchDirs = @(
    "C:\AIWorkbench\.github\skills",
    "C:\AIWorkbench\canvas",
    "C:\AIWorkbench\vault\how-to",
    "C:\AIWorkbench\vault\references",
    "C:\AIWorkbench\logs"
)
foreach ($d in $aiWorkbenchDirs) {
    if (-not $WhatIf) { New-Item -ItemType Directory -Path $d -Force -ErrorAction SilentlyContinue | Out-Null }
}

$aiWorkbenchSource = Join-Path $scriptDir "agents\ai-workbench"
if (Test-Path $aiWorkbenchSource) {
    if (-not $WhatIf) {
        Copy-Item "$aiWorkbenchSource\copilot-instructions.md" "C:\AIWorkbench\.github\copilot-instructions.md" -Force
        if (Test-Path "$aiWorkbenchSource\skills") {
            Copy-Item "$aiWorkbenchSource\skills\*" "C:\AIWorkbench\.github\skills\" -Force
        }
    }
    Write-Host "  AI Workbench workspace ready at C:\AIWorkbench" -ForegroundColor Green
    Write-Host "  Instructions and skills installed" -ForegroundColor Green
} else {
    Write-Host "  agents\ai-workbench not found in repo — skipping file copy" -ForegroundColor Yellow
    $failures += "AI Workbench: agents\ai-workbench source not found"
}

# ─────────────────────────────────────────────────────────────
# Section 14b — Personalization pass
# Replace [FIRST_NAME] placeholder in all installed agent files
# with the user's actual first name so the agent knows who they
# are from the very first session.
# ─────────────────────────────────────────────────────────────
Step "Personalizing agent files for $SETUP_NAME"

$firstName = $SETUP_NAME.Split(' ')[0]
$agentRoots = @('C:\AIMaker\.github', 'C:\AIWorkbench\.github')
foreach ($root in $agentRoots) {
    if (Test-Path $root) {
        Get-ChildItem $root -Recurse -File -Include *.md | ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            if ($content -match '\[FIRST_NAME\]') {
                $content = $content -replace '\[FIRST_NAME\]', $firstName
                Set-Content $_.FullName $content -NoNewline -Encoding UTF8
            }
        }
    }
}
Write-Host "  Agent files personalized for $firstName" -ForegroundColor Green


# ─────────────────────────────────────────────────────────────
Step "Setting up WorkIQ (Microsoft 365 integration)"

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

# Install WorkIQ if missing
$wiq = Get-Command workiq -ErrorAction SilentlyContinue
if ($wiq) {
    $wiqVer = workiq version 2>&1 | Select-Object -First 1
    Write-Host "  WorkIQ already installed: $wiqVer" -ForegroundColor Green
} else {
    Write-Host "  Installing WorkIQ via npm (@microsoft/workiq)..."
    if (-not $WhatIf) {
        npm install -g @microsoft/workiq
        if ($LASTEXITCODE -eq 0) {
            Refresh-Path
            Write-Host "  [OK]  WorkIQ installed." -ForegroundColor Green
        } else {
            Write-Host "  WorkIQ install failed. You can retry later: npm install -g @microsoft/workiq" -ForegroundColor Red
            $failures += "WorkIQ: npm install failed"
        }
    } else {
        Write-Host "  would install @microsoft/workiq" -ForegroundColor Yellow
    }
}

if (-not $WhatIf) {
    # Accept EULA
    Write-Host "  Accepting WorkIQ EULA..."
    $eulaResult = workiq accept-eula 2>&1
    $eulaStr = $eulaResult -join " "
    if ($LASTEXITCODE -eq 0 -or $eulaStr -match "accepted|already") {
        Write-Host "  [OK]  EULA accepted." -ForegroundColor Green
    } else {
        Write-Host "  EULA result: $eulaStr" -ForegroundColor Yellow
    }

    # Microsoft 365 authentication (interactive — browser required)
    Write-Host ""
    Write-Host "  WorkIQ needs to authenticate with your Microsoft 365 account." -ForegroundColor Cyan
    Write-Host "  A browser window will open. Sign in with your work account." -ForegroundColor Gray
    Write-Host "  After signing in, return here and press Enter." -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press Enter to open the Microsoft 365 login..."
    Write-Host "  Connecting to Microsoft 365 via WorkIQ..."
    $authResult = workiq ask -q "What are my meetings today?" 2>&1
    Write-Host $authResult

    $authStr = $authResult -join " "
    if ($authStr -match "EULA|eula") {
        workiq accept-eula 2>&1 | Out-Null
        $authResult = workiq ask -q "What are my meetings today?" 2>&1
        Write-Host $authResult
        $authStr = $authResult -join " "
    }

    if ($authStr -match "^error|^failed|unauthorized|unauthenticated" -and
        $authStr -notmatch "no meetings|no events|0 meetings|empty") {
        Write-Host "  WARNING: WorkIQ auth may not have completed. You can re-run:" -ForegroundColor Yellow
        Write-Host "    powershell -File C:\AIMaker\scripts\setup.ps1" -ForegroundColor Gray
        $failures += "WorkIQ: M365 auth may be incomplete"
    } else {
        Write-Host "  [OK]  WorkIQ authenticated with Microsoft 365." -ForegroundColor Green
    }

    # Register WorkIQ as MCP server in Copilot CLI config
    Write-Host "  Registering WorkIQ as MCP server..."
    $copilotConfig = "$env:USERPROFILE\.copilot\config.json"
    if (-not (Test-Path $copilotConfig)) {
        $configDir = Split-Path $copilotConfig
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        '{}' | Set-Content -Path $copilotConfig
    }
    $cfg = Get-Content $copilotConfig -Raw | ConvertFrom-Json
    if (-not $cfg.PSObject.Properties["mcpServers"]) {
        $cfg | Add-Member -MemberType NoteProperty -Name "mcpServers" -Value ([PSCustomObject]@{})
    }
    $cfg.mcpServers | Add-Member -MemberType NoteProperty -Name "workiq" -Value ([PSCustomObject]@{
        command = "workiq"; args = @("mcp")
    }) -Force
    if (-not $cfg.PSObject.Properties["trusted_folders"]) {
        $cfg | Add-Member -MemberType NoteProperty -Name "trusted_folders" -Value @("C:\AIMaker")
    } elseif (@($cfg.trusted_folders) -notcontains "C:\AIMaker") {
        $cfg.trusted_folders = @($cfg.trusted_folders) + "C:\AIMaker"
    }
    $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $copilotConfig -Encoding UTF8
    Write-Host "  [OK]  WorkIQ registered as MCP server in Copilot CLI config." -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────
# Section 16 — Desktop Shortcut
# ─────────────────────────────────────────────────────────────
Step "Creating desktop shortcut"

$launcherSource = Join-Path $scriptDir "start.ps1"
$shortcutDir = [Environment]::GetFolderPath('Desktop')
$consolePath = Join-Path $shortcutDir "AI Agents.lnk"

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) { $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe" }

if (Test-Path $launcherSource) {
    if (-not $WhatIf) {
        $shell = New-Object -ComObject WScript.Shell
        $s = $shell.CreateShortcut($consolePath)
        $s.TargetPath = $pwshPath
        $s.Arguments = "-ExecutionPolicy Bypass -File `"$launcherSource`""
        $s.WorkingDirectory = $scriptDir
        $s.Description = "Launch AI Maker and AI Workbench in Windows Terminal"
        $ghExe = "C:\Program Files\GitHub CLI\gh.exe"
        if (Test-Path $ghExe) { $s.IconLocation = "$ghExe,0" }
        $s.Save()
    }
    Write-Host "  Shortcut created: $consolePath" -ForegroundColor Green
} else {
    Write-Host "  start.ps1 not found — skipping shortcut" -ForegroundColor Yellow
}

# ─────────────────────────────────────────────────────────────
# Section 16 — Summary
# ─────────────────────────────────────────────────────────────
Write-Host ""

if ($failures.Count -gt 0) {
    Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║   Setup completed with errors        ║" -ForegroundColor Yellow
    Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Failed steps ($($failures.Count)):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "    [FAIL] $f" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  Fix the failed steps above, then re-run:" -ForegroundColor Yellow
    Write-Host "    powershell -ExecutionPolicy Bypass -File .\install.ps1" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║         Setup Complete!              ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

Write-Host "  IMPORTANT: Close and reopen Windows Terminal" -ForegroundColor Yellow
Write-Host "  for fonts and themes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "  What's ready:" -ForegroundColor White
Write-Host "    Dev tools      - Git, GitHub CLI, Copilot CLI, Node.js, VS Code, PowerShell 7" -ForegroundColor Gray
Write-Host "    Productivity   - Windows Terminal, Handy (Speech-to-Text)" -ForegroundColor Gray
Write-Host "    Agency         - Agentic Engineering Platform" -ForegroundColor Gray
Write-Host "    Git            - Configured as $SETUP_NAME" -ForegroundColor Gray
Write-Host "    GitHub         - Authenticated ($SETUP_GITHUB) + Copilot extension" -ForegroundColor Gray
Write-Host "    Terminal       - Oh My Posh themed ($selectedTheme)" -ForegroundColor Gray
Write-Host "    AI Maker       - Workspace at C:\AIMaker (yellow tab)" -ForegroundColor Gray
Write-Host "    AI Workbench   - Workspace at C:\AIWorkbench (red tab)" -ForegroundColor Gray
Write-Host "    Shortcut       - AI Agents on your Desktop" -ForegroundColor Gray
Write-Host ""
Write-Host "  To start your agents:" -ForegroundColor White
Write-Host "    Double-click 'AI Agents' on your Desktop" -ForegroundColor Gray
Write-Host "    OR run: pwsh -File C:\GitHub\pc-setup\start.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "  Next: Open the install guide in your browser:" -ForegroundColor White
Write-Host "    C:\GitHub\pc-setup\docs\install-guide.html" -ForegroundColor Gray
Write-Host ""
Write-Host "  Skip flags (for re-running):" -ForegroundColor White
Write-Host "    -SkipApps    -SkipGit    -SkipThemes    -SkipRepos" -ForegroundColor Gray
Write-Host ""
