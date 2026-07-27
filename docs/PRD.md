# AI Maker v3 — Product Requirements Document (PRD)

**Author:** FA (Chief Architect)  
**Status:** DRAFT — Pending Marcus sign-off  
**Date:** 2026-06-28  
**Audience:** All Forge agents, Marcus Ash  
**Location:** This file lives at `docs/PRD.md` in the ai-maker repo. It is the canonical reference for all AI Maker development. Read this FIRST before touching any code.

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [Customers](#2-customers)
3. [Two Paths (Pills)](#3-two-paths-pills)
4. [Four Starting States](#4-four-starting-states)
5. [Post-Install Machine State (Definition of Done)](#5-post-install-machine-state-definition-of-done)
6. [Install Flow (Ordered Steps)](#6-install-flow-ordered-steps)
7. [Entry Point: install.bat](#7-entry-point-installbat)
8. [Agency Integration](#8-agency-integration)
9. [Skills](#9-skills)
10. [Agent Identities](#10-agent-identities)
11. [Workspace Structure](#11-workspace-structure)
12. [Post-Install Activation (Zero Friction First Use)](#12-post-install-activation-zero-friction-first-use)
13. [Verification (verify.ps1)](#13-verification-verifyps1)
14. [Protected Assets](#14-protected-assets)
15. [Idempotency Contract](#15-idempotency-contract)
16. [Migration (Legacy CLI → App)](#16-migration-legacy-cli--app)
17. [Source Code Architecture](#17-source-code-architecture)
18. [Test Architecture](#18-test-architecture)
19. [Release Process](#19-release-process)
20. [Open Issues](#20-open-issues)
21. [Release Checklist](#21-release-checklist)
22. [Glossary](#22-glossary)

---

## 1. Product Vision

### Why the GitHub Copilot App

The **GitHub Copilot App** is where GitHub's agent team is investing all its development energy. It is the most capable agentic harness Microsoft has — purpose-built for AI-driven work, not bolted onto an editor or terminal. It offers capabilities the CLI simply cannot:

- **Parallel agent sessions** — run multiple agents simultaneously, each in isolated worktrees, visible in a single "My Work" dashboard
- **Inter-agent messaging** — sessions can coordinate, delegate, and report back to each other without human relay
- **Canvases** — shared interactive surfaces where agents and humans co-edit plans, code, and artifacts in real time
- **Mobile & remote control** — start work on your desktop, review and direct it from your phone via GitHub Mobile
- **Agent Merge** — automated PR lifecycle (CI monitoring, reviewer feedback, merge) without manual babysitting
- **Session modes** — choose your autonomy level: interactive, plan-and-approve, or full autopilot
- **Persistent session state** — full audit trail of agent reasoning, decisions, and changes across sessions
- **Native GitHub integration** — issues, PRs, code review, CI, repo search — all built in, zero config

The GitHub CLI is a terminal tool. It's powerful, but it's the wrong form factor for managers, designers, and PMs who need AI help with research, writing, communication, and data analysis. Even for engineers, the App is where the platform is heading — it's the supported, actively-developed product that gets new features first.

**AI Maker exists to move people off the CLI and onto the Copilot App** — the most useful agentic harness that Microsoft is leveraging internally. It does this by:

- Installing the App via Agency in under 10 minutes (zero manual config)
- Pre-loading curated AI skills (11 creative/strategic, 11 technical)
- Wiring up M365 (email, calendar, Teams, tasks) so agents can actually DO things
- Providing persistent memory (vault) that survives across sessions
- Making first use zero-friction — everything works the moment you open a session

The product wraps the **Agency runtime** (Microsoft's Agentic Engineering Platform), supports 4 distinct user starting states plus legacy migration paths, and is designed so that a non-technical manager can go from zero to a working AI partner in one paste-and-go command.

**One-sentence pitch:** "Your AI assistant for research, writing, brainstorming, data analysis, design, and communication, in a real window, not a terminal. One agent, 11 skills, five minutes to set up."

---

## 2. Customers

**Primary audience:** People Marcus Ash supports directly — non-technical managers, PMs, designers, and technical leads at Microsoft who want AI assistance without living in a terminal.

**Two personas:**

| Persona | Pill | Technical Level | Needs |
|---------|------|-----------------|-------|
| **The Manager** | Blue | Low — knows Windows, not git | Research, writing, comms, data viz, M365 integration |
| **The Engineer** | Red | High — git, CLI, automation | Everything above + CI/CD, PowerShell, testing, security, GitHub |

**Key insight:** Both personas get the SAME Copilot App experience. The difference is what's installed underneath (skills, dev tools, GitHub backup).

---

## 3. Two Paths (Pills), Plus Bring Your Own

| | Blue Pill | Red Pill | Bring Your Own Agents |
|---|---|---|---|
| **Audience** | Non-technical managers | Technical users | Users who already have their own agent/skills repo |
| **Skills** | 11 (AI Maker) | 22 (AI Maker + AI Workbench) | None installed by AI Maker — whatever the synced repo carries |
| **GitHub account** | Not required for install | Required | Required |
| **Git** | Installed (Agency prereq) | Installed + workspace backed up | Installed |
| **GitHub Copilot App** | Installed (via `agency gh-app`) | Installed (via `agency gh-app`) | Installed |
| **Copilot CLI** | No | Yes | No |
| **Workspace backup** | Local only | Private GitHub repo `{user}/ai-workspace` | User's own repo, unmodified |
| **Cross-machine sync** | No | Yes (clone + `-SkillsOnly`) | Yes (it's just their repo) |
| **Install time** | ~5 min | ~10 min | ~5 min |
| **Agent sessions** | AI Maker only | AI Maker + AI Workbench | Whatever the synced repo defines |

**Bring Your Own Agents (§6.3)** is a third install path: same dev-tools infra as Red Pill (Git, GitHub Copilot App, WorkIQ, GitHub auth), but skips AI Maker/AI Workbench skills, agent identity files, and workspace scaffold entirely. Instead it prompts for a GitHub repo and clones it straight to `C:\GitHub\<repo-name>` — no merge, no overlay, same pattern as `pc-setup`'s repo-clone step. Whether the synced repo's own `skills/`/`.github/agents/` actually activate in the Copilot App is the repo owner's responsibility, not AI Maker's — this path installs infra only.

**Both paths share (non-negotiable):**
- GitHub Copilot App installed via `agency gh-app` (Agency mode)
- Agency runtime installed (Velopack)
- MCP servers registered (WorkIQ + Bluebird)
- M365 MCPs enabled (Teams, Outlook, Planner)
- SHELL env var set (`C:\Program Files\Git\usr\bin\sh.exe`)
- Workspace at `C:\GitHub\ai-workspace` with vault + agents
- AI Maker + AI Workbench agent identities active
- Session named "AI maker"
- All activation gates cleared (EULAs, SSO, Entra auth)
- Skills available globally across ALL sessions and worktrees

---

## 4. Install Scenarios

There are **5 scenarios** the installer must handle. The first two are fresh installs, the next two are migrations from the old CLI-based setup, and the last is an in-place upgrade.

### 4.1 Scenario 1: First-Timer → Blue Pill

**Who:** Someone who has never had AI Maker. No existing workspace, no legacy folders.  
**What they pick:** Option 1 (Blue Pill) in install.bat  
**What happens:** Full fresh install — Agency, 11 skills, local workspace, no git.  
**Detection:** No `C:\GitHub\ai-workspace`, no `C:\AIMaker`, no `C:\AIWorkbench`

### 4.2 Scenario 2: First-Timer → Red Pill

**Who:** Someone who has never had AI Maker. No existing workspace, no legacy folders.  
**What they pick:** Option 2 (Red Pill) in install.bat  
**What happens:** Full fresh install — Agency, 22 skills, git-backed workspace synced to GitHub.  
**Detection:** No `C:\GitHub\ai-workspace`, no `C:\AIMaker`, no `C:\AIWorkbench`

### 4.3 Scenario 3: Legacy Blue Pill → New Blue Pill (Migration)

**Who:** Someone who had the old CLI-based Blue Pill setup (`C:\AIMaker` folder, no git).  
**What happens:**
- Install everything fresh into `C:\GitHub\ai-workspace` (completely new path — zero collision)
- DETECT what they had: custom copilot-instructions.md, vault files, any other assets
- COPY those into the new workspace structure (`vault/maker/`, `.user.md` for modified instructions)
- NEVER touch `C:\AIMaker` — it stays intact so they can still reference old content or run CLI  
**Detection:** `C:\AIMaker` exists, no `.git` inside it  
**Key principle:** Copy-first, never move, never delete. The old setup is untouched.

### 4.4 Scenario 4: Legacy Red Pill → New Red Pill (Migration)

**Who:** Someone who had the old CLI-based Red Pill setup (`C:\AIMaker` with git, possibly `C:\AIWorkbench`).  
**What happens:**
- Install everything fresh into `C:\GitHub\ai-workspace`
- DETECT what they had: vault files, custom instructions, workbench content
- COPY vault data into new structure (`vault/maker/` from AIMaker, `vault/workbench/` from AIWorkbench)
- Approximate their old setup in the new structure (same pill, same data, new architecture)
- NEVER touch `C:\AIMaker` or `C:\AIWorkbench` — legacy stays intact  
**Detection:** `C:\AIMaker` exists with `.git`, or `C:\AIWorkbench` exists  
**Key principle:** Same as Scenario 3 — copy-first, preserve legacy, new path for new install.

### 4.5 Scenario 5: New Blue Pill → New Red Pill (Upgrade)

**Who:** Someone who already ran the new Blue Pill installer (has `C:\GitHub\ai-workspace` with manifest saying "blue"). Now wants Red.  
**What happens:**
- Add Copilot CLI extension + GitHub authentication (via the App)
- Add AI Workbench agent + 11 AI Workbench skills (now 22 total)
- Git init the workspace, create private repo, push
- Update manifest (pill: "red", upgraded_from: "blue")
- Preserve ALL existing vault data and user customizations  
**Detection:** `C:\GitHub\ai-workspace` exists, `.ai-maker-manifest.json` says `pill: "blue"`, user picks Red

### 4.6 Idempotent Rerun (applies to all scenarios)

Running the installer again on an already-working setup MUST:
- Verify Agency + MCP registration (repair if broken)
- Update skills if source is newer (skip user-modified skills)
- Verify SHELL env var (repair if missing)
- NOT delete any user files
- NOT create duplicates
- Exit 0

### 4.7 Detection Logic

The lib function `Get-InstallScenario()` evaluates filesystem state to determine which scenario applies:
- Does `C:\GitHub\ai-workspace\` exist?
- Is `.ai-maker-manifest.json` present and valid?
- Is `.git\` present in the workspace?
- Does `C:\AIMaker\` exist? With or without `.git`?
- Does `C:\AIWorkbench\` exist?
- What pill does the manifest say vs what the user requested?

### 4.8 Migration Principles (Scenarios 3 & 4)

These are non-negotiable:

1. **Copy-first** — vault data and instructions are COPIED to the new workspace, never moved
2. **Legacy untouched** — `C:\AIMaker` and `C:\AIWorkbench` are NEVER modified or deleted
3. **New path** — the new install goes to `C:\GitHub\ai-workspace` specifically to avoid collisions
4. **Detect modifications** — SHA-256 of copilot-instructions.md vs known stock; user-modified versions preserved as `.user.md`
5. **User confirms** — migration shows a plan of what will be copied before executing (or use `-Force` to skip)
6. **Additional files preserved** — any non-standard files found in legacy are copied to `workspace/legacy/` subfolder

---

## 5. Post-Install Machine State (Definition of Done)

After a successful install, the following MUST ALL be true. This is the contract.

### 5.1 Both Pills (Assertions 1-13)

| # | Assertion | Verification Command |
|---|---|---|
| 1 | Copilot App installed via Agency mode | `agency gh-app` exits 0; App launches |
| 2 | Agency runtime installed | `agency.exe` locatable (PATH → `$env:APPDATA\agency\*\agency.exe` glob) |
| 3 | MCP servers registered | `(Get-Content ~/.copilot/m-mcp-servers.json \| ConvertFrom-Json).workiq` exists |
| 4 | Bluebird MCP registered | `(Get-Content ~/.copilot/m-mcp-servers.json \| ConvertFrom-Json).bluebird` exists |
| 5 | SHELL env var set (User scope) | `[Environment]::GetEnvironmentVariable('SHELL','User')` = `C:\Program Files\Git\usr\bin\sh.exe` |
| 6 | Git installed | `git --version` exits 0 (required by Agency) |
| 7 | Workspace exists | `Test-Path C:\GitHub\ai-workspace` = True |
| 8 | Workspace scaffold complete | Blue: `.github/agents/ai-maker.md`, `.github/copilot-instructions.md`, `vault/maker/`. Red: adds `ai-workbench.md`, `vault/workbench/` |
| 9 | Skills installed (11 for Blue, 22 for Red) | `(Get-ChildItem ~/.copilot/skills/ai-maker-*).Count` = 11 |
| 10 | Manifest written | `C:\GitHub\ai-workspace\.ai-maker-manifest.json` valid JSON, pill = correct |
| 11 | Identity + routing in copilot-instructions.md | File contains AI Maker persona, Agent Routing section, session rename directive |
| 12 | Skills available globally | Skills in `~/.copilot/skills/` load in ALL sessions/worktrees across the App |
| 13 | All activation gates cleared | EULAs accepted, Entra SSO validated, MCP servers responsive |

> **⚠️ CRITICAL REQUIREMENT (Marcus-directed):**
> "Installed" is NOT "done." The installer must ensure skills are **ready to use**
> across ANY session or worktree the user spawns in the Copilot App.
> - EULAs that need acceptance → prompted and completed during install
> - SSO/Entra auth → validated during install (not deferred to first use)
> - MCP servers → confirmed responsive (not just registered in JSON)
> - Skills in `~/.copilot/skills/` → globally available (not project-scoped)

### 5.2 Red Pill Only (Assertions 14-19, in addition to above)

| # | Assertion | Verification Command |
|---|---|---|
| 14 | Copilot CLI extension available | App can invoke `gh copilot` within sessions |
| 15 | GitHub authenticated | App has valid GitHub token (OAuth via App login) |
| 16 | 22 skills total | `(Get-ChildItem ~/.copilot/skills/ai-workbench-*).Count` = 11 (+ 11 maker) |
| 17 | AI Workbench agent exists | `Test-Path C:\GitHub\ai-workspace\.github\agents\ai-workbench.md` = True |
| 18 | Git repo initialized | `Test-Path C:\GitHub\ai-workspace\.git` = True |
| 19 | Remote set + pushed | `git -C C:\GitHub\ai-workspace remote get-url origin` matches `https://github.com/{user}/ai-workspace.git` |

### 5.3 Migration (Legacy → New, Scenarios 3 & 4)

All of §5.1 (+ §5.2 if migrating to Red), PLUS:
- Legacy `C:\AIMaker` and/or `C:\AIWorkbench` are COMPLETELY UNTOUCHED (no files modified, moved, or deleted)
- Vault data copied: `C:\AIMaker\vault\*` → `C:\GitHub\ai-workspace\vault\maker\`
- Vault data copied: `C:\AIWorkbench\vault\*` → `C:\GitHub\ai-workspace\vault\workbench\` (if existed)
- User-modified `copilot-instructions.md` preserved as `.github/copilot-instructions.user.md`
- Any additional user files found in legacy → copied to `workspace/legacy/` subfolder
- Manifest includes: `migrated_from: "cli-v2"`, `legacy.migrated_maker_vault: true/false`

### 5.4 Upgrade (New Blue → New Red, Scenario 5)

All of §5.1 + §5.2, PLUS:
- Existing vault data preserved (zero files deleted from `vault/`)
- User-modified `copilot-instructions.md` saved as `.github/copilot-instructions.user.md`
- Manifest updated: `pill: "red"`, `upgraded_from: "blue"`, `upgraded_at: timestamp`

---

## 6. Install Flow (Ordered Steps)

> **⚠️ ARCHITECTURAL MANDATE (Marcus-directed, non-negotiable):**
> Agency IS the install path. The Copilot App is installed VIA Agency (`agency gh-app`),
> NOT via `winget install GitHub.CopilotApp`. Agency is the foundation — everything else
> (skills, workspace, identity) layers on top of a working Agency install.

### 6.1 Blue Pill

```
PHASE 1: AGENCY FOUNDATION
  1. Prerequisites check (Windows 10+, winget, 3GB disk)
  2. Install PowerShell 7 (if missing) — via winget
  3. Install Git (winget Git.Git — required: Agency MCP servers shell out to git)
  4. Set SHELL env var → C:\Program Files\Git\usr\bin\sh.exe (User scope)
  5. Install Agency CLI: irm aka.ms/InstallTool.ps1 | iex; agency
  6. Probe for agency.exe (PATH → AppData Velopack glob → error if missing)
  7. Register MCP servers (write workiq + bluebird entries to m-mcp-servers.json)
  8. Verify MCP registration (read m-mcp-servers.json, THROW if workiq or bluebird missing)
  9. Enable M365 MCPs: agency config set --global --mcp teams; --mcp outlook; --mcp planner

PHASE 2: AI MAKER LAYER
  10. Download + install 11 AI Maker skills → ~/.copilot/skills/
  11. Create workspace scaffold (C:\GitHub\ai-workspace)
  12. Write copilot-instructions.md (AI Maker identity + Agent Routing + session rename)
  13. Write .github/agents/ai-maker.md (Blue Pill = AI maker agent ONLY, per §10.3)
  14. Write manifest (.ai-maker-manifest.json, pill: "blue")

PHASE 3: LAUNCH
  15. agency gh-app — launches Copilot App with Agency mode (picks up all config on first launch)
  16. Print success + next steps ("Add C:\GitHub\ai-workspace as a project in the App")
```

### 6.2 Red Pill

```
PHASE 1: AGENCY + DEVELOPER TOOLS
  1. Prerequisites check (Windows 10+, winget, 3GB disk)
  2. Install PowerShell 7 (if missing) — via winget
  3. Install Git (winget Git.Git — required: Agency MCP servers shell out to git)
  4. Set SHELL env var → C:\Program Files\Git\usr\bin\sh.exe (User scope)
  5. Install Agency CLI: irm aka.ms/InstallTool.ps1 | iex; agency
  6. Probe for agency.exe (PATH → AppData Velopack glob → error if missing)
  7. Register MCP servers (write workiq + bluebird entries to m-mcp-servers.json)
  8. Verify MCP registration (THROW if missing)
  9. Enable M365 MCPs: agency config set --global --mcp teams/outlook/planner

PHASE 2: AI MAKER LAYER
  10. Download + install 22 skills → ~/.copilot/skills/
  11. Create workspace scaffold (C:\GitHub\ai-workspace)
  12. Write copilot-instructions.md (both agent identities + routing)
  13. Write .github/agents/ai-maker.md + .github/agents/ai-workbench.md
  14. Git init → git config user → git add → git commit
  15. GitHub authentication (App's built-in OAuth flow — browser popup)
  16. Create private repo ai-workspace → git remote add → git push
  17. Write manifest (pill: "red")

PHASE 3: LAUNCH
  18. agency gh-app — launches Copilot App with Agency mode (fully configured on first launch)
  19. Print success + next steps
```

**NOTE:** Git is installed in Phase 1 for BOTH pills (Agency requires it).
The difference for Red Pill is GitHub authentication + git-backed workspace + Workbench agent.

### 6.3 Bring Your Own Agents

```
PHASE 1: DEVELOPER TOOLS (same as Red Pill Phase 1, steps 1-4 — no Agency, matches shipped reality)
  1. Prerequisites check (Windows 10+, winget, 3GB disk)
  2. Install Git (winget Git.Git)
  3. Set SHELL env var
  4. Install GitHub Copilot App (winget GitHub.CopilotApp) + WorkIQ plugin

PHASE 2: GITHUB AUTH (needed to clone the user's own repo)
  5. Install GitHub CLI if missing, gh auth login

PHASE 3: SYNC USER'S OWN AGENT REPO (no AI Maker/Workbench install)
  6. Prompt for a GitHub repo (org/repo or URL), validate via `gh repo view`
  7. Clone to C:\GitHub\<repo-name> — skip-and-pull if it already exists
     AND origin matches; throw on collision with a different repo
  8. Configure git user.name/user.email in the synced repo
  9. Write a BYO breadcrumb (~/.copilot/ai-maker/byo-manifest.json) —
     NOT a full AI Maker manifest, since no skills/agents were installed

PHASE 4: LAUNCH
  10. Launch Copilot App pointed at the synced repo directory (not ai-workspace)
```

**NOTE:** No skills.zip, agents.zip, or `New-WorkspaceScaffold` call — this path installs infra only. Whether the synced repo's `.github/agents` and `skills/` actually load is on the repo owner, not this installer.

---

### 6.4 Migration (Scenarios 3 & 4)

```
PHASE 1: AGENCY FOUNDATION (same as Blue/Red steps 1-11)

PHASE 2: DEVELOPER TOOLS (Red migration only — same as §6.2 steps 12-15)

PHASE 3: AI MAKER LAYER (same as §6.1 or §6.2 steps 12-17 / 16-23)

PHASE 4: MIGRATE LEGACY DATA
  - Detect legacy paths (C:\AIMaker, C:\AIWorkbench)
  - Inventory: scan vault dirs, detect modified instructions, count files
  - Show migration plan to user (what will be COPIED — confirm or -Force)
  - Copy vault data → vault/maker/ and vault/workbench/
  - If copilot-instructions.md modified → save as .user.md in new workspace
  - Copy additional user files → workspace/legacy/ subfolder
  - Update manifest with migrated_from: "cli-v2"
  - (Optional -MarkLegacy): write .ai-maker-migrated.json breadcrumb in old folder
  - NEVER modify or delete legacy directories
```

### 6.5 Upgrade (Scenario 5: Blue → Red)

```
  1. Verify existing Blue install is healthy (Agency, skills, workspace)
  2. GitHub authentication (App's built-in OAuth flow — browser popup)
  3. Add AI Workbench agent (.github/agents/ai-workbench.md) + vault/workbench/
  4. Install 11 additional AI Workbench skills → ~/.copilot/skills/
  5. Git init workspace → git config → git add → git commit
  6. Create private repo ai-workspace → git remote add → git push
  7. Install Copilot CLI extension (available in App sessions)
  8. Update manifest (pill: "red", upgraded_from: "blue", upgraded_at: timestamp)
  9. Preserve ALL vault data and user customizations (zero destructive changes)
```

---

## 7. Entry Point: install.bat

**The one-liner (canonical install method — shown on website):**
```batch
curl.exe -sSL -o %TEMP%\install.bat https://github.com/marcusash/ai-maker/releases/latest/download/install.bat & %TEMP%\install.bat
```

> **CRITICAL:** Uses `/releases/latest/download/` (not a hardcoded version tag).
> GitHub automatically resolves `latest` to the most recent release. This means:
> - The website NEVER needs updating when a new version ships
> - No version mismatch between what the website says and what's actually latest
> - The install.bat inside the release ALSO uses `latest` for downloading .ps1 files
>
> **Requirement for install.bat:** When downloading `ai-maker-lib.ps1` and the pill installers,
> use the `latest` redirect URL pattern — NOT a hardcoded `v3.0.XX` tag.

**What install.bat does:**
1. Unblock all downloaded `.ps1` files (`Unblock-File`)
2. Check if `pwsh` (PowerShell 7) exists; install via `winget` if missing
3. Show menu: `[1] Blue Pill | [2] Red Pill | [3] Bring Your Own Agents`
4. Download `ai-maker-lib.ps1` from release assets (curl.exe --silent)
5. Download chosen installer (`install-blue.ps1` or `install-red.ps1`)
6. Route to corresponding .ps1 via `pwsh -ExecutionPolicy Bypass -File`

**install.bat code requirements:**
- `--silent` on ALL internal curl.exe calls (no progress table)
- No `>nul` on `move` commands (errors must be visible)
- `if %ERRORLEVEL%` check after EACH `move` (catch file save failures)
- Echo `[OK]` after each successful download step (user sees progress)
- CRLF line endings throughout (cmd.exe requirement)
- UTF-8 encoding

---

## 8. Agency Integration

> **⚠️ Agency is the FOUNDATION of the install, not an add-on.**
> The Copilot App is installed and launched VIA `agency gh-app`.
> Without Agency, the Copilot App has no M365 access, no MCP servers, no WorkIQ.
> This is Marcus-directed and non-negotiable.

### 8.1 What Agency IS

Agency is **Microsoft's Agentic Engineering Platform** — built on GitHub Copilot CLI and Claude Code. It provides:

- **The engine underneath the GitHub Copilot App** (Agency mode)
- **1P MCP tool servers:** WorkIQ, Bluebird, ADO, ESChat, Outlook, Teams, SharePoint, Kusto, S360, Calendar, CloudBuild
- **MCP server host** — registers servers that the Copilot App discovers via `m-mcp-servers.json`
- **Microsoft Entra auth handler** — signs in using Microsoft Identity
- **Same UX as CLI** — `\>copilot` and `\>agency copilot` are identical interfaces

### 8.2 Install Sequence (Phase 1 of every install)

```powershell
# 1. Install Agency CLI
Invoke-RestMethod "https://aka.ms/InstallTool.ps1" | Invoke-Expression
agency  # first-run setup, Entra auth

# 2. Probe for agency.exe (Velopack doesn't add to PATH)
$agency = Get-Command agency.exe -ErrorAction SilentlyContinue
if (-not $agency) {
    $agency = Get-ChildItem "$env:APPDATA\agency\*\agency.exe" |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $agency) { throw "agency.exe not found after install" }

# 3. Register MCP servers (direct JSON write — NOT a CLI command)
#    Register-AgencyMcpServers reads/seeds m-mcp-servers.json, then merges:
#    - Seeds with defaults (filesystem + playwright) if file missing
#    - Merges workiq: { command: <agency.exe path>, args: ["mcp","workiq"], tools: ["*"] }
#    - Merges bluebird: { command: <agency.exe path>, args: ["mcp","bluebird"], tools: ["*"] }
#    - Writes UTF-8 no BOM
Register-AgencyMcpServers

# 4. Verify registration (THROW if missing — never silent-lie)
$mcpFile = "$env:USERPROFILE\.copilot\m-mcp-servers.json"
$config = Get-Content $mcpFile | ConvertFrom-Json
if (-not $config.workiq) { throw "MCP registration failed: workiq missing" }
if (-not $config.bluebird) { throw "MCP registration failed: bluebird missing" }

# 5. Enable M365 MCPs (each individually, warn on non-zero exit)
foreach ($mcp in @('teams', 'outlook', 'planner')) {
    agency config set --global --mcp $mcp
}

# 6. LAST — Launch Copilot App (picks up all config on first launch)
agency gh-app
```

> **NOTE:** MCP registration does NOT use `agency mcp register` as a CLI command.
> The lib function `Register-AgencyMcpServers` directly constructs and writes the JSON.
> It uses `agency.exe` as the MCP server COMMAND (what the App spawns to start the server),
> not as a registration CLI. The App reads `m-mcp-servers.json` on startup to discover servers.

### 8.3 Prerequisites for Agency

| Prereq | Why | When to install |
|--------|-----|-----------------|
| Git | Agency MCP servers shell out to git on startup | Before Agency install |
| SHELL env var | Agency MCP Settings canvas does `process.env.SHELL \|\| "/bin/sh"` — without it, falls back to non-existent `/bin/sh` on Windows | Before Agency install |

### 8.4 What the User Gets from Agency

After install, the user has **7 MCP servers** available across two registration mechanisms:

| MCP Server | What it does | Registration mechanism |
|-----------|-------------|----------------------|
| **workiq** | M365 bridge — email, calendar, Teams messages, tasks, search | `m-mcp-servers.json` (our installer writes this) |
| **bluebird** | Supporting service for Agency runtime | `m-mcp-servers.json` (our installer writes this) |
| **filesystem** | Local file read/write for the Copilot App | `m-mcp-servers.json` (seeded as default) |
| **playwright** | Browser automation / web interaction | `m-mcp-servers.json` (seeded as default) |
| **teams** | Direct Teams read/write (send messages, read channels) | Agency-native (`agency config set --global --mcp teams`) |
| **outlook** | Direct Outlook read/write (send email, read inbox) | Agency-native (`agency config set --global --mcp outlook`) |
| **planner** | Microsoft Planner task management | Agency-native (`agency config set --global --mcp planner`) |

Plus:
- **Agency MCP Settings canvas:** side-panel extension in the App for configuring MCP servers
- **Entra auth:** automatic Microsoft identity — no manual OAuth dance

**Key distinction:** workiq and bluebird are registered by our installer writing JSON directly. teams, outlook, and planner are enabled through Agency's own config system (`agency config set --global --mcp <name>`). Both are required — workiq provides the M365 "skills" layer, while the individual teams/outlook/planner MCPs provide direct API access.

### 8.5 MCP Server Config Format

There are two config surfaces:

**Surface 1: `~/.copilot/m-mcp-servers.json`** (Copilot App reads on startup)

```json
{
  "servers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "C:\\Users\\{user}"],
      "tools": ["*"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"],
      "tools": ["*"]
    },
    "workiq": {
      "command": "C:\\Users\\{user}\\AppData\\Roaming\\agency\\{version}\\agency.exe",
      "args": ["mcp", "workiq"],
      "tools": ["*"]
    },
    "bluebird": {
      "command": "C:\\Users\\{user}\\AppData\\Roaming\\agency\\{version}\\agency.exe",
      "args": ["mcp", "bluebird"],
      "tools": ["*"]
    }
  }
}
```

> Our installer writes workiq + bluebird. If the file doesn't exist, it seeds filesystem + playwright as defaults first.
> Wrapped in a `"servers"` object. Existing user entries are never overwritten (idempotent merge).

**Surface 2: Agency-native config** (Agency's own settings, NOT in m-mcp-servers.json)

```powershell
agency config set --global --mcp teams
agency config set --global --mcp outlook
agency config set --global --mcp planner
```

> These enable Agency's built-in M365 MCP integrations. Without this step, the agent has no
> `send_teams_message` / `send_email` / `planner` tools even when workiq is registered.
> Each is enabled individually; non-zero exit triggers a warning (non-fatal).

---

## 9. Skills

### 9.1 Install Location

**Canonical path:** `$env:USERPROFILE\.copilot\skills\`

This is the App-wide skill directory. Skills installed here are **globally available** across:
- The `ai-workspace` project session
- Any OTHER project the user adds to the Copilot App
- Any worktree session spawned from any project
- New sessions created after install

Each skill is a folder containing a `SKILL.md` manifest + implementation files.

### 9.2 AI Maker Skills (11) — Both Pills

| Skill | Domain | What it does |
|-------|--------|--------------|
| ai-maker-brainstorming | Ideation | Structured ideation, red-teaming, pre-mortems, SCAMPER |
| ai-maker-canvas | Visual artifacts | HTML dashboards, visual trackers, interactive reports |
| ai-maker-code | Architecture | Architecture decisions, light code review (NOT day-to-day coding) |
| ai-maker-data | Analytics | Metrics interpretation, dashboard creation, data synthesis |
| ai-maker-design | Design | HTML artifact creation, visual design, brand compliance review |
| ai-maker-ops | Operations | Communications (email, memos), sprint planning, status updates |
| ai-maker-quality | QA Planning | Testing strategy, QA plans, acceptance criteria definition |
| ai-maker-research | Business Research | Evidence-first competitive analysis, vendor evaluation |
| ai-maker-user-research | User Research | User interviews, personas, research synthesis |
| ai-maker-vault | Memory | Save/recall context across sessions, knowledge management |
| ai-maker-workiq | M365 Integration | Email, calendar, Teams, tasks — powered by Agency WorkIQ MCP |

### 9.3 AI Workbench Skills (11) — Red Pill Only

| Skill | Domain | What it does |
|-------|--------|--------------|
| ai-workbench-cicd | CI/CD | GitHub Actions workflows, pipeline debugging, release design |
| ai-workbench-data | Data Engineering | Metrics pipelines, dashboard creation, data tooling |
| ai-workbench-debugging | Diagnostics | Performance profiling, error tracing, diagnostics |
| ai-workbench-design-audit | UI Review | HTML/UI quality review, visual audit, accessibility |
| ai-workbench-github | GitHub | Repos, branches, PRs, releases, GitHub Pages |
| ai-workbench-powershell | Scripting | PowerShell scripting, Windows automation, system admin |
| ai-workbench-prompt-engineering | Skill Authoring | SKILL.md creation, system prompt design, eval design |
| ai-workbench-researcher | Technical Research | Deep technical research, API docs, repo analysis |
| ai-workbench-security | Security | Credential audits, secrets scanning, workflow hardening |
| ai-workbench-testing | Testing | Pester, Playwright, Vitest, pytest, test coverage |
| ai-workbench-vision | Document Processing | OCR, PDF extraction, image processing |

### 9.4 Skill Source During Install

- **If `-SkillsSource` param provided:** use that path
- **Else if `skills/` folder exists locally:** use it (development mode)
- **Else:** download `skills.zip` from release assets, extract to temp, install from there

### 9.5 User-Modified Skill Protection

When updating skills on rerun:
1. Compute SHA-256 of each skill's `SKILL.md`
2. Compare against checksum stored in manifest
3. If different → user modified it → SKIP (do not overwrite)
4. If same → safe to update from source

---

## 10. Agent Identities

### 10.1 AI Maker (Both Pills)

- **Role:** Creative strategist for non-technical leaders
- **Tone:** Clear, confident, concise. Lead with answer, support with evidence.
- **Persona:** The sharp chief of staff who always has research ready, draft prepared, red-team critique loaded.
- **Domain:** Creative, strategic, operational work
- **Vault:** `vault/maker/` — decisions, style guides, research findings, templates
- **Routing:** If user asks technical → "That's Workbench territory"

### 10.2 AI Workbench (Red Pill only)

- **Role:** Hands-on technical partner for engineers
- **Tone:** Direct, precise, minimal. Show the code, explain only non-obvious parts.
- **Persona:** The senior SRE/DevOps engineer with the script half-written before you finish explaining.
- **Domain:** All technical and engineering work
- **Vault:** `vault/workbench/` — scripts, configs, CI/CD patterns, debugging notes
- **Routing:** If user asks strategic/creative → "That's Maker territory"

### 10.3 Bootstrap Protocol (copilot-instructions.md)

When the Copilot App opens the `ai-workspace` project for the first time:
- **Blue Pill:** Create **AI maker** session → loads `ai-maker.md` identity → renames session to "AI maker"
- **Red Pill:** Create **AI maker** session + **AI workbench** session → both agents available

### 10.4 Session Rename Directive

`copilot-instructions.md` contains: "When a session begins, rename it to 'AI maker' and then briefly acknowledge you're AI maker..."

This ensures the session in the App sidebar shows as "AI maker" (sentence case — matches the App's display convention).

> **IMPORTANT:** It's "AI maker" (lowercase m) everywhere in the App UI — session names,
> agent references in instructions, sidebar labels. Sentence case is the App's convention.
> "AI Maker" with capital M is ONLY used as the product name in documentation/website headings.

### 10.5 Agent Routing Section (in copilot-instructions.md)

```markdown
## Agent Routing

By default you operate as AI Maker (creative/strategic). When the user selects
the AI Workbench agent, follow its instructions — it handles coding, automation,
CI/CD, and technical work. Both agents share this workspace.
```

---

## 11. Workspace Structure

```
C:\GitHub\ai-workspace/
├── .github/
│   ├── agents/
│   │   ├── ai-maker.md              (ALWAYS — full AI Maker identity)
│   │   └── ai-workbench.md          (ALWAYS — full AI Workbench identity)
│   └── copilot-instructions.md      (bootstrap protocol + identity + routing)
├── vault/
│   ├── maker/                        (AI Maker persistent memory)
│   │   └── (user files — decisions, research, templates)
│   └── workbench/                    (AI Workbench persistent memory)
│       └── (user files — scripts, configs, patterns)
├── .ai-maker-manifest.json           (install state record — see §11.1)
├── .gitignore                        (secrets, .env, node_modules, etc.)
└── .git/                             (Red Pill only — synced to GitHub)
```

### 11.1 Manifest Schema

```json
{
  "schema": 1,
  "installer_version": "3.0.12",
  "pill": "blue" | "red",
  "installed_at": "2026-06-28T...",
  "upgraded_from": null | "blue",
  "upgraded_at": null | "2026-06-28T...",
  "skills": {
    "managed": [
      {
        "id": "ai-maker-brainstorming",
        "version": "1.0.0",
        "checksum": "sha256:...",
        "installed": "2026-06-28T..."
      }
    ]
  },
  "components": {
    "copilot_app": true,
    "agency": true,
    "git": true,
    "gh": false,
    "copilot_cli": false
  },
  "legacy": {
    "migrated_maker_vault": false,
    "migrated_workbench_vault": false,
    "migrated_from": null
  }
}
```

---

## 12. Post-Install Activation (Zero Friction First Use)

> **Requirement (Marcus-directed):** When the user opens their first session after install,
> EVERYTHING works. No "accept EULA" popups, no "sign in to continue" prompts,
> no "skill unavailable" errors. The install process handles ALL activation gates.

### 12.1 Activation Gates

| Gate | What | How installer clears it | Current Status |
|------|------|------------------------|----------------|
| Entra SSO | Microsoft identity for M365 access | `agency` first-run handles Entra login (browser popup) | ✅ Handled by Agency (interactive) |
| WorkIQ EULA | Terms for M365 data access | Prompted inside Agency app on first launch | ⚠️ GAP — no installer code pre-clears this |
| MCP server readiness | WorkIQ + Bluebird responding | Post-registration health check | ⚠️ GAP — only JSON structure verified, no liveness check exists |
| Teams/Outlook/Planner | M365 MCP activation | `agency config set --global --mcp {each}` | ✅ Handled in install Phase 1 |
| Copilot App auth | GitHub device auth | `agency gh-app` handles this | ✅ Handled by Agency (interactive) |
| GitHub auth (Red only) | GitHub OAuth for workspace backup | App's built-in OAuth flow (browser popup) | ✅ Handled interactively |
| SHELL env var | Agency MCP Settings canvas | Set before Agency install | ✅ Handled in install Phase 1 |

**Reality check (from FP, 2026-06-28):**
- The install IS interactive — it delegates auth to Agency/GitHub which pops browser windows
- It's "one browser popup during install, then zero prompts after"
- True zero-prompt first-session requires either:
  1. A post-launch verification step that waits for Agency to complete Entra auth and confirms token validity
  2. An `agency auth login` pre-flight command (if Agency exposes one — currently unknown)
  3. Acceptance that install includes interactive browser auth steps

**Known gaps requiring P1 resolution:**
1. **No MCP liveness check.** v3.0.10 only verifies JSON structure (keys present), not that servers respond. A true check would spawn the MCP process and verify JSON-RPC `initialize` response. No `agency mcp health` command exists.
2. **WorkIQ EULA/consent** may appear on first Copilot App session if not pre-cleared by Agency during install.

### 12.2 Global Skill Availability

Skills installed to `~/.copilot/skills/` are **global** — they load in:
- The `ai-workspace` project session
- Any OTHER project the user adds to the Copilot App
- Any worktree session spawned from any project
- New sessions created after install
- Sessions on the SAME machine (not cross-machine unless Red Pill + clone)

This is by design: `~/.copilot/skills/` is the App-wide skill directory, not project-scoped.

---

## 13. Verification (verify.ps1)

**Location:** Released as `verify.ps1` asset in every release.

**12 probes that confirm post-install state:**

| # | Probe | What it checks |
|---|-------|----------------|
| 1 | Pill detected | Workspace present, manifest readable |
| 2 | Workspace structure complete | All required dirs and files exist |
| 3 | copilot-instructions.md pill marker | Correct pill identity in file |
| 4 | Skill count matches pill | Blue: 11 maker skills; Red: 22 total |
| 5 | No nested skill directories | Idempotency — no double-install artifacts |
| 6 | Agent identity files present | ai-maker.md + ai-workbench.md in .github/agents/ |
| 7 | SHELL env var | Set to `C:\Program Files\Git\usr\bin\sh.exe` (User scope) |
| 8 | agency.exe locatable | PATH or AppData Velopack glob |
| 9 | m-mcp-servers.json | Has workiq + bluebird keys (not just file exists — keys exist) |
| 10 | Hostname + machine type | Laptop vs CloudPC captured |
| 11 | APPDATA not OneDrive-backed | Cloud PC quirk — OneDrive-backed APPDATA breaks Agency |
| 12 | Lib version matches expected | `$script:AIMakerConfig.Version` = release tag |

**Additional probes needed (from §12 activation requirement):**
| 13 | WorkIQ MCP responds | Health check call, not just JSON registration |
| 14 | Entra token valid | Token not expired |
| 15 | Skills directory readable | Expected count, all SKILL.md files present |

---

## 14. Protected Assets (NEVER Overwrite)

These files are user data. The installer MUST NOT delete or overwrite them:

| Asset | Detection | What to do instead |
|-------|-----------|-------------------|
| `vault/maker/*` | Always protected | Never touch |
| `vault/workbench/*` | Always protected | Never touch |
| `copilot-instructions.md` (user-modified) | SHA-256 vs stock template differs | Save as `.user.md`, write stock |
| User-modified skill SKILL.md | Checksum in manifest differs from installed | Skip that skill |
| `.ai-maker-manifest.json` | Always protected | Update fields, never delete |
| Any file in workspace not created by installer | Not in manifest | Never touch |

---

## 15. Idempotency Contract

Running the same installer again MUST:
- ✅ Exit 0 (success)
- ✅ Update skills if source is newer (and user hasn't modified them)
- ✅ Verify Agency + MCP registration (repair if broken)
- ✅ Verify SHELL env var (repair if missing)
- ❌ NOT delete any user files
- ❌ NOT overwrite user-modified skill files
- ❌ NOT create duplicate entries in `m-mcp-servers.json`
- ❌ NOT re-create workspace scaffold if it exists
- ❌ NOT re-init git (Red) if already initialized
- ❌ NOT re-create GitHub repo if it exists

**Philosophy:** "Verify or throw" — never print success without proof. If something should exist and doesn't, repair it. If something is broken, throw hard with a clear error message.

---

## 16. Migration (Legacy CLI → App)

### 16.1 What's Being Migrated

Users moving from the old CLI-based setup:
- `C:\AIMaker\` → was the Blue Pill CLI workspace
- `C:\AIWorkbench\` → was the Red Pill CLI workspace (had git)
- `C:\GitHub\pc-setup\` → was the repo-backed setup

### 16.2 Migration Principles

1. **Copy-first** — never move or delete legacy files
2. **Preserve user data** — vault contents are sacred
3. **Detect modification** — SHA-256 copilot-instructions.md against known stock
4. **Non-destructive** — legacy directories remain after migration
5. **Confirm before executing** — show migration plan, user confirms (or `-Force`)

### 16.3 Migration Steps (migrate.ps1)

```
1. Detect scenario (M1-M4)
2. Inventory: scan vault dirs, detect modifications, count files
3. Show migration plan (what will be COPIED, INSTALLED, NOT CHANGED)
4. User confirms (or -Force skips)
5. Install Copilot App + Agency (same Phase 1 as fresh install)
6. Install skills (11 or 22 based on detected pill)
7. Create workspace scaffold
8. Copy vault data:
   - C:\AIMaker\vault → C:\GitHub\ai-workspace\vault\maker
   - C:\AIWorkbench\vault → C:\GitHub\ai-workspace\vault\workbench
9. If copilot-instructions modified: save as .user.md
10. Write manifest with migrated_from: "cli-v2"
11. If Red: git init + repo + push
12. Optionally mark legacy (-MarkLegacy writes .ai-maker-migrated.json to old dir)
```

---

## 17. Source Code Architecture

### 17.1 Repository: `marcusash_microsoft/ai-maker`

**Public mirror:** `marcusash/ai-maker` (personal GitHub — releases + Pages site)

```
ai-maker/
├── install.bat              ← Entry point (Windows batch)
├── installers/
│   ├── ai-maker-lib.ps1    ← Shared library (1000+ lines, all functions)
│   ├── install-blue.ps1    ← Blue Pill installer
│   ├── install-red.ps1     ← Red Pill installer
│   ├── install-byo.ps1     ← Bring Your Own Agents installer
│   └── migrate.ps1         ← Legacy migration tool
├── agents/
│   ├── ai-maker.md         ← AI Maker agent identity
│   └── ai-workbench.md     ← AI Workbench agent identity
├── skills/
│   ├── ai-maker-*/         ← 11 AI Maker skill folders
│   └── ai-workbench-*/     ← 11 AI Workbench skill folders
├── tests/
│   └── contract/           ← Installer regression harness (see §18)
├── docs/
│   ├── PRD.md              ← THIS FILE
│   └── (website source)
├── release-extras/         ← Assets bundled into releases
├── reset.bat               ← Clean uninstall
└── package.json            ← Node tooling (if any)
```

### 17.2 Library Architecture (ai-maker-lib.ps1)

The lib is the core — all installers dot-source it. ~1000+ lines organized into sections:

| Section | Functions | Purpose |
|---------|-----------|---------|
| §1 Config | `$script:AIMakerConfig` | All paths, counts, version, URLs |
| §2 Transaction Log | `Initialize-TxLog`, `Write-TxEntry`, `Invoke-TxOp`, `Invoke-Rollback` | Durable operation logging, best-effort rollback |
| §3 Manifest | `New-AIMakerManifest`, `Write-AIMakerManifest`, `Read-AIMakerManifest`, `Test-AIMakerManifest` | Install state persistence |
| §4 Detection | `Get-InstallScenario` | 12-scenario state machine (see §4) |
| §5 Scaffold | `New-WorkspaceScaffold` | Creates workspace directory structure |
| §6 Skills | `Install-Skills`, `Get-SkillChecksum` | Copy skills to ~/.copilot/skills/, SHA-256 for change detection |
| §6b Agency | `Register-AgencyMcpServers`, `Invoke-AgencyGhApp` | MCP registration, App launch |
| §7 Migration | `Copy-VaultData`, `Test-CopilotInstructionsModified`, `Get-DiskSpaceCheck` | Legacy data migration |
| §8 Health | `Invoke-HealthCheck` | Diagnostic suite (12 probes) |
| §9 Templates | `$script:StockInstructions`, `$script:VaultReadme`, `$script:GitIgnoreTemplate` | Inline template content for one-file distribution |

### 17.3 Key Design Decisions

1. **Single-file distribution** — `ai-maker-lib.ps1` contains all templates inline (no external file dependencies during install)
2. **Transaction log** — every destructive operation goes through `Invoke-TxOp` for rollback capability
3. **Verify-or-throw** — never print success without proof (learned from v3.0.10 bug pattern: "silent success lies")
4. **3-tier agency.exe probe** — PATH → AppData glob → fallback (Velopack doesn't add to PATH)
5. **Pill-specific agents** — Blue Pill creates AI Maker only; Red Pill creates both AI Maker + AI Workbench (with full workbench skills)
6. **Checksum-protected updates** — skills with user modifications are never overwritten

### 17.4 Version Numbering

- Lib `$script:AIMakerConfig.Version` MUST match the release tag (minus `v` prefix)
- Example: release `v3.0.12` → lib version `"3.0.12"`
- The manifest's `installer_version` field gets this value
- Release assets (URLs, zip names) reference the same version

---

## 18. Test Architecture

### 18.1 Location

```
ai-maker/tests/contract/
├── harness/
│   └── AIMakerTestLib.psm1     ← State-capture library
├── fixtures/
│   ├── blue/                    ← Blue pill scenario fixtures
│   ├── red/                     ← Red pill scenario fixtures
│   └── sut/
│       ├── v3.0.10/             ← Known-good reference (FP's working build)
│       └── v3.0.11/             ← Second reference
├── assertions/                  ← Shared assertion helpers
├── cases/
│   ├── B1.Tests.ps1            ← Fresh Blue install
│   ├── B2.Tests.ps1            ← Blue rerun (idempotency)
│   ├── R1.Tests.ps1            ← Fresh Red install
│   └── R2.Tests.ps1            ← Red rerun (idempotency)
├── meta-tests/                  ← Tests that verify the test harness
└── test-installer.ps1           ← Entry point: .\test-installer.ps1 -Case B1
```

### 18.2 Test Cases

| Case | Scenario | Key Assertions |
|------|----------|----------------|
| **B1** | Fresh Windows 11, Blue Pill | Exit 0, 11 skills, manifest valid, workspace created, vault/maker empty, agents present, no .git |
| **B2** | Rerun Blue install (idempotency) | Exit 0, no new files, no deletions, checksums unchanged |
| **R1** | Fresh Windows 11, Red Pill | Exit 0, 22 skills, git repo, remote pushed, vault present, MCP servers registered |
| **R2** | Rerun Red install (idempotency) | Exit 0, no changes on rerun, manifest unchanged |

### 18.3 Assertion Priority

1. Protected-asset preservation (no pre-existing files modified)
2. Required artifacts present (all scaffold files exist)
3. Pill purity (Blue = no Red skills, Red = all 22)
4. Idempotent rerun (rerun = no changes)
5. MCP command shape + SHELL env var
6. Exit code contract (success = 0)

### 18.4 Test Sandbox

`AIMakerSandbox.psm1` provides isolated filesystem:
- Creates `$env:TEMP\ai-maker-test-{case}-{guid}/`
- Simulates `~/.copilot/`, `C:\GitHub/`, registry
- Pre-seeds synthetic `m-mcp-servers.json` for MCP tests
- Snapshots before/after install, compares directory tree
- `RemoteOverrides` hashtable injects test values instead of calling `gh`

### 18.5 Tags

| Tag | Meaning |
|-----|---------|
| `VMOnly` | Requires Hyper-V VM (Phase 2 — real OS install) |
| `Sandbox` | Runs in CI on every push (Phase 1 — simulated filesystem) |

---

## 19. Release Process

### 19.1 Release Repository

**Source:** `marcusash_microsoft/ai-maker` (org repo — where code lives)  
**Public:** `marcusash/ai-maker` (personal repo — where releases + Pages are published)

The org repo is where development happens. Releases are published to the personal repo because that's where the website and download URLs point.

### 19.2 Publishing Instructions (Any Agent Can Do This)

**Problem:** The org repo (`marcusash_microsoft/ai-maker`) is where code lives, but releases publish to Marcus's personal repo (`marcusash/ai-maker`). The EMU account cannot push to personal repos. A Personal Access Token (PAT) bridges this gap.

**Prerequisites:**
- `AI_MAKER_TOKEN` environment variable set at User scope on Marcus's machine
- This is a GitHub PAT for the `marcusash` account with `repo` scope
- It was set via: `[System.Environment]::SetEnvironmentVariable('AI_MAKER_TOKEN', '<token>', 'User')`
- Token expiry: ~90 days from 2026-06-27. If expired, Marcus must regenerate at https://github.com/settings/tokens

**Step-by-step release publish (copy-paste ready):**

```powershell
# 1. Set auth for personal repo (REQUIRED before any gh command targeting marcusash/ai-maker)
$env:GH_TOKEN = $env:AI_MAKER_TOKEN

# 2. Verify auth works
gh auth status  # Should show "Logged in to github.com account marcusash"

# 3. Create the release (if it doesn't exist yet)
gh release create v3.0.XX `
  --repo marcusash/ai-maker `
  --title "AI Maker v3.0.XX" `
  --notes "Release notes here"

# 4. Upload all assets (--clobber overwrites if re-uploading)
gh release upload v3.0.XX `
  --repo marcusash/ai-maker `
  --clobber `
  install.bat `
  ai-maker-lib.ps1 `
  install-blue.ps1 `
  install-red.ps1 `
  install-byo.ps1 `
  migrate.ps1 `
  verify.ps1 `
  agents.zip `
  skills.zip

# 5. Verify the release
gh release view v3.0.XX --repo marcusash/ai-maker

# 6. Test the latest redirect resolves
curl.exe -sSL -o NUL -w "%{url_effective}" https://github.com/marcusash/ai-maker/releases/latest/download/install.bat
# Should show the new version tag in the resolved URL
```

**Common errors:**
| Error | Cause | Fix |
|-------|-------|-----|
| 404 on upload | `GH_TOKEN` not set or expired | Run step 1; if still fails, token needs regeneration |
| 403 on upload | Token lacks `repo` scope | Marcus regenerates PAT with `repo` scope |
| "release not found" | Typo in tag or release doesn't exist | Run step 3 first |
| `gh: command not found` | gh CLI not in PATH | The EMU machine has gh installed; check PATH |

**IMPORTANT:**
- `gh` does NOT accept a `--token` flag — you MUST set `$env:GH_TOKEN`
- The token authenticates as `marcusash` (personal) not `marcusash_microsoft` (EMU)
- Always use `--clobber` when re-uploading to avoid "asset already exists" errors
- After publishing, verify the `/releases/latest/download/install.bat` URL resolves to the new version

**Reference:** Full publish knowledge also stored at `forge/knowledge/ai-maker-publish.md`

### 19.3 Release Assets

| Asset | Purpose |
|-------|---------|
| `install.bat` | Windows batch entry point |
| `ai-maker-lib.ps1` | Shared PowerShell library |
| `install-blue.ps1` | Blue Pill installer |
| `install-red.ps1` | Red Pill installer |
| `install-byo.ps1` | Bring Your Own Agents installer (infra only, syncs a user-chosen repo) |
| `migrate.ps1` | Legacy migration tool |
| `verify.ps1` | 12-probe verification tool |
| `agents.zip` | Agent identity files (ai-maker.md, ai-workbench.md) |
| `skills.zip` | All 22 skill folders |

### 19.4 Website

**URL:** https://marcusash.github.io/ai-maker/  
**Source:** GitHub Pages on `marcusash/ai-maker` (personal repo, `gh-pages` branch)  
**Owner:** FD (Design Lead) — **ONLY FD makes changes to the website.** Copy, visuals, layout, everything. No other agent touches it without FD's approval.

Pages:
- [`/`](https://marcusash.github.io/ai-maker/) — Main landing (Blue Pill focus, Matrix theme)
- [`/pro/`](https://marcusash.github.io/ai-maker/pro/) — Red Pill landing
- [`/account-setup/`](https://marcusash.github.io/ai-maker/account-setup/) — Which GitHub account to use
- [`/docs/migration-guide.html`](https://marcusash.github.io/ai-maker/docs/migration-guide.html) — CLI → App migration guide

**Design:** Matrix-themed (dark background, green/blue accents). Two pills visual metaphor.

**What the website promises:**
- One agent, 11 skills (Blue) or 22 skills (Red), five minutes to set up
- Runs inside the GitHub Copilot App
- Works everywhere, no admin rights required
- Persistent memory (vault) across sessions
- M365 integration (email, calendar, Teams)
- Cross-machine sync (Red Pill only)

---

## 20. Open Issues (Require Resolution)

### OI-11: PRD's Agency mandate (§6/§8) contradicts shipped Blue/Red/BYO code
**Status:** §6 and §8 declare Agency (`agency gh-app`, MCP registration, M365 MCP enablement) the non-negotiable foundation. The actually shipped `install-blue.ps1`, `install-red.ps1`, and the new `install-byo.ps1` contain zero Agency references — winget installs the Copilot App directly and WorkIQ ships as a standalone plugin. Marcus confirmed verbally this is intentional ("Agency wasn't working"). §21's release checklist still gates on Agency probes that can never pass today.  
**Owner:** FA  
**Action:** Reconcile §6/§8/§21 with the no-Agency architecture actually shipping, or restore Agency. Until resolved, treat §6.1/§6.2's Agency steps as aspirational, not current behavior.

### OI-8: Website instructions need updating
**Status:** Website install steps may not accurately reflect the actual flow (Agency auth browser popup, steps ordering). FA to review website against PRD and propose changes.  
**Owner:** FA  
**Action:** Compare https://marcusash.github.io/ai-maker/ against §6 install flow, flag gaps.

### OI-9: MCP liveness check does not exist
**Status:** No `agency mcp health` command. Only JSON structure is verified (keys present ≠ servers responding). If Marcus wants verified M365 connectivity post-install, we need either Agency to expose a health endpoint or a custom probe.  
**Owner:** FA to investigate Agency CLI capabilities  
**Priority:** P1 for v3.1, acceptable gap for v3.0.13

### OI-10: WorkIQ EULA may appear on first session
**Status:** Agency handles Entra auth during install (browser popup). But WorkIQ-specific consent may still appear on first Copilot App session. Need to verify on Cloud PC whether `agency gh-app` + MCP registration clears all consent gates.  
**Owner:** FA to verify during v3.0.13 testing  
**Priority:** Acceptable for v3.0.13 if website documents it clearly

### RESOLVED Issues

| # | Issue | Resolution | Resolved by |
|---|-------|-----------|-------------|
| OI-1 | Agency code missing from v3.0.12 | Fix forward — leave v3.0.12, ship v3.0.13 with merged code | Marcus (2026-06-28) |
| OI-2 | Version numbering | Lib version MUST match release tag. "3.0.0" in current code is a bug. | FP + FA |
| OI-3 | MCP registration method | Use FP's v3.0.10 pattern (direct JSON write via `Register-AgencyMcpServers`). FR's npx approach was wrong. | FP + FR confirmed |
| OI-4 | Skills location | `~/.copilot/skills/` only. Workspace `skills/` is source, not install target. | FP confirmed |
| OI-5 | Blue Pill includes Workbench agent? | NO — Blue Pill creates AI Maker only. Red Pill creates both AI Maker + AI Workbench. | Marcus (2026-06-28) |
| OI-6 | Install method | One-liner is canonical. Zip approach deprecated. | Marcus (2026-06-28) |
| OI-7 | DRA ownership | FA is DRA. FP contributes foundation code, FR contributes identity merge. | Marcus (2026-06-28) |

---

## 21. Release Checklist (Gate for Any Future Upload)

Before ANY release asset is uploaded to `marcusash/ai-maker`:

- [ ] All verify.ps1 probes pass on a **fresh** Windows 11 machine (or Cloud PC)
- [ ] All verify.ps1 probes pass on **rerun** (idempotency)
- [ ] Contract tests B1, B2, R1, R2 pass in sandbox
- [ ] Agency installed and `agency.exe` locatable
- [ ] `agency gh-app` launches App in Agency mode
- [ ] MCP registration confirmed (`m-mcp-servers.json` has workiq + bluebird)
- [ ] M365 MCPs enabled (teams, outlook, planner)
- [ ] WorkIQ MCP responds to health check
- [ ] Skills globally available (not just in ai-workspace)
- [ ] No regression vs previous release (before/after machine state diff)
- [ ] Version in lib matches release tag
- [ ] DRA signs off
- [ ] FA signs off (architecture)

---

## 22. Glossary

| Term | Meaning |
|------|---------|
| **Agency** | Microsoft's Agentic Engineering Platform — the runtime powering MCP servers and the Copilot App |
| **Agency mode** | The Copilot App running with Agency as its backend (`agency gh-app`) |
| **Blue Pill** | Simple install path — 11 skills, no git, local only |
| **Red Pill** | Full install path — 22 skills, git-backed, GitHub sync |
| **MCP** | Model Context Protocol — how AI agents access external tools/data |
| **WorkIQ** | Agency's M365 integration MCP server (email, calendar, Teams, tasks) |
| **Bluebird** | Agency's supporting MCP service |
| **Vault** | Persistent memory stored in `vault/maker/` or `vault/workbench/` |
| **Skill** | A folder in `~/.copilot/skills/` with a SKILL.md manifest |
| **Manifest** | `.ai-maker-manifest.json` — records install state (pill, version, skills, components) |
| **Scaffold** | The workspace directory structure created during install |
| **Entra** | Microsoft Entra ID — identity/auth system (formerly Azure AD) |
| **Velopack** | Agency's deployment tool — installs to AppData, does NOT add to PATH |
| **DRA** | Directly Responsible Agent — owns end-to-end delivery of a project |

---

*End of PRD — Last updated 2026-06-28 by FA (Chief Architect)*
