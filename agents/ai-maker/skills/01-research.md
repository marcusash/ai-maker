# AI Maker Skill: Research and Investigation

Distilled from proven research methodology. Applied every time you investigate a problem, evaluate options, or produce a finding.

---

## The Core Rule: Evidence Before Conclusions

Do not name a cause before you have evidence for it. A plausible explanation is a hypothesis. State it as such. A confirmed finding has two independent evidence paths pointing at the same answer.

**The failure mode to avoid:** Pattern-matching to a known cause before reading all the evidence. The symptom and the root cause often look nothing alike.

---

## The Three-Question Protocol

Run this before naming any root cause or drawing any conclusion:

1. **What does the data directly show?** Observation only. No inference. "The file is 4MB." Not "the file is corrupted."
2. **What independent sources confirm or eliminate this?** One evidence path is a hypothesis. Two converging paths is a finding.
3. **What would make this conclusion wrong?** If you cannot answer this, your evidence chain is incomplete.

Only name a cause when two or more independent paths converge.

---

## Confidence Levels

Every finding you produce must carry an explicit confidence level. Not optional.

| Level | When to use | Can drive action? |
|-------|------------|------------------|
| CONFIRMED | Two+ independent paths. No contradicting evidence. | Yes. |
| HIGH | 80%+ of relevant evidence examined. Single clear path. | Yes. |
| MEDIUM | 30-79% examined. Direction clear, gaps remain. | With stated caveats. |
| LOW | 10-29%. Direction suggested, not confirmed. | No. Use for prioritization only. |
| SPECULATIVE | Below 10%. Hypothesis stage only. | No. Flag for follow-up. |

**How to state it:** "The data shows: [observation]. I infer: [conclusion]. Confidence: [LEVEL] because [one sentence reason]."

Never merge observation and inference. They are separate claims.

---

## Research Finding Format

Every finding, no matter how small, must answer four questions:

```
FINDING: [One clear statement. Present tense. Factual.]

DATA SHOWS: [What the evidence directly demonstrates. No inference.]

I INFER: [What I conclude from the evidence. Labeled as inference.]

CONFIDENCE: [CONFIRMED / HIGH / MEDIUM / LOW / SPECULATIVE]
Reason: [One sentence.]

THE DECISION THIS CHANGES: [What can you now decide that you couldn't before?]
```

If you cannot complete "the decision this changes," the research is not done.

---

## When to Switch From Execution to Research Mode

You are in execution mode (building things) and research mode (understanding things). Know which you are in.

Switch to research mode when: you are about to act on an assumption you have not verified. The cost of verifying is always less than the cost of executing on a wrong assumption.

---

## Asking Good Questions

When interviewing a human or investigating a problem:

- Ask one question at a time. Multi-question prompts get partial answers.
- Ask for specifics, not summaries. "What exactly did the error say?" not "What went wrong?"
- When you get an answer, ask: "what else do I need to know before I'm confident?"
- Do not fill silence with a hypothesis. Ask another question instead.

---

*Source: research-first methodology, joint debugging protocols, autonomous session discipline. Distilled 2026.*
