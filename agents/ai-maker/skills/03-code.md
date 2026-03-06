# AI Maker Skill: Code, Debugging, and Technical Work

Distilled from rigorous engineering practice. Applied when writing code, reviewing it, debugging it, or working through a technical problem with the human present.

---

## Smallest Possible Change

Make the minimum change that achieves the goal. Do not refactor while fixing. Do not fix unrelated things. Change as few lines as possible. If the goal requires a 3-line fix, the commit has 3 changed lines.

---

## Before Writing Any Code

State the acceptance criterion first. What does success look like? What does failure look like? Write that down before writing the code. If you cannot state the criterion, you do not understand the problem yet.

---

## Code Quality Non-Negotiables

**No hardcoded paths.** Use `path.join()` or `__dirname`-relative references. Never a literal `C:\Users\...` path in code.

**No swallowed errors.** Every catch block either logs the error, returns a typed failure, or re-throws. Empty catch blocks are bugs waiting to happen.

**Explicit return types on exported functions.** The reader should not have to infer what a function returns.

**No `any` types without an explicit cast through `unknown` first.** Every `JSON.parse()` output gets typed before use.

**Tests for every exported function.** At minimum: one happy path test, one failure path test, one boundary condition test.

---

## Debugging With the Human Present

When the human is watching, every wrong hypothesis costs trust. The protocol:

**1. Read the exact error, not their description of it.** Ask for the screenshot or terminal output. Their words are a paraphrase. The actual error text is the starting point.

**2. List all possible causes before committing to one.** For any error, name 3-4 possible causes. Do not commit to one until you have evidence.

**3. Check the source state before recommending any command.** Before telling them to pull, check that the source has actually been pushed. Before telling them to restart, confirm the config change was saved.

**4. Trace the causal chain before speaking.** Can you explain: "This command will fix it because [A] causes [B] which resolves [C]"? If you cannot trace it, check first.

**5. When wrong, say so immediately.** "My first hypothesis was wrong. Here is what I missed and here is the corrected hypothesis." Acknowledge, correct, continue. Do not trail off into a new recommendation without naming the miss.

**6. Verify before declaring done.** After every fix: run the test, check the output, confirm the numbers match. Never declare a problem fixed until the system confirms it.

---

## Two Wrong Answers Is the Limit

If you give a wrong hypothesis and then another wrong hypothesis in the same session: stop. Say "I need to verify something before I give you another recommendation." Check the actual state of the system. Come back with a confirmed hypothesis, not a third guess.

---

## Before Committing

- Run the tests. Never commit a red suite you did not break.
- Check for em dashes in any modified doc files. Remove all.
- Include the Co-authored-by trailer: `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`
- No secrets in code. Not in comments. Not in test fixtures unless clearly synthetic.

---

## Reading Code vs Reading Docs

Documentation about code goes stale. When you need to know if something is fixed, implemented, or working: read the source file. Not the roadmap. Not the ADR. Not the README. The source file is the truth.

---

*Source: TypeScript standards, self-critique protocol, joint debugging methodology. Distilled 2026.*
