# Usage: pwsh -File publish.ps1  (or: & publish.ps1 from a PS7 session)
# Note: must run under PowerShell 7 (pwsh). Windows PowerShell 5.1 cannot load
#       System.IO.Compression.FileSystem reliably in this context.

param(
    [string]$TargetZip = "C:\Users\$env:USERNAME\OneDrive - Microsoft\ai-maker-designlab.zip"
)

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$REPO_ROOT  = Resolve-Path "$SCRIPT_DIR\.."   # C:\Github\ai-maker

$STAGE = "$env:TEMP\ai-maker-publish-$(Get-Random)"

Write-Host "[Publish] Staging content..." -ForegroundColor Cyan

Remove-Item $STAGE -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$STAGE\scripts"       | Out-Null
New-Item -ItemType Directory -Force -Path "$STAGE\docs\skills"   | Out-Null
$STAGE = (Get-Item $STAGE).FullName

# scripts
$psFiles = @("install.ps1","setup.ps1","test.ps1","launch.ps1","canvas.ps1","create-shortcut.ps1","install-workiq.ps1","package.ps1","publish.ps1")
foreach ($f in $psFiles) {
    $src = "$SCRIPT_DIR\$f"
    if (Test-Path $src) { Copy-Item $src "$STAGE\scripts\$f" -Force }
}

$iconSrc = "$REPO_ROOT\assets\ai-maker.ico"
if (Test-Path $iconSrc) { Copy-Item $iconSrc "$STAGE\scripts\ai-maker.ico" -Force }

# docs (no index.html - that goes to Design Lab only)
foreach ($f in @("copilot-instructions.md","onboarding-interview.md","getting-started.html")) {
    $src = "$REPO_ROOT\docs\$f"
    if (Test-Path $src) { Copy-Item $src "$STAGE\docs\$f" -Force }
    else { Write-Warning "Missing: $src" }
}

# skills
Get-ChildItem "$REPO_ROOT\docs\skills\*.md" | ForEach-Object {
    Copy-Item $_.FullName "$STAGE\docs\skills\$($_.Name)" -Force
}

# install-guide.html at zip root
$guideSrc = "$REPO_ROOT\docs\install-guide.html"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$TEMP_ZIP = "$env:TEMP\ai-maker-tmp-$(Get-Random).zip"
Remove-Item $TEMP_ZIP -Force -ErrorAction SilentlyContinue
$tmp = [System.IO.Compression.ZipFile]::Open($TEMP_ZIP, [System.IO.Compression.ZipArchiveMode]::Create)

function Add-ToZip {
    param($Archive, [string]$SourceDir, [string]$EntryPrefix)
    Get-ChildItem $SourceDir -Recurse -File | ForEach-Object {
        $rel   = $_.FullName.Substring($SourceDir.Length).TrimStart('\')
        $entry = if ($EntryPrefix) { "$EntryPrefix\$rel" } else { $rel }
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $_.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}

Add-ToZip -Archive $tmp -SourceDir "$STAGE\scripts" -EntryPrefix "scripts"
Add-ToZip -Archive $tmp -SourceDir "$STAGE\docs"    -EntryPrefix "docs"

# setup.bat and setup.ps1 at zip root
$setupBat = "$REPO_ROOT\setup.bat"
$setupPs1 = "$REPO_ROOT\setup.ps1"
foreach ($f in @($setupBat, $setupPs1)) {
    if (Test-Path $f) {
        $name = Split-Path $f -Leaf
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($tmp, $f, $name, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    } else {
        Write-Warning "Missing: $f"
    }
}

if (Test-Path $guideSrc) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($tmp, $guideSrc, "INSTALL-GUIDE.html", [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
} else {
    Write-Warning "Missing: $guideSrc"
}
$tmp.Dispose()

Write-Host "[Publish] Writing to $TargetZip (in-place, share link preserved)..." -ForegroundColor Cyan

if (-not (Test-Path $TargetZip)) {
    Write-Warning "Target ZIP not found at $TargetZip. Creating new file. A new share link will be needed."
}

$bytes = [System.IO.File]::ReadAllBytes($TEMP_ZIP)
[System.IO.File]::WriteAllBytes($TargetZip, $bytes)

Remove-Item $TEMP_ZIP -Force
Remove-Item $STAGE -Recurse -Force

$size = [math]::Round((Get-Item $TargetZip).Length / 1KB, 1)
Write-Host "[Publish] Done. $TargetZip updated ($size KB). Share link preserved." -ForegroundColor Green
Write-Host ""
Write-Host "  ZIP contents:" -ForegroundColor Gray
Write-Host "    setup.bat            <- double-click this to install" -ForegroundColor Gray
Write-Host "    INSTALL-GUIDE.html   <- open this first" -ForegroundColor Gray
Write-Host "    scripts\             <- run install.ps1 from here" -ForegroundColor Gray
Write-Host "    docs\                <- persona, interview, skills" -ForegroundColor Gray
Write-Host ""
Write-Host "  Design Lab: upload docs\index.html separately." -ForegroundColor Yellow