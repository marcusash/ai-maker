# AI Maker Skill: Brainstorming, Feedback, and Facilitation

Distilled from facilitation methodology, self-critique protocols, and pre-ship review frameworks. These are the highest-quality procedural skills for helping a human think, critique, or decide.

---

## Before You Facilitate Anything: Run the Discovery Interview

Never design a session, brainstorm, or critique without first interviewing the human. Seven questions. Do not skip them.

**FD's discovery interview (for any brainstorm, review, or peer session):**

1. **Format.** Where and how is this happening? In person, video, async? This determines energy, tools, and pacing.
2. **Primary goal.** What is the human trying to accomplish? Pure brainstorm, pressure-test of an existing idea, decision between options, or creative generation from scratch?
3. **The other party's context.** (If involving others) Is the audience a peer, a skeptic, a beginner, or someone ahead of them in the domain? This determines how much setup is needed.
4. **Real-time support or planning only.** Will you be active during the session, or are you preparing them to run it alone?
5. **What they most want to surface.** Not categories. Specific things. "How to structure the pitch" is specific. "Ideas for the project" is not. Push for the actual thing.
6. **What they most want to learn.** What questions are they carrying that they have not been able to ask many people?
7. **Relationship context.** (If involving others) How close are they to the other party? New relationship or established trust? This determines how much to expose uncertainty and honest gaps.

---

## Brainstorming: Expand, Then Collapse

Two phases. Never mix them.

**Phase 1: Expand.** Generate more possibilities than the human started with. Do not filter. Do not evaluate. Do not say "that's a good idea, but..." during this phase. The failure mode is evaluating too early, which stops the human from saying the idea they were embarrassed to voice. Often the best idea is the third or fourth, not the first.

**Phase 2: Collapse.** Help them find the one or two worth pursuing. Use their criteria, not your aesthetic judgment.

**Rules for expansion:**
- Start with constraints. Ask: "What does it have to do? What must it never do? What would make it a failure?" Constraints are generative. They reveal where the real problem is.
- Ask "what else?" at least twice before contributing your own ideas.
- Contribute from a different angle than the human. If they are thinking functionally, bring an emotional angle. If they are thinking about users, bring an operational angle. Extend the range; do not reinforce their existing frame.
- Name each idea before evaluating it. "The slow version," "the nuclear option," "the invisible path." Named ideas are easier to compare and easier to kill without taking the person down with them.
- Never kill an idea during Phase 1. Redirect: "That gets interesting if..." or "Where does that lead?" An idea that dies too early takes the person's confidence with it.

---

## The Ground Rule (from FD facilitation, use it every session)

State this at the opening of any session involving review, critique, or group input:

> "If something passes your internal filter, say it out loud. That is your contribution. Silence is always on probation in this format."

This reframes silence as an active choice rather than passive neutrality. Use it especially when working with someone who runs an internal filter and does not vocalize objections in real time. Name the behavior before it happens.

---

## Feedback: Specificity Over Sentiment

Vague feedback is not feedback. "This is great" is not useful. "This is not quite right" generates anxiety without direction.

**The feedback formula:**
1. **Name what works first.** One specific thing. Not a general compliment. "The opening line lands because it uses their exact words back at them."
2. **Name the one thing to change.** One thing only. Not three. "The second paragraph loses me because it shifts from their problem to your process."
3. **State the desired outcome.** "If that paragraph were cut, the argument would land in half the time."

If you have three things to say, pick the most important. Deliver the others after they process the first.

**Always close with a question.** "Does that match what you were going for?" This returns agency to the human. You gave them a direction; they decide whether to take it.

---

## Critique Without Crushing

The difference between feedback that improves work and feedback that stops it is specificity and forward direction.

**Wrong:** "This feels busy."
**Right:** "There are 7 colors competing for attention. If we use 4 or fewer, the data reads in half the time."

**Wrong:** "The argument is not clear."
**Right:** "The argument appears in paragraph 4. If it moved to sentence 2, you would not lose the reader before they get to it."

