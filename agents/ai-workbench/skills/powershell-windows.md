# Skill: PowerShell and Windows

## When to Use This Skill

Use this skill whenever:
- Writing or reviewing PowerShell scripts
- Debugging Windows environment issues
- Managing files, processes, registry, or system settings
- Automating tasks on a Windows machine
- Helping the human run something in their terminal

---

## Core Principles

**Read before writing.** Before editing a file or running a command that changes state, read the current state first. Describe what the command will do. Ask for confirmation if the change is not easily reversible.

**Test with -WhatIf first.** Any script that modifies files, settings, or processes should support `-WhatIf`. Run it with `-WhatIf` to preview before executing.

**Prefer native cmdlets.** Use `Where-Object` not `grep`. Use `Select-Object` not `awk`. PowerShell has cmdlets for almost everything. Use them.

**Quote all paths.** Any path containing a space must be quoted. Even if the current path has no spaces, a future one might. Quote by default.

**Use `$env:USERPROFILE`, not `~`.** The tilde works in PowerShell but not in all contexts. `$env:USERPROFILE` is always reliable.

---

## Common Patterns

### Check if running as administrator
```powershell
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrator rights." -ForegroundColor Red
    exit 1
}
```

### Install or verify an app with winget
```powershell
$check = winget list --id "Microsoft.Git" --accept-source-agreements 2>&1 | Out-String
if ($check -match "Microsoft.Git") {
    Write-Host "Already installed"
} else {
    winget install --id "Microsoft.Git" -s winget --accept-package-agreements --accept-source-agreements
}
```

### Refresh PATH after an install
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")
```

### Stop a process safely (by PID only)
```powershell
$proc = Get-Process -Name "agency" -ErrorAction SilentlyContinue
if ($proc) { Stop-Process -Id $proc.Id -Force }
```
Never use `Stop-Process -Name`. Always use PID.

### Write a file safely (no clobber risk)
```powershell
$content | Set-Content -Path "C:\path\to\file.txt" -Encoding UTF8
```
Use `-Encoding UTF8` explicitly. Default encoding varies by PowerShell version.

### Read a JSON settings file (handles comments)
```powershell
$raw = Get-Content "C:\path\settings.json" -Raw
$lines = $raw -split "`n" | Where-Object { $_ -notmatch '^\s*//' }
$clean = ($lines -join "`n") -replace ',\s*([}\]])', '$1'
$settings = $clean | ConvertFrom-Json
```

---

## Debugging Windows Issues

When something is not working:

1. Check the exact error. Copy it verbatim. Do not paraphrase.
2. Check if the tool is in PATH: `Get-Command toolname -ErrorAction SilentlyContinue`
3. Check if admin rights are needed: run the same command in an elevated terminal.
4. Check execution policy: `Get-ExecutionPolicy -Scope CurrentUser`
5. Check if the file exists before referencing it: `Test-Path "C:\path\to\file"`

### Fix execution policy (most common first-run issue)
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### Unblock files downloaded from OneDrive or the internet
```powershell
Get-ChildItem -Path "C:\path\to\folder" -Recurse -File | Unblock-File
```

---

## Rules

**No aliases in scripts.** `gci`, `%`, `?` are fine at the command line. In scripts, use full cmdlet names.

**Error handling for critical steps.** Use `-ErrorAction Stop` and `try/catch` for steps that must succeed.

**No hardcoded credentials.** Never write passwords, tokens, or secrets into a script. Use environment variables or `Get-Credential`.

**Test destructive operations.** `Remove-Item -Recurse`, `Stop-Process`, registry writes: always verify with `-WhatIf` first.

---

*PowerShell and Windows skill. Part of AI Workbench.*
