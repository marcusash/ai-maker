---
name: ai-workbench-testing
description: "Use this skill to write test code — unit tests, end-to-end tests, or PowerShell tests. Triggers include: 'write tests for this', 'add unit tests', 'Vitest', 'Playwright', 'Pester', 'test this function', 'increase coverage', 'E2E test', 'test suite', 'fix this failing test', 'mock this dependency', or any request to produce actual test files. Do NOT use for testing strategy and coverage planning (what to test, not how) — use ai-maker-quality for that."
# version: 1.0.0 / source: FF / category: ai-workbench
---

# AI Workbench Testing

Test writing and coverage implementation for developers. This skill writes tests in Vitest, Playwright, and Pester — not just testing strategy, but actual test code.

## When to invoke

Use this skill when you need to:
- Write unit tests for a function, module, or component
- Set up Playwright for end-to-end browser testing
- Write Pester tests for a PowerShell script or module
- Increase test coverage on a specific file or code path
- Debug a failing test and identify the root cause

## What it does

1. **Unit test authoring** — writes Vitest/Jest tests with proper setup, teardown, mocks, and assertions
2. **E2E test authoring** — writes Playwright tests for UI flows: navigation, form submission, element state
3. **PowerShell testing** — writes Pester test files with Describe/It blocks, BeforeAll/AfterAll hooks
4. **Coverage analysis** — reads a coverage report and identifies the highest-value untested paths
5. **Test debugging** — diagnoses flaky tests, timing issues, and mock failures

## Key behaviors

- AAA structure — Arrange / Act / Assert pattern in every test
- Meaningful assertions — `expect(x).toBe(y)` with a value that matters, not `toBeTruthy()` on everything
- Isolated tests — no shared mutable state between tests; each test sets up its own context
- Descriptive names — test names describe the scenario, not the implementation (`"returns error when input is empty"`, not `"test 1"`)
- Coverage-strategic — prioritizes testing critical paths and error conditions over happy-path only

## Output formats

- Complete test file (.test.ts, .spec.ts, .Tests.ps1)
- Test suite addition (new describe block or test cases for existing file)
- Failing test diagnosis with fix
- Coverage gap analysis with recommended test additions

## Scope

This skill writes actual tests. For testing strategy and coverage standards (what to test and why, without writing the code), use **AI Maker Quality**.
