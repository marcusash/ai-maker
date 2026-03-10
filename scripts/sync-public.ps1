<#
.SYNOPSIS
    Sync enterprise robin-setup to personal GitHub repos (marcusash/ai-maker, marcusash/gh-copilot-setup).
.DESCRIPTION
    Same pattern as MCM (marcusash_microsoft/kai-algebra2-tests -> marcusash/motor-city-math).
    Copies the correct subset of files from C:\Github\pc-setup-template to a local clone of the target
    personal repo, commits, and pushes.
.PARAMETER Target
    Which repo to sync: 'ai-maker' or 'gh-copilot-setup'
.PARAMETER Message
    Optional commit message. Defaults to "sync from enterprise".
.PARAMETER DryRun
    Show what would be copied without actually syncing.
.EXAMPLE
    .\sync-public.ps1 -Target ai-maker
    .\sync-public.ps1 -Target gh-copilot-setup -Message "security fixes applied"
    .\sync-public.ps1 -Target ai-maker -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('ai-maker', 'gh-copilot-setup')]
    [string]$Target,

    [string]$Message = "sync from enterprise",

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Source = "C:\Github\pc-setup-template"
$PersonalBase = "C:\Github"

# File mappings: source (relative to robin-setup) -> destination (relative to target repo root)
# Use "/" as destination to mean "copy to root with same name"
# Use "rename:newname" to rename on copy
$FileMap = @{
    'ai-maker' = @(
        @{ src = 'agents\ai-maker';                    dst = 'agents\ai-maker' }
        @{ src = 'docs\install-guide.html';             dst = 'docs\install-guide.html' }
        @{ src = 'agents\ai-maker\scripts\setup.ps1';   dst = 'setup.ps1' }
        @{ src = 'README-ai-maker.md';                  dst = 'README.md' }
        @{ src = '.gitignore';                          dst = '.gitignore' }
    )
    'gh-copilot-setup' = @(
        @{ src = 'agents';              dst = 'agents' }
        @{ src = 'docs';                dst = 'docs' }
        @{ src = 'install.ps1';         dst = 'install.ps1' }
        @{ src = 'setup.bat';           dst = 'setup.bat' }
        @{ src = 'start.ps1';           dst = 'start.ps1' }
        @{ src = 'stop.ps1';            dst = 'stop.ps1' }
        @{ src = 'STARTUP.md';          dst = 'STARTUP.md' }
        @{ src = 'README-gh-copilot-setup.md'; dst = 'README.md' }
        @{ src = '.gitignore';          dst = '.gitignore' }
    )
}

$PersonalUrls = @{
    'ai-maker'         = 'https://marcusash@github.com/marcusash/ai-maker.git'
    'gh-copilot-setup' = 'https://marcusash@github.com/marcusash/gh-copilot-setup.git'
}

$TargetDir = Join-Path $PersonalBase $Target

Write-Host ""
Write-Host "=== sync-public: $Target ===" -ForegroundColor Cyan
Write-Host "Source:      $Source"
Write-Host "Target repo: $TargetDir"
Write-Host "Remote:      $($PersonalUrls[$Target])"
Write-Host ""

# Step 1: Pull latest enterprise source
Write-Host "[1/5] Pulling latest from enterprise origin..." -ForegroundColor Yellow
Push-Location $Source
git pull origin main --quiet 2>$null
if ($LASTEXITCODE -ne 0) {
    git pull origin master --quiet 2>$null
}
Pop-Location

# Step 2: Security gate (skipped in dry-run mode)
if (-not $DryRun) {
    Write-Host ""
    Write-Host "[2/5] SECURITY GATE" -ForegroundColor Red
    Write-Host "Confirm: all CRITICAL security fixes applied?" -ForegroundColor Red
    Write-Host "  - No OneDrive URLs in docs"
    Write-Host "  - No hardcoded user paths (C:\Users\marcusash\)"
    Write-Host "  - No internal team initials or Forge references"
    Write-Host "  - No real names in persona fields"
    Write-Host ""
    $confirm = Read-Host "Security gate confirmed? [y/N]"
    if ($confirm -ne 'y') {
        Write-Host "Aborted. Apply security fixes first." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[2/5] SECURITY GATE (skipped in dry-run)" -ForegroundColor DarkYellow
}

# Step 3: Clone or verify target repo
Write-Host ""
Write-Host "[3/5] Preparing target repo..." -ForegroundColor Yellow
if (-not (Test-Path $TargetDir)) {
    Write-Host "Cloning $($PersonalUrls[$Target])..."
    git clone $PersonalUrls[$Target] $TargetDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Clone failed. Initializing fresh repo..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
        Push-Location $TargetDir
        git init
        git remote add origin $PersonalUrls[$Target]
        Pop-Location
    }
} else {
    Write-Host "Target exists, pulling latest..."
    Push-Location $TargetDir
    git pull origin main --quiet 2>$null
    Pop-Location
}

# Step 4: Copy files
Write-Host ""
Write-Host "[4/5] Copying files..." -ForegroundColor Yellow
$entries = $FileMap[$Target]

if ($DryRun) {
    Write-Host "(DRY RUN - no files will be copied)" -ForegroundColor Magenta
}

# Clear existing content (except .git)
if (-not $DryRun) {
    Get-ChildItem $TargetDir -Force | Where-Object { $_.Name -ne '.git' } | Remove-Item -Recurse -Force
}

foreach ($entry in $entries) {
    $srcPath = Join-Path $Source $entry.src
    $dstPath = Join-Path $TargetDir $entry.dst

    if (-not (Test-Path $srcPath)) {
        Write-Host "  SKIP (not found): $($entry.src)" -ForegroundColor DarkYellow
        continue
    }

    $isDir = (Get-Item $srcPath).PSIsContainer

    if ($DryRun) {
        $label = if ($isDir) { "[dir]" } else { "[file]" }
        Write-Host "  $label $($entry.src) -> $($entry.dst)"
        continue
    }

    if ($isDir) {
        $dstParent = Split-Path $dstPath -Parent
        if (-not (Test-Path $dstParent)) { New-Item -ItemType Directory -Path $dstParent -Force | Out-Null }
        Copy-Item $srcPath $dstPath -Recurse -Force
        $count = (Get-ChildItem $srcPath -Recurse -File).Count
        Write-Host "  [dir]  $($entry.src) -> $($entry.dst) ($count files)"
    } else {
        $dstParent = Split-Path $dstPath -Parent
        if (-not (Test-Path $dstParent)) { New-Item -ItemType Directory -Path $dstParent -Force | Out-Null }
        Copy-Item $srcPath $dstPath -Force
        Write-Host "  [file] $($entry.src) -> $($entry.dst)"
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry run complete. No changes made." -ForegroundColor Magenta
    exit 0
}

# Step 5: Commit and push
Write-Host ""
Write-Host "[5/5] Committing and pushing..." -ForegroundColor Yellow
Push-Location $TargetDir
git add -A
$status = git status --porcelain
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "No changes to commit. Repos are in sync." -ForegroundColor Green
} else {
    git commit -m "$Message`n`nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
    git branch -M main
    git push origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Push failed. You may need to: gh auth switch --user marcusash" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "Pushed to $($PersonalUrls[$Target])" -ForegroundColor Green
}
Pop-Location

Write-Host ""
Write-Host "=== sync-public: $Target complete ===" -ForegroundColor Cyan
