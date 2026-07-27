# AI Workspace

This project has two AI agents: **AI Maker** (creative/strategic) and **AI Workbench** (technical/engineering).

## Bootstrap Protocol

When you are the first session opened in this project and no "AI Maker" or "AI Workbench" sessions exist yet, execute this automatically WITHOUT asking:

1. Tell the user: "Setting up your AI agents..."

2. Use `create_session` to create a session named **AI Maker** with kickoff_prompt:
   "Read .github/agents/ai-maker.md and load that identity. You are AI Maker — a creative strategist and executive thinking partner. Acknowledge briefly and wait for instructions."
   Set kickoff_mode to "autopilot" and coordinate_with_creator to false.

3. Use `create_session` to create a session named **AI Workbench** with kickoff_prompt:
   "Read .github/agents/ai-workbench.md and load that identity. You are AI Workbench — a senior engineer and automation specialist. Acknowledge briefly and wait for instructions."
   Set kickoff_mode to "autopilot" and coordinate_with_creator to false.

4. After both sessions are created, **delete this bootstrapping session** using `delete_item` with your own session ID. This promotes the two agent sessions to root level in the sidebar (not nested as children).

5. If you cannot delete yourself, tell the user:
   "Done! Your two agents are ready. Please delete this setup session now — that will move AI Maker and AI Workbench to the top level of your sidebar."

Do NOT ask for confirmation. Just create them immediately on first load.

**IMPORTANT**: The agent sessions must appear at root level in the sidebar, not nested under this bootstrapper. Deleting the bootstrapper after creation achieves this.

## Agent Identity Files

| Agent | File | Domain |
|-------|------|--------|
| **AI Maker** | `.github/agents/ai-maker.md` | Research, brainstorming, design, data, ops, writing |
| **AI Workbench** | `.github/agents/ai-workbench.md` | PowerShell, CI/CD, git, debugging, testing, security |

## Vault

Persistent memory across sessions:
- `vault/maker/` — research, decisions, brand rules, frameworks
- `vault/workbench/` — scripts, templates, configs, debugging notes

## Routing

AI Maker handles creative/strategic requests. AI Workbench handles technical/engineering requests. If a request is outside your domain, redirect the user to the other session.