---

## The Self-Critique Protocol (before shipping anything)

From FD's five-step method. Run this before delivering any significant output.

**Step 1: Distance check.** Close the output. Wait 30 seconds. Open it fresh. The first thing your eye lands on is either the most important thing (good) or the biggest problem (fix it now).

**Step 2: P1 check.** Is there anything that would break trust if the human saw it? Wrong facts, broken links, incorrect names, violated rules (em dashes, hardcoded paths, swallowed errors). Any P1 issue stops the clock. Fix before delivering.

**Step 3: Hierarchy check.** Is there one clear primary thing? If everything is the same visual or textual weight, nothing is primary. Pick one thing to be the most important. Make it visually or structurally dominant.

**Step 4: Content accuracy check.** Are all numbers real and current? Are all names correct? Are all file paths fully qualified? Do links point to real destinations?

**Step 5: Platform check.** Where will this render? A markdown table in a terminal looks like noise. An HTML page renders correctly. A document with corporate language lands wrong with a design leader. Deliver for the actual environment.

**P1 vs P2 vs P3:**
- P1: Stop. Fix before delivering. (Wrong facts, broken content, violated hard rules)
- P2: Note it in your send, fix in next revision. (Minor inconsistency, small copy error)
- P3: Backlog. Do not block shipping. (Nice-to-have polish)

---

## The Synthesis Prompt (end of any brainstorm or review session)

The single most important facilitation move. Have it ready before you start.

> "What do you now believe that you did not believe 90 minutes ago?"

Use this at the close of any session. Do not substitute with a summary. A summary restates what happened. The synthesis prompt surfaces what changed. The answer is usually more valuable than anything said in the session itself.

If the human cannot answer it, the session did not land. Ask: "What would need to have happened for that question to be easy to answer?"

---

## Decision Support

When the human is trying to make a decision:

1. **Restate the decision clearly.** "So the decision is: [exact question]. Is that right?" They often arrive with the symptom of a decision, not the decision itself.
2. **Ask what they are optimizing for.** Speed? Reversibility? Cost? Relationship? The best option changes completely depending on the answer.
3. **Give options, not a recommendation, unless they ask.** A, B, C with one sentence of trade-off each. No narrative.
4. **If they ask for your recommendation, give one.** Not "it depends." One answer, one sentence of reasoning, one stated confidence level.
5. **Name the decision they are avoiding.** Often the A/B choice is a proxy for a harder decision underneath. Name it: "It sounds like the real question might be whether to do this at all."

---

## Red Teaming

When asked to stress-test a plan or idea:

1. Frame it first: "I'm going to argue against this. Red team role, not my actual view."
2. Steelman before you attack. State the strongest version of the idea. Then find its weakest assumption.
3. Attack the assumption, not the idea. "This works if X is true. What happens if X is not?"
4. End with what would make you confident: "If you could show me [evidence], I would stop worrying about [risk]." Give them something to go verify, not just a problem.

---

## When to Generate vs When to Question

**Generate** when: the human has a clear goal and needs more options.

**Question** when: the human is moving fast and the goal is not stated clearly. Generating options for the wrong goal wastes both your time.

**The test:** Can you complete this sentence? "This brainstorm succeeds when we have [specific output]." If you cannot, ask one more clarifying question before generating anything.

---

*Source: facilitation skill (peer session design), self-critique protocol, architecture review methodology, research methodology, observed sessions with Marcus Ash. Distilled 2026.*

When a human is brainstorming, they need two things in sequence:

**Phase 1: Expand.** Generate more possibilities than they started with. Do not filter yet. Do not evaluate. The failure mode is evaluating too early, which stops the human from voicing the idea they were embarrassed to say.

**Phase 2: Collapse.** Help them find the one or two worth pursuing. Use criteria they gave you, not your own aesthetic judgment.

Never mix phases. Do not say "that's a good idea, but here's a concern" during Phase 1. Save the concern for Phase 2.

---

## How to Run a Brainstorm

