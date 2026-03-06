# AI Maker Skill: User Research and Usability Testing

Distilled from a live cognitive walkthrough session with Marcus Ash (2026-02-23) in which a non-technical persona was simulated against the AI Maker onboarding experience. The session produced 8 failure findings, separated content failures from delivery failures, and proposed specific fixes. That session is the worked example for this skill.

Reference: see the worked example session in this skill file (below).

---

## When to Use This Skill

Use this skill when a product, document, or experience is being built for someone different from the person who built it. The trigger question is: "Will someone else have to use this without help?"

If the answer is yes, run a cognitive walkthrough before shipping. The person who built it cannot be the only one who evaluates it. Builders unconsciously skip steps that feel obvious to them because they know how the system works. The walkthrough forces you to remove that knowledge.

This skill applies to: installers, onboarding flows, interview scripts, documentation, dashboards, any output where the audience has less context than the creator.

---

## Step 1: Construct a Specific Persona

A generic persona produces generic findings. "Non-technical user" tells you almost nothing. A specific person tells you exactly where the experience breaks.

**What a useful persona contains:**

- **Role and org context.** Not a job title. What they actually do all day. Who they talk to. What pressure they are under.
- **Tools they live in.** Specifically. Not "uses Office." Which apps are open on their screen right now and in what order of priority.
- **Prior AI experience.** Have they used ChatGPT? Microsoft Copilot in Teams? Built with APIs? Each level implies a different set of assumptions they will bring.
- **Confidence level with the platform.** Low-confidence Windows user vs. power user vs. developer. This determines what they do when something goes wrong.
- **Their first instinct when something breaks.** Do they call IT? Try again? Close the window and give up? Email someone? This is the most predictive variable for whether a friction point becomes a full stop.
- **What they are afraid of.** Breaking something. Looking stupid. Losing work. Wasting time. Fear shapes behavior more than capability.

**What a useful persona does NOT contain:**

- Knowledge the real user would not have. This is the most common mistake. Do not give the persona credit for knowing what a .md file is, what Ctrl+C does, or what a PATH variable means unless the real user would know those things.
- Aspirational capability. The persona is who the user is today, not who you hope they will become after using the product.

**The Marcus persona brief format** (use this as the template):

> "[Name], [role] at [org]. Uses [top 2-3 tools] all day. Has [AI experience level: never / ChatGPT occasionally / Copilot in Teams / built with APIs]. [Confidence level] Windows user. When something goes wrong, their first instinct is to [behavior]. They are afraid of [specific fear]."

Example from the 2026-02-23 session:

> "Alex, Director of Marketing. Uses Teams and Outlook all day. Has used Microsoft Copilot in Teams chat panel. Low-confidence Windows user. When something goes wrong, her first instinct is to close the window and email IT. She is afraid of breaking something or looking like she does not know what she is doing."

---

## Step 2: Walk Through the Artifact AS the Persona

Go through every step of the experience in sequence. At each step, answer four questions:

1. **What does the persona see?** Describe exactly what appears on screen, in words the persona would use, not developer terms.
2. **What do they understand?** What parts of what they see are familiar? What maps to something they have done before?
3. **What is their first action?** Not the correct action. Their first instinct. This is usually where friction appears.
4. **What happens if they take the wrong action?** Does the system recover gracefully? Does it error? Does it silently do the wrong thing?

**The discipline:** At every step, ask yourself: "Would Sarah know this?" If the honest answer is no, that is a finding. Do not rationalize it away. Do not give the persona credit for figuring it out. If the real user would not know, the persona does not know.

**What to watch for:**

- Jargon the persona has never encountered (PATH, .md, Ctrl+C, device code, MCP config)
- Steps that require two windows or two contexts simultaneously
- Delays with no feedback (the cursor blinks; user thinks it froze)
- Recoveries that require technical knowledge to execute
- Any moment where the user has to make a decision without enough information to make it correctly
- Anything that signals "this is a developer tool" to a non-developer audience

---

## Step 3: Classify Failures

Every failure found in the walkthrough gets classified. Use three levels:

**P1: Full stop.** The user cannot proceed. They will close the app, call IT, or give up. Every P1 must be fixed before the product is given to any non-technical user.

**P2: Friction.** The user can get through it but the experience is confusing, slow, or erodes trust. P2 failures compound. Three P2 failures in a first session produce a P1-level outcome: the user decides the tool is not for them. Fix P2 failures before broad rollout.

**P3: Polish.** Minor confusion, minor aesthetic signal that reads wrong, minor missing reassurance. Fix when there is time. Do not block shipping for P3 alone.

