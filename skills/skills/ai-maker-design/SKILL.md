---
name: ai-maker-design
description: "Use this skill when the user wants to create an HTML artifact, dashboard, one-pager, or visual report, or when they want feedback on a design's visual quality or brand compliance. Triggers include: 'build a dashboard', 'create an HTML page', 'design a one-pager', 'review this design', 'does this match the brand', 'make it look better', 'add a visual layout', 'canvas output', or any request to produce or review a polished visual deliverable. Do NOT use for technical UI development (React, WinUI 3) or accessibility audits of existing code — use the appropriate technical skill for those."
# version: 1.0.0 / source: FD / category: ai-maker
---

# AI Maker Design

Visual design, HTML canvas creation, and UX feedback for managers and non-designers. This skill helps you produce polished HTML artifacts, review design deliverables, and apply brand rules — without needing a design background.

## When to invoke

Use this skill when you need to:
- Create an HTML dashboard, one-pager, or visual report
- Review a design for visual quality, brand compliance, or usability
- Get structured feedback on a UI before sharing with stakeholders
- Apply brand colors, typography, or layout rules to a document
- Build a canvas artifact (landing page, status board, summary view)

## What it does

1. **Generates HTML artifacts** — produces self-contained HTML files with embedded CSS; no build step required
2. **Applies brand rules** — uses specified color palette, font choices, and spacing conventions
3. **Reviews designs** — provides structured UX feedback: hierarchy, readability, whitespace, contrast, call-to-action clarity
4. **Iterates on feedback** — takes "make it more X" instructions and applies them precisely
5. **Formats for print or screen** — applies appropriate styles for PDF rendering vs browser display

## Key behaviors

- Produces working code, not mockups — output is always a renderable file
- Accessibility-aware — checks contrast ratios, uses semantic HTML, avoids relying on color alone
- Mobile-considered — layouts don't break at smaller widths unless explicitly print-only
- Brand-consistent — never introduces unapproved colors or font families
- Scope-honest — flags when a request needs a real designer's judgment

## Output formats

- Self-contained HTML file
- Inline CSS stylesheet addition
- Structured design review (hierarchy / readability / brand / accessibility)
- Before/after design iteration

## Scope

This skill covers HTML artifact creation and design review for non-designers. For technical UI development (React components, WinUI 3, production web apps), use appropriate technical skills.
