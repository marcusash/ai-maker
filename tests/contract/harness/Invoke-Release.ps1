#Requires -Version 7.0
<#
.SYNOPSIS
    AI Maker release builder + publisher. Assembles a flat-layout release
    from the vendored SUT, runs the pre-flight gate, then atomically tags
    and publishes to GitHub with rollback on failure.

.DESCRIPTION
    Steps:
      1. Run pre-flight gate (Invoke-PreflightGate.ps1). HALT on failure.
      2. Stage flat-layout release dir from sut/<tag>/ + agents/ + skills/.
      3. Build per-asset zips: skills.zip, agents.zip, ai-maker-<tag>.zip.
      4. SHA256 manifest of every published asset (pre-tag snapshot).
      5. `Remove-Item Env:GH_TOKEN -EA 0` (FP scar v3.0.7).
      6. Push tag.
      7. `gh release create` with all assets. On fail, rollback tag.
      8. Post-publish: curl each asset URL, confirm 200 + SHA matches manifest.

.PARAMETER Tag
    Release tag (e.g. 'v3.0.11').

.PARAMETER Repo
    GitHub repo (default 'marcusash_microsoft/ai-maker').

.PARAMETER SutVersion
    Vendored SUT version under tests/contract/fixtures/sut/ (default = $Tag).

.PARAMETER Title
    Release title.

.PARAMETER Notes
    Release notes (markdown).

.PARAMETER DryRun
    Run all steps EXCEPT git push and gh release create.

.PARAMETER SkipGate
    Skip pre-flight gate. Dangerous — use only if gate already ran in same session.

.EXAMPLE
    pwsh tests\contract\harness\Invoke-Release.ps1 -Tag v3.0.11 `
        -Title "v3.0.11 — Install-Skills idempotency fix" `
        -Notes "Fixes nested-dir bug in Install-Skills. Idempotent rerun no longer doubles file count."
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Tag,
    [string]$Repo = 'marcusash_microsoft/ai-maker',
    [string]$SutVersion = '',
    [string]$Title = "AI Maker $Tag",
    [string]$Notes = '',
    [switch]$DryRun,
    [switch]$SkipGate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

if (-not $SutVersion) { $SutVersion = $Tag }

$script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$script:SutRoot  = Join-Path $script:RepoRoot "tests\contract\fixtures\sut\$SutVersion"
$script:StageRoot = Join-Path $env:TEMP "ai-maker-release-$Tag"
$script:Manifest = @{}