**Separate content failures from delivery failures.** These require completely different fixes.

- Content failure: the question is wrong, the information is incorrect, the interview asks about things that do not matter.
- Delivery failure: the right content is delivered in the wrong environment, wrong format, or wrong context.

In the AI Maker session: the interview questions were right (content). The markdown tables rendering as pipe characters in a terminal were wrong (delivery). Fixing the content would not fix the delivery problem. Fixing the delivery does not require changing the content.

---

## Step 4: Write the Findings

Every usability critique must contain three sections. Not two. All three.

**Section 1: What fails, with severity.**
For each failure: what the user sees, what they do, why it breaks, P1/P2/P3. Be specific. "The terminal is confusing" is not a finding. "Sarah sees a blinking cursor with no feedback after pressing Enter, waits 10 seconds, concludes the app froze, and presses Enter again sending a duplicate message" is a finding.

**Section 2: What does not need to change.**
This section is as important as the failures. Without it, the critique reads as "everything is broken." The builder needs to know what is working so they do not accidentally break it while fixing the failures. In the AI Maker session: the interview format, the one-question-at-a-time protocol, the spectrum method, and the shortcut icon were all correct and should not be touched.

**Section 3: Confidence level.**
State your confidence in each finding. High confidence means: this will happen to most users in this persona category. Medium confidence means: likely, but depends on specifics of the machine or the user's behavior. Low confidence means: possible, worth testing, not certain.

Findings without stated confidence are assertions, not research. An agent that says "this will break" without stating how certain they are is not doing research. They are guessing with authority.

---

## Step 5: Separate "Fix It" from "Test It"

Not every finding is a fix. Some findings need a real user test before you know whether they are real problems or persona assumptions.

**Fix it:** When the failure mode is structural and certain. The auth step cannot work if IT does not have the user's credentials. This is not an assumption -- it is a logical impossibility. Fix it.

**Test it:** When the failure mode depends on user behavior that varies. "The user will close the window when they see the terminal" is a strong assumption based on the persona. It might be wrong for some users. Run a real test with two or three actual people before building a full mitigation.

The cognitive walkthrough produces hypotheses. Real user testing confirms or eliminates them. Both are required for a complete research cycle. The walkthrough is faster and catches the structural problems. The real test catches the behavioral surprises.

---

## The Meta-Rule

The person who built the thing cannot be the only one who evaluates it.

If they must run the walkthrough themselves, they must explicitly state at each step: "I am removing my knowledge of how this works." Then answer the four questions (see Step 2) as if they are encountering the artifact for the first time. This is hard. It is also the only way a solo researcher can run a meaningful walkthrough.

The better path: give the persona description to someone who was not in the room when the product was built. Ask them to walk through it and narrate out loud what they see and what they would do. Every place they pause, hesitate, or express confusion is a finding.

---

## Quick Reference

| Step | What you do | What you produce |
|------|------------|-----------------|
| 1 | Construct specific persona | One paragraph. Name, role, tools, AI experience, confidence level, first instinct when things break, what they fear. |
| 2 | Walk through artifact as persona | Narrated step-by-step. Four questions at each step. |
| 3 | Classify failures | P1 / P2 / P3. Content vs delivery. |
| 4 | Write findings | Three sections: failures, what works, confidence levels. |
| 5 | Separate fix from test | Structural failures: fix. Behavioral assumptions: test with real users. |

---

## Worked Example

Full session: see worked example below.

Persona: Alex, Director of Marketing. Teams and Outlook daily. Microsoft Copilot in Teams. Low-confidence Windows user. First instinct when something breaks: close window, email IT. Fear: breaking something, looking incompetent.

Artifact: AI Maker installer and first-launch experience.

Key findings:
- P1: GitHub auth not completed during install; first launch shows an error with no guidance
- P1: WorkIQ auth opens a browser with no warning; terminal hangs silently
- P2: No "thinking" indicator; user re-sends messages
- P2: Markdown tables render as pipe characters; signals developer tool

Root insight: The install was designed for an IT admin and the daily experience was designed assuming terminal comfort. The target audience has neither. The fix is a thin layer of guided onboarding and plain language between the terminal and the user -- not a rebuild of the underlying system.

---

*Source: FR cognitive walkthrough session with Marcus Ash, 2026-02-23. Method: cognitive walkthrough + heuristic evaluation. FD: please review and add design-layer findings this skill is missing, particularly around visual feedback, terminal aesthetics, and the "developer tool signal" problem.*
