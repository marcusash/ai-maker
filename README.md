# AI Maker

An AI assistant for Microsoft managers. Install in about 10 minutes. Works on any Windows 10/11 machine with a GitHub account.

AI Maker installs GitHub Copilot CLI and WorkIQ, sets up a personal workspace, and gives you an AI assistant trained on your role — with skills for research, design feedback, code review, ops, data, brainstorming, user research, canvas work, and long-term memory.

---

## Getting started

Open `docs/install-guide.html` in your browser for the full step-by-step guide.

Or jump straight to the scripts:

```powershell
# From the scripts/ folder (Admin terminal required)
PowerShell -ExecutionPolicy Bypass -File .\install.ps1
```

---

## Repository structure

```
ai-maker/
  docs/
    install-guide.html        # Step-by-step install guide (open in browser)
    getting-started.html      # First-session Canvas guide
    copilot-instructions.md   # AI Maker system prompt (copied to workspace on install)
    onboarding-interview.md   # First-session interview protocol
    README.md                 # Detailed docs index
    skills/                   # 11 skill modules loaded into AI Maker
    specs/                    # Architecture and integration specs
  scripts/
    install.ps1               # Master installer (run this first)
    install-workiq.ps1        # WorkIQ integration installer
    launch.ps1                # Desktop shortcut target
    canvas.ps1                # Canvas workspace launcher
    create-shortcut.ps1       # Desktop shortcut creator
    test.ps1                  # 15-check verification suite
    package.ps1               # Packages repo into distribution ZIP
    publish.ps1               # Publishes distribution to sharing location
  assets/
    ai-maker.ico              # Brand icon
  evals/                      # Prompt quality evaluation pipelines
  tests/                      # Eval test suites
```

---

## Distribution

To share AI Maker with someone, run `package.ps1` to build `ai-maker-safe.zip`. Scripts are renamed `.txt` inside the ZIP to pass Microsoft SharePoint/email filters. The ZIP includes `docs/install-guide.html` at the root as `INSTALL-GUIDE.html` — open that first.

---

## Requirements

- Windows 10 or 11
- Internet connection
- A GitHub.com account (Microsoft Enterprise: `alias_microsoft`)
- About 10 minutes

---

## Owner

Marcus Ash, CVP of Design, Microsoft.