function Step { param([string]$Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Info { param([string]$Msg) Write-Host "    $Msg" -ForegroundColor DarkGray }
function Ok   { param([string]$Msg) Write-Host "    ✓ $Msg" -ForegroundColor Green }
function Die  { param([string]$Msg) Write-Host "FATAL: $Msg" -ForegroundColor Red; exit 1 }

function Compute-Sha256 {
    param([string]$Path)
    (Get-FileHash $Path -Algorithm SHA256).Hash.ToLower()
}

Write-Host ""
Write-Host "=== AI Maker release builder — $Tag → $Repo ===" -ForegroundColor Cyan
Write-Host "    SUT: $script:SutRoot" -ForegroundColor DarkGray
Write-Host "    Stage: $script:StageRoot" -ForegroundColor DarkGray
if ($DryRun) { Write-Host "    *** DRY RUN — no git push / gh release create ***" -ForegroundColor Yellow }
Write-Host ""

# ──────────────────────────────────────────────────────────────────────
# 1. Pre-flight gate
# ──────────────────────────────────────────────────────────────────────
if (-not $SkipGate) {
    Step "Running pre-flight gate"
    & (Join-Path $PSScriptRoot 'Invoke-PreflightGate.ps1') -Tag $Tag -SutVersion $SutVersion -Repo $Repo
    if ($LASTEXITCODE -ne 0) { Die "Pre-flight gate FAILED. Fix and retry." }
    Ok "Gate PASS"
} else {
    Info "Skipping gate (--SkipGate)"
}

# ──────────────────────────────────────────────────────────────────────
# 2. Stage flat-layout release dir
# ──────────────────────────────────────────────────────────────────────
Step "Staging flat-layout release at $script:StageRoot"
if (Test-Path $script:StageRoot) { Remove-Item $script:StageRoot -Recurse -Force }
New-Item -ItemType Directory -Path $script:StageRoot -Force | Out-Null

# Core scripts from vendored SUT (the patched lib + URL-bumped installers)
foreach ($f in 'ai-maker-lib.ps1','install-blue.ps1','install-red.ps1','migrate.ps1','reset.ps1') {
    $src = Join-Path $script:SutRoot $f
    if (-not (Test-Path $src)) { Die "SUT missing required file: $f" }
    Copy-Item $src $script:StageRoot -Force
    Info "staged $f from SUT"
}

# Bootstrap from repo root (install.bat is flat-layout aware; reset.bat too)
foreach ($f in 'install.bat','reset.bat') {
    Copy-Item (Join-Path $script:RepoRoot $f) $script:StageRoot -Force
    Info "staged $f from repo root"
}

# Agents — use mock-content as canonical (FP source of truth for pill templates)
$stageAgents = Join-Path $script:StageRoot 'agents'
New-Item -ItemType Directory -Path $stageAgents -Force | Out-Null
$mockAgents = Join-Path $script:RepoRoot 'tests\contract\fixtures\shared\mock-content\agents'
foreach ($f in 'ai-maker.md','ai-workbench.md','copilot-instructions.blue.md','copilot-instructions.red.md') {
    $src = Join-Path $mockAgents $f
    if (-not (Test-Path $src)) { Die "Mock agents missing: $f" }
    Copy-Item $src $stageAgents -Force
    Info "staged agents\$f"
}

# Skills — straight copy from repo root
$stageSkills = Join-Path $script:StageRoot 'skills'
Copy-Item (Join-Path $script:RepoRoot 'skills') $script:StageRoot -Recurse -Force
$skillCount = (Get-ChildItem $stageSkills -Directory).Count
Info "staged skills/ ($skillCount dirs)"

Ok "Staging complete"

# ──────────────────────────────────────────────────────────────────────
# 2b. Stage user-facing extras (verify scripts + docs)
# ──────────────────────────────────────────────────────────────────────
Step "Staging release extras (verify.ps1/.bat, runbook, quickstart)"
$extrasDir = Join-Path $script:RepoRoot 'release-extras'
foreach ($f in 'verify.ps1','verify.bat','REAL-SMOKE-RUNBOOK.md','QUICKSTART.md') {
    $src = Join-Path $extrasDir $f
    if (-not (Test-Path $src)) { Die "release-extras missing: $f" }
    Copy-Item $src $script:StageRoot -Force
    Info "staged $f"
}
Ok "Extras staged"

# ──────────────────────────────────────────────────────────────────────
# 3. Build per-asset zips
# ──────────────────────────────────────────────────────────────────────
Step "Building release zips"

$assetsDir = Join-Path $env:TEMP "ai-maker-release-assets-$Tag"
if (Test-Path $assetsDir) { Remove-Item $assetsDir -Recurse -Force }
New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null

# skills.zip — zip contents of skills/ (no top-level dir wrapper)
$skillsZip = Join-Path $assetsDir 'skills.zip'
Compress-Archive -Path (Join-Path $stageSkills '*') -DestinationPath $skillsZip -Force
Info "built skills.zip ($([math]::Round((Get-Item $skillsZip).Length/1KB,1)) KB)"

# agents.zip — same pattern
$agentsZip = Join-Path $assetsDir 'agents.zip'
Compress-Archive -Path (Join-Path $stageAgents '*') -DestinationPath $agentsZip -Force
Info "built agents.zip ($([math]::Round((Get-Item $agentsZip).Length/1KB,1)) KB)"

# Bundle zip — whole staging dir (one-click for Marcus)
$bundleZip = Join-Path $assetsDir "ai-maker-$Tag.zip"
Compress-Archive -Path (Join-Path $script:StageRoot '*') -DestinationPath $bundleZip -Force
Info "built ai-maker-$Tag.zip ($([math]::Round((Get-Item $bundleZip).Length/1KB,1)) KB)"

# Individual scripts (kept flat for install-blue.ps1 bootstrap-from-URL flow)
foreach ($f in 'ai-maker-lib.ps1','install-blue.ps1','install-red.ps1','migrate.ps1','install.bat') {
    Copy-Item (Join-Path $script:StageRoot $f) $assetsDir -Force
}

Ok "Assets built in $assetsDir"

# ──────────────────────────────────────────────────────────────────────
# 4. SHA256 manifest (pre-publish snapshot)
# ──────────────────────────────────────────────────────────────────────
Step "Computing SHA256 manifest"
$manifestPath = Join-Path $assetsDir 'SHA256SUMS.txt'
$manifestLines = @()
foreach ($a in (Get-ChildItem $assetsDir -File | Where-Object Name -ne 'SHA256SUMS.txt')) {
    $h = Compute-Sha256 $a.FullName
    $script:Manifest[$a.Name] = $h
    $manifestLines += "$h  $($a.Name)"
    Info "$($a.Name) → $($h.Substring(0,16))..."
}
$manifestLines | Set-Content $manifestPath -Encoding utf8
Ok "Manifest written to SHA256SUMS.txt"

if ($DryRun) {
    Write-Host ""
    Write-Host "=== DRY RUN COMPLETE — assets staged at $assetsDir ===" -ForegroundColor Yellow
    Write-Host "    Would tag: $Tag" -ForegroundColor Yellow
    Write-Host "    Would publish to: https://github.com/$Repo/releases/tag/$Tag" -ForegroundColor Yellow
    exit 0
}

# ──────────────────────────────────────────────────────────────────────
# 5. Scrub GH_TOKEN (FP scar v3.0.7 — ambient token lacks repo write)
# ──────────────────────────────────────────────────────────────────────
Step "Scrubbing GH_TOKEN (FP v3.0.7 scar)"
Remove-Item Env:GH_TOKEN -EA SilentlyContinue
$ghAuthOk = $false
try {
    $authOut = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) { $ghAuthOk = $true; Ok "gh auth OK" }
} catch {}
if (-not $ghAuthOk) { Die "gh not authenticated after GH_TOKEN scrub. Run: gh auth login --web" }

# ──────────────────────────────────────────────────────────────────────
# 6. Push tag (annotated)
# ──────────────────────────────────────────────────────────────────────
Step "Tagging $Tag"
Push-Location $script:RepoRoot
try {
    # Check tag doesn't already exist locally or remotely
    $tagExistsLocal = (git tag -l $Tag) -eq $Tag
    $tagExistsRemote = $false
    git fetch origin "refs/tags/${Tag}:refs/tags/${Tag}" 2>$null
    if ((git tag -l $Tag) -eq $Tag) { $tagExistsRemote = $true }
    if ($tagExistsRemote) { Die "Tag $Tag already exists on remote. Aborting." }
    if ($tagExistsLocal) { git tag -d $Tag | Out-Null }

    git tag -a $Tag -m "$Title"
    if ($LASTEXITCODE -ne 0) { Die "git tag failed" }
    git push origin $Tag
    if ($LASTEXITCODE -ne 0) { Die "git push tag failed" }
    Ok "Tag $Tag pushed to origin"
} finally {
    Pop-Location
}

# ──────────────────────────────────────────────────────────────────────
# 7. gh release create with rollback on fail
# ──────────────────────────────────────────────────────────────────────
Step "Publishing GitHub release"
$assetArgs = @()
foreach ($a in (Get-ChildItem $assetsDir -File)) { $assetArgs += $a.FullName }

if (-not $Notes) {
    $Notes = @"
## $Title

Install-Skills idempotency fix. Rerunning Install-Skills no longer creates nested skill directories or doubles file counts.

**Verify:** Run install.bat → choose Blue or Red Pill → rerun installer → confirm no duplicate skills under workspace.

**Smoke checklist:** See ``REAL-SMOKE-RUNBOOK.md`` in this release.
"@
}

$notesFile = Join-Path $env:TEMP "release-notes-$Tag.md"
$Notes | Set-Content $notesFile -Encoding utf8

$releaseArgs = @(
    'release','create',$Tag
    '--repo',$Repo
    '--title',$Title
    '--notes-file',$notesFile
    '--verify-tag'
) + $assetArgs

Info "gh $($releaseArgs -join ' ')"
& gh @releaseArgs
$ghExit = $LASTEXITCODE
if ($ghExit -ne 0) {
    Write-Host "    gh release create FAILED (exit $ghExit). Rolling back tag..." -ForegroundColor Red
    Push-Location $script:RepoRoot
    try {
        git push --delete origin $Tag 2>&1 | Out-Null
        git tag -d $Tag 2>&1 | Out-Null
    } finally { Pop-Location }
    Die "Release failed and tag rolled back. Check gh output above."
}
Ok "Release published"

# ──────────────────────────────────────────────────────────────────────
# 8. Post-publish: curl each asset URL, verify 200 + SHA matches
# ──────────────────────────────────────────────────────────────────────
Step "Post-publish URL validation (FP v3.0.8 hash-drift gate)"
$baseUrl = "https://github.com/$Repo/releases/download/$Tag"
$verifyDir = Join-Path $env:TEMP "ai-maker-verify-$Tag"
if (Test-Path $verifyDir) { Remove-Item $verifyDir -Recurse -Force }
New-Item -ItemType Directory -Path $verifyDir -Force | Out-Null

$drift = @()
foreach ($name in $script:Manifest.Keys) {
    $url = "$baseUrl/$name"
    $dst = Join-Path $verifyDir $name
    try {
        # Brief wait — gh release create can lag asset availability
        Start-Sleep -Seconds 2
        Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing -ErrorAction Stop
        $publishedHash = Compute-Sha256 $dst
        $expectedHash = $script:Manifest[$name]
        if ($publishedHash -ne $expectedHash) {
            $drift += "$name : expected $($expectedHash.Substring(0,12))... got $($publishedHash.Substring(0,12))..."
        } else {
            Info "$name → 200 + SHA match"
        }
    } catch {
        $drift += "$name : URL fetch failed — $($_.Exception.Message)"
    }
}
if ($drift.Count -gt 0) {
    Write-Host ""
    Write-Host "POST-PUBLISH DRIFT DETECTED — release is BROKEN. Rolling back." -ForegroundColor Red
    foreach ($d in $drift) { Write-Host "  $d" -ForegroundColor Red }
    & gh release delete $Tag --repo $Repo --yes 2>&1 | Out-Null
    Push-Location $script:RepoRoot
    try {
        git push --delete origin $Tag 2>&1 | Out-Null
        git tag -d $Tag 2>&1 | Out-Null
    } finally { Pop-Location }
    Die "Post-publish gate failed. Release and tag rolled back."
}
Ok "All assets verified — 200 + SHA match"

Write-Host ""
Write-Host "=== RELEASE $Tag PUBLISHED ===" -ForegroundColor Green
Write-Host "    https://github.com/$Repo/releases/tag/$Tag" -ForegroundColor Cyan
Write-Host "    Bundle: $baseUrl/ai-maker-$Tag.zip" -ForegroundColor Cyan
Write-Host ""
