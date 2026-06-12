---
name: ai-maker-research
description: "Use this skill when the user wants to research a topic, evaluate a vendor or product, build a competitive landscape, or make an evidence-backed decision. Triggers include: 'research this', 'competitive analysis', 'what does the data say', 'investigate', 'market landscape', 'evidence for', 'look into', 'compare options', 'due diligence', 'strategic analysis', or any request to synthesize multiple sources before making a decision. Also use when preparing a research brief, executive summary, or recommendation memo. Do NOT use for deep technical implementation research (API docs, GitHub repo analysis) — use ai-workbench-researcher for that."
# --- AI Maker provenance (App ignores, manifest uses) ---
# version: 1.0.0
# source: FR
# updated: 2026-06-11
# category: ai-maker
---

# AI Maker Research

Evidence-first reasoning for managers and strategic decision-makers. This skill brings structured research methodology to business questions — competitive analysis, market intelligence, proposal evaluation, and synthesis of complex information into clear recommendations.

## When to invoke

Use this skill when you need to:
- Evaluate a vendor, product, or technology for a business decision
- Build a competitive landscape or market comparison
- Synthesize multiple sources into a coherent recommendation
- Red-team a proposal or plan before it goes to leadership
- Prepare a research brief, executive summary, or evidence-backed position paper

## What it does

1. **Frames the question** — converts a vague request into a clear research question with defined success criteria
2. **Gathers evidence** — pulls from web search, docs, prior context, and provided materials; cites every claim
3. **Synthesizes** — identifies patterns, contradictions, and gaps across sources
4. **Recommends** — produces a clear recommendation with supporting rationale and confidence level
5. **Formats for the audience** — output calibrated for managers: executive summary first, detail below

## Key behaviors

- Evidence before conclusion — never leads with opinion, always cites source
- Confidence-rated claims — distinguishes "confirmed", "probable", and "uncertain"
- Flags contradictions — surfaces conflicting evidence rather than hiding it
- Scope discipline — stays on the question; notes tangential findings but does not chase them
- Business framing — translates technical findings into business implications

## Output formats

- Executive summary (1 paragraph + 3-5 bullets)
- Competitive comparison table
- Evidence-backed recommendation memo
- Research brief with citations

## Scope

This skill is for **business and strategic research**. For deep technical research (API documentation, implementation patterns, GitHub repo archaeology), use **AI Workbench Researcher** instead.
