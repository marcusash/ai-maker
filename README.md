# AI Maker

A personalized GitHub Copilot agent environment for Windows. Two agents, one setup.

---

## Quick start (lightweight — AI Maker only)

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/marcusash/ai-maker/main/setup.ps1 | iex
```

This installs just **AI Maker** — a personalized agent with skills for design, code, research, quality, data, brainstorming, and user research. Five minutes, no GitHub repo required.

---

## Full setup (AI Maker + AI Workbench)

For the complete environment with two agents and dev tools, open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/marcusash/ai-maker/main/install.ps1 | iex
```

This will:
1. Install Git, GitHub CLI, Node.js, VS Code, PowerShell 7, Windows Terminal, Oh My Posh
2. Create a GitHub repo (`your-username/pc-setup`) and push your setup files to it
3. Install AI Maker and AI Workbench, personalized with your name
4. Optionally set up WorkIQ (Microsoft 365 integration)

---

## What you get

**AI Maker** — design, code, research, quality, data, brainstorming, user research skills. Learns your working style in the first session via an onboarding interview.

**AI Workbench** (full setup only) — deep research, debugging, PowerShell and Windows expertise, GitHub management. Built for technical deep dives.

**WorkIQ integration** — if you have M365 Copilot, both agents can query your calendar, email, and Teams directly.

---

## Prerequisites

**Required:**
- Windows 10 or Windows 11
- GitHub account: [github.com](https://github.com)
- **GitHub Copilot Pro or higher** ($10/month) — the free plan does not support the CLI
- Node.js 22+ and PowerShell 7+ (the setup script installs these if missing)

**WorkIQ (optional — Microsoft 365 users only):**
- An organizational Microsoft 365 account (E3, E5, Business Standard, or Business Premium)
- Microsoft 365 Copilot add-on license
- IT admin consent to WorkIQ in your organization's Entra ID
- Personal Outlook.com accounts do not qualify

---

## After install

1. Open the Copilot CLI. AI Maker greets you by name and runs the onboarding interview.
2. Work through the tutorial in `docs/install-guide.html` for real tasks with your agent.
3. When ready, explore AI Workbench for deeper technical work.

See `STARTUP.md` for your daily routine.

---

## Re-running the installer

Safe to re-run on the same machine. Already-installed apps are detected and skipped.

```powershell
powershell -ExecutionPolicy Bypass -File C:\GitHub\pc-setup\install.ps1 -SkipApps -SkipThemes
```

Available skip flags: `-SkipApps`, `-SkipGit`, `-SkipThemes`, `-SkipRepos`

---

## File structure

```
ai-maker\
  install.ps1              Full installer (both agents + dev tools)
  setup.ps1                Lightweight installer (AI Maker only)
  start.ps1                Launch both agents in Windows Terminal
  stop.ps1                 Stop all running agent sessions
  STARTUP.md               Daily startup guide
  agents\
    ai-maker\
      copilot-instructions.md    AI Maker persona
      docs\                      Onboarding interview and reference docs
      skills\                    AI Maker skill files (11 skills)
    ai-workbench\
      copilot-instructions.md    AI Workbench persona
      skills\                    AI Workbench skill files
  docs\
    install-guide.html     Full setup guide with tutorials
```

---

Created by [Marcus Ash](https://github.com/marcusash) · 2026
