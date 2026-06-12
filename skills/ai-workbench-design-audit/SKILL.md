---
name: ai-workbench-design-audit
description: "Use this skill to evaluate and review an existing HTML, UI, or visual artifact for quality, accessibility, or brand compliance. Triggers include: 'review this design', 'audit this HTML', 'check accessibility', 'WCAG compliance', 'contrast ratio', 'brand check', 'layout bugs', 'design quality', 'is this accessible', 'score this UI', or any request to evaluate something that already exists. Do NOT use to create new designs — use ai-maker-design or ai-maker-canvas for creation."
# version: 1.0.0 / source: FF / category: ai-workbench
---

# AI Workbench Design Audit

Evaluative review of HTML, UI, and visual deliverables for technical quality, accessibility, and design correctness. This skill audits what's been built — it does not create new designs.

## When to invoke

Use this skill when you need to:
- Review an HTML deliverable for visual quality before sending to stakeholders
- Audit a UI for accessibility compliance (contrast, keyboard, screen reader)
- Check that a design matches brand guidelines or spec
- Identify layout bugs across screen sizes or print/PDF rendering
- Get a structured quality score on a design artifact

## What it does

1. **Visual quality review** — evaluates hierarchy, whitespace, typography, and color use against design principles
2. **Accessibility audit** — checks contrast ratios (WCAG AA), keyboard navigability, ARIA labels, and color-only encoding
3. **Brand compliance check** — compares colors, fonts, and spacing against provided brand rules
4. **Layout bug detection** — identifies overflow, overflow-hidden issues, misaligned elements, and print-mode breakage
5. **Structured scoring** — produces a scored review: visual quality / accessibility / brand / technical correctness

## Key behaviors

- Evaluative, not generative — this skill reviews; it does not redesign (use AI Maker Design for new creation)
- Evidence-cited — every finding references a specific element, rule, or line of code
- Severity-ranked — blocking (accessibility/brand violations) vs warnings (improvement opportunities) vs notes
- Actionable — every finding includes a specific fix recommendation

## Output formats

- Structured audit report (scored, severity-ranked)
- Accessibility findings with WCAG reference and fix
- Brand compliance checklist result
- Layout bug list with reproduction steps

## Scope

This skill evaluates existing HTML/UI artifacts. For creating new designs or generating HTML artifacts, use **AI Maker Design** or **AI Maker Canvas**.
