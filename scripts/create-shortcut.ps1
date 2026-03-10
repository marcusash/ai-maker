# Create AI Maker desktop shortcut
# Usage: create-shortcut.ps1 [-WorkspacePath C:\AIMaker] [-ScriptDir <path>]

param(
    [string]$WorkspacePath = "C:\AIMaker",
    [string]$ScriptDir = $PSScriptRoot
)

$ErrorActionPreference = "Continue"

$launchScript = "$ScriptDir\launch.ps1"
$shortcutDest = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "AI Maker.lnk")

# Icon: check known locations, fall back to gh.exe, then cmd.exe
$iconPath = @(
    "$ScriptDir\ai-maker.ico",
    "$ScriptDir\assets\ai-maker.ico",
    "$WorkspacePath\.github\assets\ai-maker.ico"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iconPath) {
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCmd) { $iconPath = $ghCmd.Source }
}
if (-not $iconPath) { $iconPath = "C:\Windows\System32\cmd.exe" }

function New-Shortcut {
    param([string]$Dest)
    $shell    = New-Object -ComObject WScript.Shell
    $lnk      = $shell.CreateShortcut($Dest)
    $lnk.TargetPath       = "powershell.exe"
    $lnk.Arguments        = "-ExecutionPolicy Bypass -WindowStyle Normal -File `"$launchScript`""
    $lnk.WorkingDirectory = $WorkspacePath
    $lnk.IconLocation     = "$iconPath,0"
    $lnk.Description      = "AI Maker - your AI partner"
    $lnk.WindowStyle      = 1
    $lnk.Save()
}

New-Shortcut -Dest $shortcutDest

if (Test-Path $shortcutDest) {
    Write-Host "  OK: Desktop shortcut created: $shortcutDest" -ForegroundColor Green

    # Taskbar pin (best-effort - fails silently under group policy)
    $taskbarDest = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\AI Maker.lnk"
    try {
        New-Shortcut -Dest $taskbarDest
        Write-Host "  OK: Taskbar shortcut created (restart Explorer to see it)" -ForegroundColor Green
    } catch {
        Write-Host "  INFO: Taskbar pin requires manual drag from desktop." -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host "  FAIL: Shortcut creation failed at $shortcutDest" -ForegroundColor Red
    exit 1
}