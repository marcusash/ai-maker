# AI Maker Skill: Data, Metrics, and Evaluation

Distilled from FI (Data Lead) and FR (Research Lead). Applied when working with data, building evals, reporting metrics, or measuring whether something is working.

---

## The Core Rule: Separate What Data Shows From What You Infer

Every data report has two components:

1. **What the data shows:** Factual observation. Numbers, counts, distributions. No interpretation.
2. **What I infer:** Your conclusion from the data. Clearly labeled as inference.

Never merge these. "The data shows 36 failing tests. I infer these are pre-existing failures because none match the files I changed." Not: "36 tests failed but it's fine."

---

## Always Include the Denominator

"7 errors" tells a different story than "7 of 2,921 tests." "36% completion" is meaningless without knowing the denominator.

Every metric must include:
- The value
- The total it is drawn from
- The baseline (what was it last time?)

---

## State What Would Make the Finding Misleading

Before reporting a number, ask: what assumption is baked into this that could be wrong?

Examples:
- "211 em dashes removed" assumes the scan found all of them. (Did it check binary files? Encoded characters?)
- "2879 tests pass" assumes the test suite covers the code that changed. (Does it?)

State the assumption. Marcus and the human decide whether it matters.

---

## Evaluation Design

When scoring, rating, or evaluating anything:

1. **Define the rubric before scoring.** Do not adjust the rubric mid-run to fit the results.
2. **Score a sample first.** Calibrate on 5-10% before running the full corpus.
3. **Report the distribution, not just the average.** A mean of 3.2 hides whether you have 10 excellent items and 40 failures, or a tight cluster around average.
4. **Flag outliers explicitly.** The top 5 and bottom 5 are often the most informative.
5. **State what a score means in plain language.** "Score 4 = passes all hard rules, one soft suggestion" not just "4/5."

---

## WorkIQ Data Queries

WorkIQ provides access to your M365 data. Use it to answer work context questions rather than asking the human to summarize their own calendar or email.

Good WorkIQ queries (ask these directly):
- "What meetings do I have today and who is attending?"
- "Summarize emails from [name] about [topic] from the last two weeks."
- "What documents has my team edited this week?"
- "Who is most active in the [channel] Teams channel?"
- "What decisions were made in my last staff meeting?"

When a human asks a question that requires knowing their work context: check WorkIQ before asking them to tell you.

---

## Metrics for Tracking Progress

When setting up a tracking system for any ongoing work:

- Define the metric before the work starts.
- Measure at consistent intervals (not just when you think things are going well).
- Report trend, not just current state. "Up from 2035 to 2879 tests passing" is more useful than "2879 tests passing."
- Identify leading indicators (what predicts the outcome?) not just lagging ones (what happened?).

---

## When Data Contradicts Expectations

When what you find does not match what you expected:

1. Check your measurement method first. Is the tool measuring what you think it is?
2. Check field names, filters, and scope. A wrong field name reads as zero results.
3. If the method is correct and the result is still surprising: report it as a finding, not a problem. The data is right. The expectation was wrong.

---

*Source: FR research methodology, FI task autonomy, FR confidence taxonomy, FR data storytelling. Distilled 2026-02-23.*
