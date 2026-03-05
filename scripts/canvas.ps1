# canvas.ps1 - AI Maker Canvas launcher
# Opens an HTML file as a full-screen app window (no browser chrome).
# The AI Maker agent uses this to display visuals, dashboards, and documents.
#
# Usage (from C:\AIMaker):
#   .\scripts\canvas.ps1 canvas\my-visual.html
#   .\scripts\canvas.ps1 canvas\my-visual.html -Width 1600 -Height 1000
#
# The agent can also run this for you automatically after creating a canvas file.

param(
    [Parameter(Mandatory=$true)][string]$Path,
    [int]$Width  = 1400,
    [int]$Height = 900
)

# Resolve to absolute path
if (-not [System.IO.Path]::IsPathRooted($Path)) {
    $Path = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition | Split-Path -Parent) $Path
}

if (-not (Test-Path $Path)) {
    Write-Error "canvas: file not found: $Path"
    exit 1
}

$abs = Resolve-Path $Path
$uri = "file:///" + ($abs.Path -replace '\\', '/')
$appArgs = "--app=$uri --window-size=$Width,$Height"

# Launch in Edge (standard on all Microsoft machines). Falls back to Chrome.
$edge86 = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
$edge   = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
$chrome = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"

if     (Test-Path $edge86)  { Start-Process $edge86 $appArgs }
elseif (Test-Path $edge)    { Start-Process $edge $appArgs }
elseif (Test-Path $chrome)  { Start-Process $chrome $appArgs }
else {
    Write-Error "canvas: Microsoft Edge not found. Install Edge or Chrome to use Canvas."
    exit 1
}

Write-Host "Canvas open: $($abs.Path)" -ForegroundColor Cyan
