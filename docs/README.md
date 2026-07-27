# AI Maker — Architecture Overview

**Purpose:** A one-command installer that moves managers and engineers onto the GitHub Copilot App with Agency as the runtime, curated AI skills, persistent vault memory, and M365 integration.

**What it installs:** Agency (Microsoft's Agentic Engineering Platform), the GitHub Copilot App, MCP servers (WorkIQ, Bluebird), 11-22 AI skills, and a workspace scaffold.

**What the agent does first:** Bootstrap protocol auto-creates two agent sessions (AI Maker + AI Workbench) on first project load.

---

## Two Paths

| Path | Skills | Git | GitHub Repo | Audience |
|------|--------|-----|-------------|----------|
| **Blue Pill** | 11 (AI Maker only) | No | No | Non-technical leaders |
| **Red Pill** | 22 (AI Maker + AI Workbench) | Yes | Private `{user}/ai-workspace` | Technical users |

---

## File Hierarchy

```
ai-maker/
├── install.bat              ← Windows batch entry point (download from release)
├── installers/
│   ├── ai-maker-lib.ps1    ← Shared library (all functions, inline templates)
│   ├── install-blue.ps1    ← Blue Pill installer
│   ├── install-red.ps1     ← Red Pill installer
│   ├── migrate.ps1         ← Legacy CLI → App migration tool
│   └── verify.ps1          ← 12-probe post-install verification
├── agents/
│   ├── ai-maker.md         ← AI Maker agent identity
│   ├── ai-workbench.md     ← AI Workbench agent identity
│   └── copilot-instructions.md ← Bootstrap protocol (auto-creates sessions)
├── skills/
│   ├── ai-maker-*/         ← 11 AI Maker skill folders
│   └── ai-workbench-*/     ← 11 AI Workbench skill folders
├── tests/
│   └── e2e-install.ps1     ← Pre-publish validation (13 structural checks)
├── docs/
│   ├── PRD.md              ← Product Requirements Document
│   └── (website source)
├── release-extras/         ← Assets bundled into releases
└── reset.bat               ← Clean uninstall
```

---

## Install Flow

1. User pastes one-liner from website (or runs `install.bat`)
2. `install-blue.ps1` (or `install-red.ps1`) downloads `ai-maker-lib.ps1` from release
3. **Phase 1: Agency Foundation** — Git, Agency CLI, MCP registration, M365 MCPs
4. **Phase 2: AI Maker Layer** — Skills download, workspace scaffold, agent identities
5. **Phase 3: Launch** — `agency gh-app` opens the Copilot App

---

## Key Design Decisions

- **Single-file distribution** — lib contains all templates inline (no external deps during install)
- **`irm | iex` compatible** — no `$PSScriptRoot` assumptions; auto-downloads deps from release
- **Verify-or-throw** — never print success without proof
- **Checksum-protected updates** — user-modified skills are never overwritten
- **Copy-first migration** — legacy data is copied, never moved or deleted

---

## Release Process

Source: `marcusash_microsoft/ai-maker` (org repo)  
Public: `marcusash/ai-maker` (personal repo — releases + Pages)

Assets per release: `install.bat`, `ai-maker-lib.ps1`, `install-blue.ps1`, `install-red.ps1`, `migrate.ps1`, `verify.ps1`, `agents.zip`, `skills.zip`

---

## Website

https://marcusash.github.io/ai-maker/

- `/` — Main landing (Blue Pill)
- `/pro/` — Red Pill landing
- `/docs/blue.html` — Blue Pill step-by-step

---

*FA. 2026-06-29. Architecture document for AI Maker v3.*
