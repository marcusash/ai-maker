# AI Agent PC Setup

A portable setup for your own AI agent environment on a new Windows PC. After running the installer, you will have:

- Two AI agents running in Windows Terminal: **AI Maker** (for daily work) and **AI Workbench** (for research and technical tasks)
- Dev tools installed: Git, GitHub CLI, Copilot CLI, Node.js, VS Code, PowerShell 7
- Terminal configured with Oh My Posh themes and the Handy speech-to-text app
- Agent workspaces at `C:\AIMaker` and `C:\AIWorkbench`

---

## Setup on a new machine

### Step 1: Open PowerShell as administrator

Press `Win`, type `powershell`, right-click, select **Run as administrator**.

### Step 2: Run the installer

If you have Git already:
```powershell
git clone https://github.com/YOUR_GITHUB_USERNAME/pc-setup C:\GitHub\pc-setup
cd C:\GitHub\pc-setup
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Or download and run in one step:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/pc-setup/main/install.ps1 -OutFile $env:TEMP\install.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\install.ps1
```

The installer will ask for your name, GitHub username, and email. Everything is configured from your answers.

### Step 3: Close and reopen Windows Terminal

Fonts and themes take effect after a restart.

### Step 4: Launch your agents

Double-click **AI Agents** on your Desktop, or run:
```powershell
pwsh -File C:\GitHub\pc-setup\start.ps1
```

---

## Daily use

See `STARTUP.md` for your daily routine.

---

## Re-running the installer

Safe to re-run on the same machine. Already-installed apps are detected and skipped.

```powershell
powershell -ExecutionPolicy Bypass -File C:\GitHub\pc-setup\install.ps1 -SkipApps -SkipThemes
```

Available skip flags:
- `-SkipApps` — skip app installs
- `-SkipGit` — skip Git and GitHub CLI config
- `-SkipThemes` — skip Oh My Posh and shell profiles
- `-SkipRepos` — skip repo cloning

---

## File structure

```
pc-setup\
  install.ps1              Main installer
  setup.bat                Double-click to run with elevation
  start.ps1                Launch both agents in Windows Terminal
  stop.ps1                 Stop all running agent sessions
  STARTUP.md               Daily startup guide
  agents\
    ai-maker\
      copilot-instructions.md    AI Maker persona
      docs\                      Onboarding interview and reference docs
      skills\                    AI Maker skill files
    ai-workbench\
      copilot-instructions.md    AI Workbench persona
      skills\                    AI Workbench skill files
  docs\
    install-guide.html     Full setup guide with tutorials (open in browser)
  user-config.ps1          Your name, GitHub username, email (gitignored)
```

---

## Tutorials

Open `docs\install-guide.html` in your browser for the full guide, including:
1. My GitHub Home
2. Meeting Intelligence Report
3. Team Onboarding Kit
4. Your Voice Skill
