---
name: ai-workbench-researcher
description: "Use this skill for deep technical research — digging into how a library, API, or framework actually behaves, analyzing GitHub repos, comparing implementation approaches, or tracing undocumented behavior through source code and issues. Triggers include: 'how does X actually work', 'dig into this repo', 'compare these approaches', 'find the root cause in the docs', 'what do the GitHub issues say', 'research the implementation', 'trace this behavior', or any request requiring multi-source technical evidence gathering. Do NOT use for business or strategic research — use ai-maker-research for that."
# --- AI Workbench provenance (App ignores, manifest uses) ---
# version: 1.0.0
# source: FR
# updated: 2026-06-11
# category: ai-workbench
---

# AI Workbench Researcher

Deep technical research for developers and builders. This skill performs multi-source evidence gathering on implementation questions — API behavior, library internals, GitHub repo archaeology, spec compliance, and comparative analysis of technical approaches.

## When to invoke

Use this skill when you need to:
- Understand how a library, API, or framework actually behaves (not just what the docs say)
- Dig into a GitHub repo to understand its architecture, recent changes, or open issues
- Compare two technical approaches with evidence from real-world usage
- Trace the root cause of an error through documentation, issues, and source code
- Build a technical brief before choosing an implementation strategy

## What it does

1. **Searches broadly** — GitHub repos, issue trackers, changelogs, RFCs, MDN, official docs, and community sources
2. **Goes past the docs** — reads source code, open issues, PRs, and community discussions to surface undocumented behavior
3. **Compares implementations** — side-by-side analysis of competing approaches with tradeoff matrix
4. **Cites precisely** — links to specific files, line numbers, issues, and commit SHAs where possible
5. **Summarizes for engineers** — output calibrated for technical readers: precision over brevity, specifics over generalities

## Key behaviors

- Source hierarchy: official spec → official docs → source code → maintainer statements → community consensus → anecdote
- Distinguishes version-specific behavior — always notes which version a finding applies to
- Reproduces findings — when possible, provides a minimal example or test to confirm behavior
- Flags deprecations and breaking changes in findings
- Technical framing — does not simplify findings for non-technical audiences; use AI Maker Research for that

## Output formats

- Technical research brief with citations
- Implementation comparison matrix (approach / tradeoffs / evidence)
- API behavior summary with version notes
- "What I found vs what the docs claim" discrepancy report

## Scope

This skill is for **technical and implementation research**. For business intelligence, competitive analysis, or executive-level synthesis, use **AI Maker Research** instead.
