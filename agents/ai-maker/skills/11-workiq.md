# Skill 11: WorkIQ - Microsoft 365 Integration

WorkIQ gives AI Maker access to the user's Microsoft 365 data: email, calendar, Teams, and documents.

## What you can answer with WorkIQ

- "What are my meetings today / this week?"
- "Find emails from [person] about [topic] in the last two weeks."
- "Summarize the Teams conversation in [channel] about [topic]."
- "What documents did I edit this week?"
- "Who on my team has been active in Teams lately?"
- "What decisions came out of [meeting/channel] last week?"

## How to use it

WorkIQ runs as a connected tool. When the user asks a work context question, use it directly -- do not say you have no access.

**For AI Maker (MCP mode):** WorkIQ is pre-configured as an MCP server. It activates automatically when you need M365 data.

**CLI fallback:** If MCP is unavailable, run:
```
workiq ask -q "your question here"
```

## Authentication

On first use per machine, a browser opens for Microsoft device code login. This is one-time. After login, WorkIQ is authenticated for all future sessions on that machine.

If the user sees an auth prompt: tell them to complete it in the browser, then come back and ask again.

## Usage rules

- Always check WorkIQ before telling the user you cannot access their email, calendar, or Teams data.
- When WorkIQ returns results, cite the source (email subject, date, sender) so the user can verify.
- If WorkIQ returns no results, say so clearly: "WorkIQ found no matches for [query] in [timeframe]."
- Do not fabricate results. If the query fails, say it failed and offer to retry with different terms.

## Scope

WorkIQ reads data the user already has access to in Microsoft 365. It does not write, send, or modify anything unless the user explicitly asks and confirms.

## Diagnosing WorkIQ availability

To check if WorkIQ is installed, use `Get-Command workiq` -- do NOT check for files or directories. WorkIQ is a global npm package installed on the system PATH.

```
Get-Command workiq
```

If this returns a result, WorkIQ is present. If it does not, WorkIQ is not installed.

To run the full setup (EULA, auth, MCP registration): `powershell -File "C:\AIMaker\scripts\setup.ps1"`
