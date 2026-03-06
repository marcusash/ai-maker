# AI Maker Skill: Quality and Testing

Distilled from quality-first engineering practice. Applied when writing tests, reviewing quality, or evaluating whether something is ready to ship.

---

## Quality Is a Gate, Not a Metric

A test suite is not proof of quality. It is a minimum bar. The question is not "do tests pass?" It is "do the tests catch the right failures?"

Every meaningful piece of behavior needs a test that would fail if the behavior broke. If no test would catch a regression, the behavior is not protected.

---

## What Must Be Tested

For every function or behavior:

- **Happy path:** The normal case works as expected.
- **Failure path:** The function fails gracefully when given bad input.
- **Boundary conditions:** Empty input, maximum input, null, zero. At least one of these per function.

For bug fixes: write the test that would have caught the bug before writing the fix. If you cannot write that test, you do not fully understand the bug.

---

## Test File Convention

Test file lives next to or mirroring the source: `tests/lib/{module-name}.test.ts`.

One test file per module. Tests in the same file as the code they test are not acceptable.

---

## When Tests Fail

Distinguish pre-existing failures from failures you caused. Report both, clearly separated. Never mark a task done when you have introduced new test failures.

If a test was already failing before your change, document it explicitly. Do not fix unrelated failures unless they are clearly caused by your work.

---

## Mutation Testing

Mutation testing measures whether your tests actually catch changes to the code (not just whether they run). A high mutation score means your tests are doing real work.

Target: 75% mutation score for core modules.

When mutation score is below target: look for the specific mutations that survived. A survived mutation means a behavior that can be changed without any test noticing. That is a test gap, not a code gap.

---

## Quality Before Shipping

Before declaring any deliverable done:

- [ ] All tests pass that were passing before.
- [ ] New behavior has test coverage (happy path + one failure path minimum).
- [ ] No em dashes in any new documentation.
- [ ] Acceptance criterion stated before the work was started, and met.
- [ ] If the task was a bug fix: the test that would have caught the original bug now exists.

---

## The Acceptance Criterion Rule

State what success looks like before starting any task. If you cannot state the criterion, the task is not well defined. Clarify before executing.

**Good criterion:** "The installer test suite runs 15 tests, all pass, and exit code is 0."

**Bad criterion:** "It works."

---

## Reporting Quality

When reporting test results: state the denominator. "15 of 15 tests pass" is more useful than "all tests pass." "36 of 2921 tests fail" tells a different story than "36 tests fail."

State which failures are pre-existing and which are new. If all failures are pre-existing, say so explicitly.

---

*Source: testing standards, mutation testing discipline, architecture review checklists. Distilled 2026.*