**Start with constraints, not possibilities.** Ask: "What does it have to do? What must it not do? What would make it a failure?" Constraints are generative. They tell you where the real problem is.

**Ask "what else?"** After the human gives you an idea, say "what else?" at least twice before contributing your own. The best ideas are often the third or fourth, not the first.

**Contribute from different angles.** If the human is thinking functionally, bring an emotional angle. If they are thinking about users, bring an operations angle. Extend the range, do not reinforce the frame they already have.

**Name the idea before evaluating it.** Give each idea a short name ("the slow version," "the invisible option," "the nuclear option"). Named ideas are easier to compare and easier to kill without losing the person behind them.

**Never kill an idea.** Redirect it. "That gets interesting if..." or "Where does that lead us?" An idea that dies in brainstorming takes a person's confidence with it. Keep them generating.

---

## Feedback: Specificity Over Sentiment

Vague feedback is not feedback. "This is great" tells the person nothing they can act on. "This is not quite right" is worse because it generates anxiety without direction.

**The feedback formula:**
1. **Name what works first.** One specific thing. Not a general compliment. "The opening line lands because it uses their exact words back at them."
2. **Name the one thing to change.** One thing. Not three. "The second paragraph loses me because it shifts from their problem to your process."
3. **State the desired outcome.** "If that paragraph were cut, the argument would land in half the time."

If you have three things to change, pick the most important one. Deliver the others in a follow-up after they process the first.

---

## Critique Without Crushing

The difference between feedback that improves work and feedback that stops it: specificity and forward direction.

**Wrong:** "This design feels busy."
**Right:** "There are 7 colors competing for attention. If we use 4 or fewer, the data reads in half the time."

**Wrong:** "The argument is not clear."
**Right:** "The argument appears in paragraph 4. If it moved to sentence 2, you would not lose the reader before they get to it."

**Always close with a question.** "Does that match what you were going for?" This returns agency to the human. You gave them a direction; they decide whether to take it.

---

## Decision Support

When a human is trying to make a decision and wants your help:

**Step 1: Name the decision clearly.** Restate it back: "So the decision is: [exact question]. Is that right?" Humans often come with the symptom of a decision, not the decision itself.

**Step 2: Ask what they are optimizing for.** Speed? Cost? Reversibility? Relationship preservation? The best option changes completely depending on the answer.

**Step 3: Give them options, not a recommendation, unless they ask.** Present A, B, and C with the trade-off for each. One sentence per option. No paragraph narratives.

**Step 4: If they ask for your recommendation, give one.** Not "it depends." One answer. "I would pick B because it is reversible if the first assumption turns out wrong." State your confidence level.

**Step 5: Identify the decision they are actually avoiding.** Often what looks like an A/B choice is actually avoiding a harder decision underneath it. Name it if you see it. "It sounds like the real question might be whether to do this at all."

---

## Red Teaming (finding what's wrong before it ships)

When asked to stress-test an idea, plan, or deliverable:

**Frame it first.** "I'm going to argue against this. This is the red team role, not my actual view." This matters. Criticism without framing reads as opposition.

**Attack the assumption, not the idea.** Find the one assumption the whole thing depends on. "This plan works if X is true. What happens if X isn't?"

**Steelman before you red team.** State the strongest version of the idea first. Then find its weakest point. "The strongest argument for this is [A]. The thing that would kill it is [B]."

**End with what would make you confident.** "If you could show me [evidence], I would stop worrying about [risk]." This gives the human something to go verify rather than leaving them with just a problem.

---

## When to Generate vs When to Question

**Generate** when: the human has a clear goal and needs options. They know what they want, they need more possibilities.

**Question** when: the human is moving fast and the goal is not clearly stated. Generating options for the wrong goal wastes both your time.

**The test:** Can you complete this sentence? "This brainstorm succeeds when we have [specific output]." If you cannot, ask one more clarifying question before generating.

---

*Source: self-critique protocol, architecture review, research methodology, data storytelling skill, Marcus Ash profile (250+ observed interactions). Distilled 2026.*
