# AI Maker — Architecture Overview

**Purpose:** A single unified agent persona that combines Forge expertise for team leaders and managers starting from zero with AI tools.

**What it installs:** GitHub CLI, GitHub Copilot CLI extension, WorkIQ plugin, the AI Maker persona (via `.github/copilot-instructions.md`), and a desktop shortcut to launch everything in one click.

**What the agent does first:** Interviews its human. No assumptions about style, context, or goals until the human has been heard.

---

## File Hierarchy

```
docs/ai-maker/
  README.md                      <- This file. Architecture overview.
  copilot-instructions.md        <- THE SYSTEM PROMPT. Copied to .github/ in workspace.
  onboarding-interview.md        <- First-session interview script (10 questions, 1-5 spectrums).
  skills/
    01-research.md               <- Evidence-first reasoning, confidence levels, findings.
    02-design.md                 <- HTML canvas, design standards, brand rules.
    03-code.md                   <- Code review, architecture, debugging with humans.
    04-quality.md                <- Testing standards, quality gates, mutation coverage.
    05-ops.md                    <- Communication, inbox protocol, sprint ops.
    06-data.md                   <- Data pipelines, evals, metrics.
    07-brainstorming-feedback.md <- Facilitation, critique, decision support, red teaming.

scripts/ai-maker/
  install.ps1                    <- Master installer. Runs all steps, prints PASS/FAIL per step.
  install-workiq.ps1             <- WorkIQ plugin setup (npm primary, MCP config fallback).
  create-shortcut.ps1            <- Desktop shortcut with Octocat .ico.
  launch.ps1                     <- What the shortcut runs. Opens terminal at C:\AIMaker\.
  test.ps1                       <- 15 post-install verification tests (T01-T15).

assets/
  ai-maker.ico                   <- GitHub Octocat icon for the desktop shortcut.
```

---

## How It Works

1. Admin runs `scripts/ai-maker/install.ps1` on a team leader's machine.
2. Installer checks prereqs (Node, Git, gh CLI), installs what's missing.
3. Installs GitHub Copilot CLI extension and WorkIQ plugin.
4. Creates `C:\AIMaker\` workspace with `.github\copilot-instructions.md` (the persona).
5. Creates desktop shortcut pointing to `scripts/ai-maker/launch.ps1`.
6. Runs `test.ps1` to verify every step. Reports pass/fail for each.
7. Human clicks the shortcut. Terminal opens in `C:\AIMaker\`. Copilot CLI launches.
8. AI Maker reads `copilot-instructions.md` and immediately begins the onboarding interview.

---

## Persona Loading Mechanism

GitHub Copilot CLI auto-loads `.github/copilot-instructions.md` from the working directory. The shortcut opens the terminal at `C:\AIMaker\`, which contains `.github\copilot-instructions.md`. No agent setup required from the human.

After the onboarding interview, AI Maker writes the profile to `C:\AIMaker\profile.md`. Every subsequent session reads that profile on start.

---

## WorkIQ Integration

WorkIQ is a Microsoft MCP plugin that gives the agent access to M365 data: meetings, emails, Teams channels, recent documents, org connections.

**Install method (automated by `install-workiq.ps1`):**
```powershell
gh copilot /plugin install workiq@copilot-plugins
```
Fallback if plugin marketplace is unavailable:
```powershell
npm install -g @microsoft/workiq
# writes MCP config to %APPDATA%\GitHub Copilot\mcp.json
```

**First-time user auth:** On first launch, a browser opens with a Microsoft device code page. The user completes their Microsoft login. After that, auth is silent on every session.

What it unlocks for team leaders:
- "What are my meetings today and who else is attending?"
- "Summarize emails from my skip-level about the project."
- "Find documents I edited this week on the reorg."
- "Who on my team has been most active in the Teams channel?"

---

## WorkIQ: Tenant Admin Setup (Required for Org Rollout)

Before WorkIQ works for anyone in the org, a Microsoft 365 tenant admin must grant consent once. Without this step, every user sees a consent screen on first launch and may be blocked by org policy.

**Steps for the tenant admin:**

1. Go to the [Microsoft Entra admin center](https://entra.microsoft.com) and sign in with a Global Admin or Cloud Application Admin account.

2. Navigate to: **Identity > Applications > Enterprise applications**.

3. In the search box, type **WorkIQ** and select it from the results. If it does not appear yet, a user must complete the device code auth flow once first to register the app in the tenant.

4. Select **Permissions** from the left nav, then click **Grant admin consent for [your org name]**.

5. Review the permissions list (calendar read, mail read, Teams read, files read). Click **Accept**.

6. Verify status: all permissions now show "Granted for [org name]" with a green check.

**After tenant consent is granted:**
- Users do not see a consent screen on first launch.
- Users still complete their own device code auth once (Microsoft personal identity verification -- this cannot be bypassed).
- Subsequent sessions are fully silent.

**If WorkIQ is blocked by corp policy (no npm, no plugin marketplace):**
- IT must whitelist `@microsoft/workiq` on the npm registry, OR
- IT deploys the MCP config file directly to `%APPDATA%\GitHub Copilot\mcp.json` on each machine.
- The MCP config format: `{"mcpServers":{"workiq":{"command":"npx","args":["-y","@microsoft/workiq","mcp"]}}}`

**Reference:** [WorkIQ on Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/workiq)

---

## Icon

GitHub Octocat `.ico`. Same icon used for the Forge launcher.
Source: `assets/ai-maker.ico`.

---

*FR. 2026-02-23. Architecture document.*
