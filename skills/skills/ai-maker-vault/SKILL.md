---
name: ai-maker-vault
description: "Use this skill to save, recall, or organize information in the vault — the personal knowledge base. Triggers include: 'save this', 'remember this', 'add to vault', 'log this decision', 'what did we decide about X', 'find in my vault', 'recall', 'document this', 'knowledge base', 'where did I put', 'organize my notes', or any request to persist or retrieve personal context across sessions. Also use when the user wants to capture a decision with its rationale for future reference."
# version: 1.0.0 / source: FR / category: ai-maker
---

# AI Maker Vault

Long-term memory management, knowledge save/recall, and vault organization for AI Maker users. This skill helps you store what matters, retrieve it when needed, and keep your vault from becoming a graveyard.

## When to invoke

Use this skill when you need to:
- Save a decision, proposal, or reference for future retrieval
- Recall something you know you saved but can't find
- Organize your vault: consolidate duplicates, create structure
- Document a decision with its rationale for future reference
- Build a personal knowledge base entry from a conversation

## What it does

1. **Save** — structures and writes vault entries in the correct category folder (how-to, proposals, references, decisions)
2. **Recall** — searches vault content for relevant prior context given a current question
3. **Organize** — suggests vault structure improvements, identifies duplicates, consolidates scattered notes
4. **Decision logging** — captures a decision with: what was decided, why, alternatives considered, and who decided
5. **Knowledge extraction** — pulls key learnings from a conversation or document and formats them as a vault entry

## Vault structure

```
vault/
├── how-to/         (procedures, instructions, playbooks)
├── proposals/      (active and past proposals)
├── references/     (links, specs, source material)
└── decisions/      (decision log with rationale)
```

## Key behaviors

- Dated entries — every saved item includes a date so decay is traceable
- Retrieval-optimized — entries are written to be findable, not just saveable (clear titles, tags where appropriate)
- Minimal friction — saving should take seconds, not a filing session
- Decay-aware — notes when a saved item may be stale and should be reviewed

## Output formats

- Vault entry (markdown file, ready to save)
- Decision log entry (structured: decision / rationale / alternatives / owner / date)
- Recall response: what the vault contains relevant to the question
- Vault audit: inventory of what's there, what's stale, what's missing

## Scope

This skill covers vault read/write and knowledge management for AI Maker. It does not commit to GitHub — for sync, use Red Pill git workflow.
