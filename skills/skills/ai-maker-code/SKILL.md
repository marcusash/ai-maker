---
name: ai-maker-code
description: "Use this skill when a manager needs to understand, review, or evaluate code without writing it themselves. Triggers include: 'explain this code', 'review this PR', 'what does this do', 'is this good code', 'evaluate this architecture', 'what are the risks', 'prepare questions for the engineering team', 'what's the technical debt here', or any request to understand or assess a technical codebase from a manager's perspective. Do NOT use for writing production code or debugging implementations — use technical Workbench skills for that."
# version: 1.0.0 / source: FA / category: ai-maker
---

# AI Maker Code

Code review, architecture decisions, and refactoring guidance for managers who work with engineering teams. This skill helps you understand code, ask better questions, and make informed decisions — without needing to write production code yourself.

## When to invoke

Use this skill when you need to:
- Review a pull request or code change for quality, risk, or clarity
- Understand what a piece of code does in plain language
- Evaluate an architectural proposal from your engineering team
- Identify technical debt or risk in a codebase
- Prepare questions for an engineering review or planning session

## What it does

1. **Explains code** — translates code into plain language; describes what it does, why it matters, and what could go wrong
2. **Reviews PRs** — identifies bugs, security concerns, performance issues, and maintainability problems
3. **Evaluates architecture** — assesses proposals for scalability, complexity, and alignment with stated goals
4. **Identifies risk** — flags technical debt, missing tests, unclear ownership, and dependency concerns
5. **Drafts questions** — prepares specific, informed questions for engineering conversations

## Key behaviors

- Manager-calibrated — explains tradeoffs in business terms, not just technical ones
- Risk-first — surfaces the highest-risk findings immediately; detail follows
- Non-prescriptive on implementation — notes concerns without dictating solutions to engineers
- Evidence-based — cites specific lines, patterns, or precedents rather than vague concerns

## Output formats

- Code explanation in plain language
- Structured code review (bugs / security / performance / maintainability)
- Architecture evaluation with tradeoffs
- Engineering meeting prep: questions and context

## Scope

This skill is for managers reviewing and understanding code. For writing production code, building features, or debugging implementation issues, use a technical Workbench skill.
