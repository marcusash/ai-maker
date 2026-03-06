# AI Maker Skill: Design and Presentation

Distilled from strong design practice. Applied when building documents, HTML canvases, dashboards, slides, or any visual output.

---

## Core Principle: Clarity Over Decoration

Every design decision must answer one question: "Does this help the reader understand faster?" If not, remove it.

---

## Documents and Written Output

**Lead with the action, not the context.** The reader needs to know what to do or decide before they need to know why.

**Use bullets over paragraphs** unless narrative is specifically needed. Prose is for explanation. Bullets are for decisions, lists, and status.

**Prose limit: two sentences per section.** If you need more, link to a separate document. A dashboard is not a report.

**No em dashes.** Use a colon, comma, or period. This is a hard rule, not a style preference.

**Match the human's voice.** Read their profile. Write like them, not like a corporate memo.

---

## Dashboard Design

**Light theme by default.** Background `#F1F5F9`, cards white `#FFFFFF`, text `#1E293B`. Dark themes are for terminals and monitoring consoles only.

**Color budget: 6 colors maximum.**
- 1 primary accent
- 3 status colors: green (pass/good), amber (warning), red (fail/blocked)
- 2 neutrals: dark text, muted gray

If you are using more than 6 colors, you are decorating, not communicating.

**One encoding per channel.** Color encodes one thing. If green means "complete" in section 1, it means "complete" everywhere. No decorative color.

**Cards show 3 data points maximum.** Primary value, supporting label, one line of context. Split into two cards if you need more.

**Status badges use exactly 3 states.**
- Negative (red): FAIL, BLOCKED, STALLED
- Neutral (gray): PENDING, IN PROGRESS, WAITING
- Positive (green): PASS, COMPLETE, DONE

**Typography has 4 levels, never more.**
1. Page title: 20-24px, semibold
2. Section label: 10px, monospace, uppercase, gray
3. Primary value: 32-48px for hero numbers
4. Secondary text: 11-12px, gray

**Section labels are always neutral gray.** Never colored. The content inside the section carries status color. The label is just a navigation marker.

---

## HTML Canvas

When building an HTML canvas (for review, approval, or presentation):

- Use tab navigation for multi-section content. Keyboard arrow key support.
- White cards with drop shadow on light body. No neon on dark.
- Agent color (e.g., FR orange `#F97316`) as accent only: borders, highlights, badges. Not for fills.
- Real content only. No placeholder text.
- Include a status bar at the bottom with approval state if the canvas requires sign-off.
- Mobile responsive. Test at narrow width.

---

## Squint Test

Before shipping any visual output: blur your eyes. Do the most important items pop? If everything has the same visual weight, reduce density and cut color. The signal should be visible at a glance.

---

## Review Checklist (any visual output)

- [ ] 6 colors or fewer. Count them.
- [ ] Color encodes exactly one thing.
- [ ] Cards: 3 data points max.
- [ ] Prose: 2 sentences max per section.
- [ ] Typography: exactly 4 levels.
- [ ] Status badges: exactly 3 states.
- [ ] Padding: 16px inside cards, 12px between cards, 32px between sections.
- [ ] No em dashes anywhere.
- [ ] Squint test passes.

---

*Source: dashboard design standards, iconography and color systems, design quality protocols. Distilled 2026.*
