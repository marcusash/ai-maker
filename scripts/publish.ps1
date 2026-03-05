# AI Maker Publisher
# Builds fresh content and writes it into the EXISTING OneDrive ZIP in-place.
# Never deletes the target file. Preserves the OneDrive item ID and share link.
# Run from anywhere: powershell -File publish.ps1

param(
    [string]$TargetZip = "C:\Users\$env:USERNAME\OneDrive - Microsoft\ai-maker-designlab.zip"
)

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$REPO_ROOT  = Resolve-Path "$SCRIPT_DIR\..\.."

$STAGE = "$env:TEMP\ai-maker-publish-$(Get-Random)"

Write-Host "[Publish] Staging content..." -ForegroundColor Cyan

Remove-Item $STAGE -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$STAGE\scripts"              | Out-Null
New-Item -ItemType Directory -Force -Path "$STAGE\docs\ai-maker\skills" | Out-Null
$STAGE = (Get-Item $STAGE).FullName

$psFiles = @("install.ps1","test.ps1","launch.ps1","canvas.ps1","create-shortcut.ps1","install-workiq.ps1","package.ps1","publish.ps1")
foreach ($f in $psFiles) {
    $src = "$SCRIPT_DIR\$f"
    if (Test-Path $src) { Copy-Item $src "$STAGE\scripts\$f" -Force }
}

foreach ($f in @("copilot-instructions.md","onboarding-interview.md","getting-started.html","index.html")) {
    $src = "$REPO_ROOT\docs\ai-maker\$f"
    if (Test-Path $src) { Copy-Item $src "$STAGE\docs\ai-maker\$f" -Force }
    else { Write-Warning "Missing: $src" }
}

Get-ChildItem "$REPO_ROOT\docs\ai-maker\skills\*.md" | ForEach-Object {
    Copy-Item $_.FullName "$STAGE\docs\ai-maker\skills\$($_.Name)" -Force
}

$iconSrc = "$REPO_ROOT\assets\ai-maker.ico"
if (Test-Path $iconSrc) { Copy-Item $iconSrc "$STAGE\scripts\ai-maker.ico" -Force }

$guideSrc = "$REPO_ROOT\docs\ai-maker\install-guide.html"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$TEMP_ZIP = "$env:TEMP\ai-maker-tmp-$(Get-Random).zip"
Remove-Item $TEMP_ZIP -Force -ErrorAction SilentlyContinue
$tmp = [System.IO.Compression.ZipFile]::Open($TEMP_ZIP, [System.IO.Compression.ZipArchiveMode]::Create)

function Add-ToZip {
    param([System.IO.Compression.ZipArchive]$Archive, [string]$SourceDir, [string]$EntryPrefix)
    Get-ChildItem $SourceDir -Recurse -File | ForEach-Object {
        $rel   = $_.FullName.Substring($SourceDir.Length).TrimStart('\')
        $entry = "$EntryPrefix\$rel"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $_.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}

Add-ToZip -Archive $tmp -SourceDir "$STAGE\scripts" -EntryPrefix "scripts"
Add-ToZip -Archive $tmp -SourceDir "$STAGE\docs"    -EntryPrefix "docs"

if (Test-Path $guideSrc) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($tmp, $guideSrc, "install-guide.html", [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
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