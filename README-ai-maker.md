# AI Maker

> **Two pills. One choice.**
>
> 🔵 **Blue pill — you're here.** One agent. Five minutes. No repo. Dip your toe in.
>
> 🔴 **Red pill — go further.** Two agents. Full dev setup. Your own repo. [github.com/marcusash/gh-copilot-setup](https://github.com/marcusash/gh-copilot-setup)

---

## What is this?

AI Maker is a personalized GitHub Copilot agent that learns how you work and gets better at helping you over time. It runs in your terminal via the Copilot CLI.

One setup script. One agent. Done in five minutes. No GitHub repo required, no dev environment to configure.

If you have a Microsoft 365 Copilot license, AI Maker also connects to your email, calendar, and Teams via WorkIQ.

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

## Quick start

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/marcusash/ai-maker/main/setup.ps1 | iex
```

The script will ask for your name, then copy the AI Maker agent files to your machine and personalize them. If you want WorkIQ, it will walk you through that too.

Open the Copilot CLI. Your agent knows your name from session one.

---

## What you get

- **AI Maker agent** — a personalized Copilot agent with skills for design, code, research, quality, data, brainstorming, and user research
- **Onboarding interview** — AI Maker learns your working style in the first session
- **WorkIQ integration** — if you have M365 Copilot, AI Maker can query your calendar, email, and Teams without you having to summarize them
- **Personalization** — agent knows your name and adapts to your preferences over time

---

## Want more?

Take the red pill. Two agents, full dev environment, your own GitHub repo.

[github.com/marcusash/gh-copilot-setup](https://github.com/marcusash/gh-copilot-setup)

---

Created by [Marcus Ash](https://github.com/marcusash) · 2026
