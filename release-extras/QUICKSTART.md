# AI Maker v3.0.11 — Quickstart (for anyone)

**TL;DR:** Download zip → extract → right-click `install.bat` as admin → done.

## Install

1. Download: <https://github.com/marcusash_microsoft/ai-maker/releases/download/v3.0.11/ai-maker-v3.0.11.zip>
2. Right-click the zip → **Extract All**.
3. Right-click `install.bat` → **Run as administrator**.
4. Pick **1** (Blue Pill, lightweight) or **2** (Red Pill, full toolkit).
5. Wait for "INSTALL COMPLETE". An agency tray icon should appear.

## Verify (optional)

Double-click `verify.bat`. Twelve probes run in a few seconds. All green = good.

## What you get

- **Blue Pill:** 11 AI Maker skills (planning, writing, design). Lightweight workspace at `C:\GitHub\ai-workspace`.
- **Red Pill:** 22 skills — adds 11 AI Workbench technical skills (CI/CD, debugging, security review, GitHub).

Both pills register MCP servers for WorkIQ + Bluebird via the agency app.

## Switching pills

Run `install.bat` again, pick the other number. Workspace upgrades in place. Your vault is preserved.

## What's new in v3.0.11

- **Install-Skills idempotency fix.** Rerunning the installer no longer creates nested skill directories or doubles file counts. Safe to re-run repeatedly.
- Lib version: 3.0.11
- First release on `marcusash_microsoft/ai-maker` (org-canonical).

## Problems?

Open an issue: <https://github.com/marcusash_microsoft/ai-maker/issues/new>

Attach `C:\Temp\ai-maker-smoke\verify-<timestamp>.log` if you ran verify.
