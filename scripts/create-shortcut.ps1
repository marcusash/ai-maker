# Create desktop shortcut for AI Maker
# Usage: create-shortcut.ps1 -WorkspacePath C:\AIMaker -ScriptDir <path>

param(
    [string]$WorkspacePath = "C:\AIMaker",
    [string]$ScriptDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

function Write-OK($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  FAIL: $msg" -ForegroundColor Red }

# Icon path (GitHub Octocat .ico)
$iconPath = "$ScriptDir\..\..\assets\ai-maker.ico"
if (-not (Test-Path $iconPath)) {
    # Fallback to gh CLI icon if custom icon not present
    $ghPath = Get-Command gh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    $iconPath = if ($ghPath) { $ghPath } else { "C:\Windows\System32\cmd.exe" }
}
$iconPath = Resolve-Path $iconPath -ErrorAction SilentlyContinue
if (-not $iconPath) { $iconPath = "C:\Windows\System32\cmd.exe" }

$launchScript = "$ScriptDir\launch.ps1"
$shortcutPath = [System.IO.Path]::Combine(
    [System.Environment]::GetFolderPath("Desktop"),
    "AI Maker.lnk"
)

$shell    = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath       = "powershell.exe"
$shortcut.Arguments        = "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$launchScript`""
$shortcut.WorkingDirectory = $WorkspacePath
$shortcut.IconLocation     = "$iconPath,0"
$shortcut.Description      = "AI Maker — your AI partner"
$shortcut.WindowStyle      = 1
$shortcut.Save()

if (Test-Path $shortcutPath) {
    Write-OK "Desktop shortcut created: $shortcutPath"

    # Also pin to taskbar via LayoutModification (best-effort, requires GPO or restart)
    try {
        $taskbarPath = [System.IO.Path]::Combine(
            [System.Environment]::GetFolderPath("Desktop"),
            "AI Maker.lnk"
        )
        $taskbarShortcut = $shell.CreateShortcut(
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\AI Maker.lnk"
        )
        $taskbarShortcut.TargetPath       = "powershell.exe"
        $taskbarShortcut.Arguments        = "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$launchScript`""
        $taskbarShortcut.WorkingDirectory = $WorkspacePath
        $taskbarShortcut.IconLocation     = "$iconPath,0"
        $taskbarShortcut.Save()
        Write-OK "Taskbar shortcut created (restart Explorer to see it)"
    } catch {
        Write-Host "  INFO: Taskbar pin requires manual drag from desktop." -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Fail "Shortcut creation failed: $shortcutPath"
    exit 1
}
