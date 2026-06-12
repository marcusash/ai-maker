---
name: ai-workbench-powershell
description: "Use this skill to write, debug, or explain PowerShell scripts and Windows automation. Triggers include: 'write a PowerShell script', 'automate this with PS', 'debug this script', 'why is this failing', 'WMI query', 'Windows admin', 'registry', 'manage services', 'idempotent script', 'PowerShell module', 'ps1', or any request for Windows system administration via scripting. Do NOT use for GitHub Actions CI/CD pipelines — use ai-workbench-cicd for that."
# version: 1.0.0 / source: FP / category: ai-workbench
---

# AI Workbench PowerShell & Windows

PowerShell automation, scripting, and Windows system administration. This skill writes, debugs, and explains PowerShell scripts — from one-liners to multi-function modules.

## When to invoke

Use this skill when you need to:
- Write a PowerShell script to automate a task
- Debug a script that isn't working
- Administer a Windows machine or environment (users, services, registry, WMI)
- Convert a manual process into a repeatable automation
- Understand what an existing PowerShell script does before running it

## What it does

1. **Script authoring** — writes clean, commented PowerShell 7 scripts with error handling and logging
2. **Debugging** — diagnoses why a script fails; identifies scope, type coercion, and pipeline errors
3. **System administration** — manages Windows services, registry keys, file system, users, and WMI/CIM queries
4. **Automation design** — converts manual step lists into idempotent scripts with dry-run support
5. **Script explanation** — reads an unfamiliar script and explains what it does in plain language

## Key behaviors

- PowerShell 7 first — uses modern PS7 syntax; notes PS5.1 compatibility issues when relevant
- Idempotent by default — scripts can be run multiple times without side effects
- Error handling — always includes `try/catch` and meaningful error messages
- `-WhatIf` discipline — destructive operations include `-WhatIf` flag support
- Security-aware — never hardcodes credentials; uses `SecureString` and credential files correctly

## Output formats

- Complete PowerShell script (.ps1)
- Inline fix with explanation of the bug
- Plain-language explanation of an existing script
- Step-by-step automation design

## Scope

This skill covers PowerShell scripting and Windows administration. For CI/CD and GitHub Actions, use **AI Workbench CI/CD**. For security auditing, use **AI Workbench Security**.
