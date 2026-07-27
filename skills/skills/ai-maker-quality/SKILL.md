---
name: ai-maker-quality
description: "Use this skill when the user needs to define testing strategy, set quality standards, evaluate test coverage, or review a QA plan. Triggers include: 'what should we test', 'is our test coverage good enough', 'define acceptance criteria', 'review this QA plan', 'what's the right testing approach', 'how much testing do we need', 'quality gate', or any request to reason about what quality means for a project. Do NOT use for writing actual test code — use ai-workbench-testing for that."
# version: 1.0.0 / source: FF / category: ai-maker
---

# AI Maker Quality

Testing strategy, quality standards, and coverage planning for managers. This skill helps you define what "good enough" means for a project and how to verify it — without writing the tests yourself.

## When to invoke

Use this skill when you need to:
- Define a testing strategy for a project or feature
- Evaluate whether a team's test coverage is adequate
- Set quality gates and acceptance criteria for a release
- Review a QA plan before sign-off
- Understand the difference between unit, integration, and end-to-end tests

## What it does

1. **Defines testing strategy** — recommends the right mix of test types for a given project and risk profile
2. **Sets coverage standards** — recommends coverage thresholds based on code criticality and team size
3. **Writes acceptance criteria** — translates feature requirements into testable pass/fail conditions
4. **Reviews QA plans** — identifies gaps in test coverage, missing edge cases, or unverified assumptions
5. **Explains testing concepts** — clarifies unit vs integration vs E2E, manual vs automated, shift-left vs traditional QA

## Key behaviors

- Risk-based — higher coverage requirements for higher-risk code paths
- Pragmatic — recommends what's achievable, not a theoretical ideal
- Business-framed — connects quality gaps to user impact and business risk
- Non-prescriptive on tooling — recommends approaches, lets engineers choose specific tools

## Output formats

- Testing strategy document
- Acceptance criteria checklist
- QA plan review with gap analysis
- Coverage recommendation with rationale

## Scope

This skill covers testing strategy and quality standards for managers. For writing actual tests in Vitest, Playwright, or Pester, use **AI Workbench Testing**.
