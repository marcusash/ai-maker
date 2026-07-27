---
name: ai-maker-canvas
description: "Use this skill when the user wants a visual output that renders as an HTML page — dashboards, status boards, trackers, comparison tables, timelines, or any rich visual deliverable. Triggers include: 'build a dashboard', 'create a canvas', 'make a status board', 'visual summary', 'render this as HTML', 'interactive report', 'one-pager layout', 'card grid', 'progress tracker', or any request where the output should be a rendered HTML artifact rather than plain text. Also use when the user asks for an output they can share or print as a visual document."
# version: 1.0.0 / source: FR / category: ai-maker
---

# AI Maker Canvas

HTML and TUI dashboard creation, visual artifacts, and inline rendered outputs. This skill produces polished visual deliverables that render directly in the Copilot App's canvas panel.

## When to invoke

Use this skill when you need to:
- Build a status board, tracker, or summary dashboard
- Create a visual artifact to share with a team or leadership
- Render data as a formatted HTML table, chart, or card layout
- Produce a one-pager, timeline, or comparison view
- Generate any output that should be viewed as a rendered page rather than plain text

## What it does

1. **HTML artifact generation** — produces self-contained HTML with embedded CSS that renders cleanly in the App's canvas panel
2. **Dashboard layouts** — builds card grids, status boards, metric summaries, and progress trackers
3. **Data visualization** — renders tables, comparison matrices, timelines, and simple charts from provided data
4. **Export-ready formatting** — applies print-safe styles so artifacts can be captured or PDF'd
5. **Interactive elements** — adds collapsible sections, tabs, or filter UI where appropriate for the content

## Key behaviors

- Self-contained — all CSS is inline or embedded; no external dependencies
- Canvas-optimized — dimensions and layout tuned for the App's side-panel rendering
- Print-aware — uses `@media print` rules when output may be captured as PDF
- Semantic HTML — uses proper heading hierarchy and landmark elements
- Accessible — sufficient contrast, no color-only encoding, keyboard-navigable interactive elements

## Output formats

- Status dashboard (card grid, color-coded)
- Comparison matrix (side-by-side table)
- Timeline or milestone tracker
- Summary one-pager (hero stat + detail sections)
- Interactive tabbed report

## Scope

This skill covers HTML canvas artifact creation. It does not cover data ingestion or analysis — provide the data, this skill renders it. For data interpretation, use **AI Maker Data**.
