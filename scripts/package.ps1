# AI Maker Packager
# Builds a correctly-structured ai-maker.zip for distribution.
# Run from anywhere: powershell -File package.ps1
# Output: C:\Users\<user>\Downloads\ai-maker.zip

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$REPO_ROOT  = Resolve-Path "$SCRIPT_DIR\..\.."   # journal root

$OUT_ZIP = "$env:USERPROFILE\Downloads\ai-maker.zip"
$STAGE   = "$env:TEMP\ai-maker-stage-$(Get-Random)"

Write-Host "[Package] Staging to $STAGE" -ForegroundColor Cyan

# Clean slate
Remove-Item $STAGE -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$STAGE\scripts"   | Out-Null
New-Item -ItemType Directory -Force -Path "$STAGE\docs\ai-maker\skills" | Out-Null
# Resolve to long path (avoids 8.3 short-name length mismatch in Substring)
$STAGE = (Get-Item $STAGE).FullName

# --- scripts ---
$psFiles = @(
    "install.ps1","test.ps1","launch.ps1",
    "canvas.ps1","create-shortcut.ps1","install-workiq.ps1",
    "package.ps1"
)
foreach ($f in $psFiles) {
    $src = "$SCRIPT_DIR\$f"
    if (Test-Path $src) {
        Copy-Item $src "$STAGE\scripts\$f" -Force
    }
}

# --- docs/ai-maker root ---
foreach ($f in @("copilot-instructions.md","onboarding-interview.md","getting-started.html")) {
    $src = "$REPO_ROOT\docs\ai-maker\$f"
    if (Test-Path $src) {
        Copy-Item $src "$STAGE\docs\ai-maker\$f" -Force
    } else {
        Write-Warning "Missing: $src"
    }
}

# --- skills ---
Get-ChildItem "$REPO_ROOT\docs\ai-maker\skills\*.md" | ForEach-Object {
    Copy-Item $_.FullName "$STAGE\docs\ai-maker\skills\$($_.Name)" -Force
}

# --- icon ---
$iconSrc = "$REPO_ROOT\assets\ai-maker.ico"
if (Test-Path $iconSrc) {
    Copy-Item $iconSrc "$STAGE\scripts\ai-maker.ico" -Force
}

# --- zip using .NET for reliable multi-folder support ---
Remove-Item $OUT_ZIP -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($OUT_ZIP, [System.IO.Compression.ZipArchiveMode]::Create)

function Add-ToZip {
    param([System.IO.Compression.ZipArchive]$Archive, [string]$SourceDir, [string]$EntryPrefix)
    Get-ChildItem $SourceDir -Recurse -File | ForEach-Object {
        $rel   = $_.FullName.Substring($SourceDir.Length).TrimStart('\')
        $entry = "$EntryPrefix\$rel"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $_.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}

Add-ToZip -Archive $zip -SourceDir "$STAGE\scripts" -EntryPrefix "scripts"
Add-ToZip -Archive $zip -SourceDir "$STAGE\docs"    -EntryPrefix "docs"

# install-guide.html goes at zip root for immediate visibility
$guideSrc = "$REPO_ROOT\docs\ai-maker\install-guide.html"
if (Test-Path $guideSrc) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $guideSrc, "install-guide.html",
        [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
} else {
    Write-Warning "Missing: $guideSrc"
}
$zip.Dispose()
Remove-Item $STAGE -Recurse -Force

$size = [math]::Round((Get-Item $OUT_ZIP).Length / 1KB, 1)
Write-Host "[Package] Done: $OUT_ZIP ($size KB)" -ForegroundColor Green
Write-Host "  Structure inside ZIP:" -ForegroundColor Gray
Write-Host "    scripts\   <- run install.ps1 from here" -ForegroundColor Gray
Write-Host "    docs\ai-maker\   <- persona, interview, skills" -ForegroundColor Gray
