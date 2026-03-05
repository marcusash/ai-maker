# AI Maker Setup Launcher
# Called by setup.bat. Handles path quoting correctly then elevates to run install.ps1.
$dir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $dir "scripts\install.ps1"
Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -Verb RunAs -Wait
