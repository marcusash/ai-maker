# GitHub Copilot Setup

> **Two pills. One choice.**
>
> 🔵 **Blue pill — start smaller.** One agent, five minutes, no repo. [github.com/marcusash/ai-maker](https://github.com/marcusash/ai-maker)
>
> 🔴 **Red pill — you're here.** Two agents. Full dev setup. Your own repo. See how deep the rabbit hole goes.

---

## What is this?

A complete Windows developer environment setup with two personalized GitHub Copilot agents — AI Maker and AI Workbench. One install script sets up your whole machine: Git, GitHub CLI, VS Code, Windows Terminal, and both agents. It also creates a GitHub repo in your name so you can maintain and extend your setup going forward.

This is the full path. If you want to dip your toe in first, start with [AI Maker](https://github.com/marcusash/ai-maker).

---

## Prerequisites

**Required:**
- Windows 10 or Windows 11
- GitHub account: [github.com](https://github.com)
- **GitHub Copilot Pro or higher** ($10/month) — the free plan does not support the CLI
- About 20 minutes for a fresh machine install

**WorkIQ (optional — Microsoft 365 users only):**
- An organizational Microsoft 365 account (E3, E5, Business Standard, or Business Premium)
- Microsoft 365 Copilot add-on license
- IT admin consent to WorkIQ in your organization's Entra ID
- Personal Outlook.com accounts do not qualify

---

## Quick start

Open PowerShell **as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/marcusash/gh-copilot-setup/main/install.ps1 | iex
```

The script will ask for your name and GitHub username, then:
1. Install Git, GitHub CLI, Node.js, VS Code, PowerShell 7, Windows Terminal, Oh My Posh
2. Create a GitHub repo (`your-username/pc-setup`) and push your setup files to it
3. Install AI Maker and AI Workbench, personalized with your name
4. Optionally set up WorkIQ (Microsoft 365 integration)

---

## What you get

**AI Maker** — design, code, research, quality, data, brainstorming, user research skills. Learns your working style in the first session.

**AI Workbench** — deep research, debugging, PowerShell and Windows expertise, GitHub management. Built for technical deep dives.

**Your own repo** — `your-username/pc-setup` on GitHub. Add your own skills, update agent instructions, and push your changes. This is your environment now.

**WorkIQ integration** — if you have M365 Copilot, both agents can query your calendar, email, and Teams directly.

---

## What's next after install

1. Open the Copilot CLI. AI Maker greets you by name and runs the onboarding interview.
2. Work through the tutorial in `docs/install-guide.html` — it walks you through real tasks with your agent.
3. When you're ready, explore AI Workbench for deeper technical work.

---

## Changed your mind?

The blue pill is always there.

[github.com/marcusash/ai-maker](https://github.com/marcusash/ai-maker)

---

Created by [Marcus Ash](https://github.com/marcusash) · 2026
