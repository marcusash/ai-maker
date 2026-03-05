# Daily Startup Guide

## Morning routine (2 minutes)

**1. Launch your agents**

Double-click **AI Agents** on your Desktop.

Two tabs open in Windows Terminal:
- **AI Maker** (yellow tab): your daily work partner
- **AI Workbench** (red tab): research and technical tasks

**2. AI Maker greets you**

AI Maker will read your profile and say: "Good morning, [your name]. Ready to work. What's first?"

Tell it what's on your plate today.

---

## What each agent is for

| AI Maker | AI Workbench |
|----------|--------------|
| Write and edit emails | Research and fact-checking |
| Summarize meeting notes | Analyze data and documents |
| Draft docs and updates | Debug technical problems |
| Brainstorm ideas | Run PowerShell scripts |
| Daily planning | GitHub management |
| Canvas presentations | Build tools and automations |

A good rule: if you could describe the task as "help me with my work," use AI Maker. If the task involves digging into data, running code, or solving a technical problem, use AI Workbench.

---

## Stopping your agents

Close the Windows Terminal tabs, or run:
```
pwsh -File C:\GitHub\pc-setup\stop.ps1
```

---

## Updating your agents

When you push changes to your pc-setup repo:
```
cd C:\GitHub\pc-setup
git pull
pwsh -File .\install.ps1 -SkipApps -SkipGit -SkipThemes -SkipRepos
```

This re-copies the latest agent instructions to `C:\AIMaker` and `C:\AIWorkbench`.

---

## Adding a skill

Skills are markdown files in your agent's `.github\skills\` folder.

**To install a skill from GitHub:**
1. Open AI Workbench
2. Run: `git clone https://github.com/AUTHOR/skill-repo C:\Temp\new-skill`
3. Copy the skill file: `Copy-Item C:\Temp\new-skill\SKILL.md C:\AIWorkbench\.github\skills\skill-name.md`
4. Clean up: `Remove-Item C:\Temp\new-skill -Recurse -Force`
5. Restart AI Workbench

Or just tell AI Workbench: "Install this skill from GitHub: [URL]" and it will handle it.

---

## First-time setup checklist

- [ ] Ran `install.ps1` successfully
- [ ] Reopened Windows Terminal (fonts take effect)
- [ ] Launched agents with "AI Agents" desktop shortcut
- [ ] Completed AI Maker onboarding interview (first launch only)
- [ ] Opened `docs\install-guide.html` and read it
- [ ] Completed Tutorial 1 (My GitHub Home)

---

## Quick reference

| Task | Command |
|------|---------|
| Start agents | Double-click "AI Agents" on Desktop |
| Stop agents | `pwsh -File C:\GitHub\pc-setup\stop.ps1` |
| Re-run installer (apps only) | `pwsh -File C:\GitHub\pc-setup\install.ps1 -SkipThemes -SkipRepos` |
| Update agent instructions | `cd C:\GitHub\pc-setup; git pull; .\install.ps1 -SkipApps -SkipGit -SkipThemes -SkipRepos` |
| Open install guide | Open `C:\GitHub\pc-setup\docs\install-guide.html` in browser |
