---
name: ai-maker-workiq
description: "Use this skill for Microsoft 365 integration — email, calendar, Teams, tasks, and M365 search. Triggers include: 'send an email', 'schedule a meeting', 'draft a Teams message', 'find that email', 'what's on my calendar', 'create a task', 'Outlook', 'Teams post', 'Microsoft 365', 'M365', 'check availability', or any request to take action in the Microsoft 365 ecosystem. Do NOT use for general communication drafting without M365 integration — use ai-maker-ops for that."
# version: 1.0.0 / source: FP / category: ai-maker
---

# AI Maker WorkIQ

Microsoft 365 integration — email, calendar, Teams, and task management for managers. This skill helps you act on your M365 environment: drafting, searching, scheduling, and coordinating through the tools you already use.

## When to invoke

Use this skill when you need to:
- Draft or send an email in Outlook
- Find a meeting, document, or email from your M365 history
- Schedule a meeting or manage your calendar
- Compose a Teams message or channel post
- Look up who's available, what's due, or what's been decided in recent communications

## What it does

1. **Email drafting** — writes Outlook emails with correct tone, structure, and level of detail for the recipient
2. **Calendar management** — schedules meetings, checks availability, drafts invites with agenda
3. **Teams communication** — composes channel posts, meeting chat messages, and @ mentions appropriately
4. **M365 search** — finds emails, documents, and meetings by topic, person, or time range
5. **Task tracking** — creates and manages tasks in Microsoft To Do or Planner from conversation context

## Key behaviors

- Audience-calibrated — email to a direct report vs a VP vs a customer all sound different
- Action-triggering — always knows the next step: draft, send, schedule, or find
- Privacy-aware — does not store M365 content in vault without explicit instruction
- Integration-honest — notes when an action requires the user to confirm in the actual M365 app

## Output formats

- Email draft (subject + body, ready to paste into Outlook)
- Meeting invite (title, attendees, agenda, duration)
- Teams message draft
- M365 search results summary

## Scope

This skill covers M365 productivity integration. For sprint operations and general team communication (non-M365), use **AI Maker Ops**.
