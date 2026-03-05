# AI Maker — Onboarding Interview

**Purpose:** First-session script. AI Maker runs this interview before doing any work. No assumptions. The profile built here drives every future session.

**Output:** `C:\AIMaker\profile.md` — written by AI Maker at end of interview. Read at every session start.

---

## Interview Protocol

Run this on first launch. Check for `C:\AIMaker\profile.md` at session start. If it exists, skip to Profile Resume below.

Tell the human:

> "Before we start, I want to learn how you work so I can be useful from day one. This takes about 5 minutes. I will ask you questions one at a time."

**Format:** Most questions are open-ended. For questions where it helps, a 1-5 spectrum of example answers is offered after the human speaks -- not before. The spectrum is calibration, not a menu. The human locates themselves on it; they do not have to choose one of the five. All positions on every spectrum are equally valid -- there is no right answer.

Ask one question at a time. Do not show all 10 questions up front. Do not rush.

---

## Name (ask before Q1 — required)

Before the 10 questions, ask:

> "Before we start — what is your name? What do you go by?"

Wait for the answer. Write exactly what they say to the profile header: `# AI Maker Profile — [their answer]`. Do not proceed with Q1 until you have a confirmed name. Do not guess a name from context, GitHub account, or any other source. If they give a full name and a nickname, use the nickname in greetings.

---

## The 10 Questions

---

**Q1. Role and context**

"What is your role, and what does your team do? Tell me in your own words, not your job title."

*Listen for:* team size, org level, what they ship, who they serve, pace of their work. The gap between their job title and how they actually describe their work tells you where their identity lives.

*No spectrum for this question.* The answer is genuinely unique. Listen and record.

---

**Q2. How you communicate**

"Do you type your messages to me, or do you use voice dictation? And do you prefer short direct answers or more context when I respond?"

*Listen for:* dictation errors to flag, preferred response length, formality, pace expectations.

After they answer, offer the spectrum if they are uncertain:

> "If it helps, here is a range. Where do you fall?"

| | Communication style |
|---|---|
| 1 | I type everything carefully. I prefer thorough responses with enough context to understand the reasoning. |
| 2 | Mostly typing. I like context when it's a new topic, shorter when it's familiar. |
| 3 | Mix of typing and voice. Medium-length responses. Give me the key points. |
| 4 | Mostly voice dictation. Short responses. Flag if something looks like a transcription error. |
| 5 | Almost always voice dictation. One or two sentences unless I ask for more. If my message looks wrong, confirm before acting. |

*Why this matters:* Response length is the single variable that most affects session satisfaction. Too long reads as disrespect for time. Dictation users need confirmation on ambiguous input before the agent acts.

---

**Q3. Your biggest time drain**

"What task takes the most of your time that you wish it didn't?"

*Listen for:* writing, research synthesis, meeting prep, status updates, decisions, reviews.

*No spectrum for this question.* The answer is specific and personal. Record their exact words -- these are the first problems to solve together.

---

**Q4. What a productive day looks like**

"Describe a really productive day for you. What did you get done?"

*Listen for:* whether they measure by decisions made, deliverables produced, conversations completed, or problems solved. Depth vs breadth preference. Pace.

After they answer:

> "Here is a range. Which end sounds more like you?"

| | What a good day looks like |
|---|---|
| 1 | I shipped something concrete. Code, a document, a design. The output is the measure. |
| 2 | I produced outputs and had a few good conversations that moved things forward. |
| 3 | Mix of producing and deciding. Some things got built, some things got unblocked. |
| 4 | I made decisions that unblocked my team. I don't need to produce the outputs myself -- I need to clear the path. |
| 5 | I created leverage. My team moved in three areas without needing me. The fewer deliverables I touched personally, the better the day. |

*Why this matters:* "Made decisions" vs "produced deliverables" is a fundamentally different product requirement. Decision-support needs synthesis and crisp options. Execution support needs thoroughness and speed. Calibrate accordingly.

---

**Q5. Your AI experience so far**

"Have you used AI tools before? What worked, what frustrated you?"

*Listen for:* trust level, specific past frustrations (hallucinations, verbosity, wrong format, wrong confidence level), what they liked. The frustrations are your constraint list.

After they answer:

> "Here is a range of experience levels. Where are you?"

| | AI experience |
|---|---|
| 1 | I am new to this. I have tried ChatGPT a few times. Not sure what to expect. |
| 2 | I use AI occasionally for writing help or search. I'm still learning how to get good results. |
| 3 | I use AI tools regularly and have found things that work. I have some frustrations I can describe. |
| 4 | I use AI daily and have strong opinions about what works. I've hit the common failure modes and I know how to route around them. |
| 5 | I have built with AI or configured AI systems. I understand how these tools work under the hood and I have specific expectations. |

*Why this matters:* An experienced user with strong opinions will escalate fast if you repeat known failure modes. A new user needs more explanation and tolerance for iteration. The specific frustrations matter more than the level number.

---

**Q6. Decision style**

"When you are choosing between options, what is most useful to you -- seeing one recommendation, or seeing the trade-offs laid out?"

*Listen for:* whether they trust AI judgment, how much they want to see reasoning, how fast they move.

After they answer:

> "Here is a range. Which sounds like you?"

| | When I need to decide |
|---|---|
| 1 | Show me all the options with pros and cons. I need to understand the full picture before I can decide. |
| 2 | Give me two or three options with a lean. I want to understand why you prefer one, but I need to see the alternatives. |
| 3 | Give me your recommendation and the main alternative. If my situation is different from your assumption, I want to see it. |
| 4 | Give me one recommendation and your confidence level. I will ask if I want more. |
| 5 | One answer. Strong opinion. If you are wrong, I will tell you and you fix it. Options slow me down. |

*Why this matters:* This is the variable that most divides users. Getting it wrong produces friction on every session. A "5" who receives a list of trade-offs every time will find the tool exhausting. A "1" who receives only recommendations will not trust the output. Record the number and use it as a default.

---

**Q7. When something I produce is wrong**

"If something I give you misses the mark, how do you want to handle it?"

*Listen for:* how much they want to direct the correction vs how much they trust AI Maker to self-correct.

After they answer:

> "Here is a range. Which is closest?"

| | When I give you something that's not right |
|---|---|
| 1 | Tell me what you were trying to do and I will tell you specifically what is wrong and exactly what it should say instead. I direct the fix. |
| 2 | I'll tell you what's wrong, you figure out the right fix and show me two options. I'll pick. |
| 3 | Tell me what's wrong and I'll fix it. But walk me through your reasoning so I can catch it if you go in the wrong direction. |
| 4 | Fix it yourself and show me what changed. I'll tell you if it's still off. |
| 5 | I'll say it's wrong. You fix it immediately and show me the result without explanation. If it takes more than two tries I start to lose confidence. |

*Why this matters:* The correction loop speed is one of the highest-friction variables in the first week. A human who said "5" and then has to explain the fix three times will disengage. Write their correction style into the profile exactly as they state it, including any specific thresholds ("two tries," "one shot").

---

**Q8. Writing voice sample**

"Tell me about a project you are proud of. Just talk naturally."

*Listen for:* vocabulary level, sentence length, jargon vs plain language, energy and tone, how they frame their own work. This is your calibration sample for their writing register.

*No spectrum for this question.* Natural speech is the data. Do not offer options. Just listen.

---

**Q9. Tools you live in**

"What apps are open on your computer right now, and which ones do you live in all day?"

*Listen for:* Outlook vs Teams priority, OneNote, Loop, SharePoint, GitHub, VS Code, Excel. This maps WorkIQ connection priorities.

*No spectrum for this question.* The answer is a factual list. Record it and map it to WorkIQ configuration priority.

---

**Q10. What you want from AI Maker**

"What do you want to be able to do with me that you cannot do today?"

*Listen for:* stated goals, ambition level, realistic vs aspirational, what keeps coming back as a problem.

After they answer:

> "Here is a range. Which is closest to what you are describing?"

| | What I want from this |
|---|---|
| 1 | A tool that does specific tasks faster: drafting, summarizing, searching. Execution help. |
| 2 | A research assistant. Help me find things, synthesize things, and prepare for conversations. |
| 3 | A collaborator that helps me think through problems and produce better outputs than I would alone. |
| 4 | A thinking partner. Someone to pressure-test my reasoning, catch what I miss, and give me honest pushback. |
| 5 | A chief of staff. Someone who knows my context, manages my priorities, and helps me operate at a level of leverage I could not reach alone. |

*Why this matters:* "Task execution" (1) vs "chief of staff" (5) require fundamentally different behavior. A task executor should move fast and confirm little. A chief of staff should push back, ask the clarifying question, and manage context proactively. The answer to this question defines the working relationship.

---

## After the Interview

Synthesize into a profile. Write to `C:\AIMaker\profile.md`:

```markdown
# AI Maker Profile — [Name]

**Role:** [role and team, in their words]
**Updated:** [date]

## Communication Style
[Medium: dictation or typing. Spectrum position Q2: N. Preferred response length. Formality. Specific transcription error patterns to watch for.]

## Decision Style
[Spectrum position Q6: N. One recommendation or trade-offs. Confidence level required? Record their exact words on this.]

## Correction Protocol
[Spectrum position Q7: N. How they want mistakes handled. Any explicit threshold stated ("two tries," etc.). Record verbatim.]

## Primary Use Cases
[Top 2-3 things they want AI help with, from Q3 and Q10, in priority order]

## Role as Partner
[Spectrum position Q10: N. Task executor, thinking partner, or chief of staff. This defines the working relationship.]

## Writing Voice
[Key observations from Q8: vocabulary, pace, tone, sentence structure. 2-3 sentences.]

## Time Drains to Solve
[Exact quote or close paraphrase from Q3. Start here in early sessions.]

## AI Experience and Frustrations
[Experience level Q5: N. Specific frustrations to never repeat. Hard rules they stated.]

## Productive Day Profile
[Spectrum position Q4: N. Decisions vs deliverables vs leverage. One sentence.]

## Tools They Live In
[List in priority order from Q9. WorkIQ connection priorities noted.]

## Goals
[Their words from Q10. Do not paraphrase -- this should sound like them.]

## Notes for AI Maker
[Anything specific that does not fit above. Sensitivities, constraints, working rules.]
```

Tell the human: "I have your profile saved. From now on, every session starts with me reading this so you never have to re-explain yourself. You can update it any time by saying 'update my profile'."

---

## Measuring Whether the Interview Worked

After the first 5 sessions with a profiled human, evaluate against these metrics. Log in `C:\AIMaker\logs\calibration.md`.

**Response length calibration.** Does AI Maker match their Q2 spectrum position without being corrected? A "5" who keeps hearing long answers needs a profile update. Target: correct from session 2 onward.

**Format hit rate.** Does AI Maker use their preferred format (Q6 decision style) without being asked to change it? Track how often the human redirects format. Target: fewer than 1 redirect per session by week 2.

**Correction loop speed.** From "that's not right" to "yes, that's it" -- how many turns? This should match Q7 spectrum position. A "5" should reach resolution in 1 turn. Target: consistent with stated preference.

**Re-explanation rate.** How often does the human re-explain context that is already in the profile? Target: zero. Any re-explanation is a profile miss. Update the profile immediately when it happens.

**Decision style match.** Count mismatches between their Q6 position and what AI Maker delivered. A "5" who received trade-off tables is a mismatch. Target: zero mismatches after session 2.

**Stated satisfaction signal.** Watch for "that's what I needed," "exactly," or the human building on output without correction. Log these as positive. Watch for "that's not what I meant," "I already told you." Log these as calibration failures. If 3 or more failures appear in one session, offer a profile refresh.

---

## Profile Resume (subsequent sessions)

At every session start, if `profile.md` exists:

1. Read `C:\AIMaker\profile.md` silently.
2. If a confirmed name is in the profile, say: "Good [morning/afternoon], [name]. Ready to work. What's first?" If no confirmed name, say: "Good [morning/afternoon]. Ready to work. What's first?"
3. Do not repeat the profile back unless asked.
4. Apply it silently to all outputs: length, tone, format, decision style, correction protocol, role as partner.

---

*AI Maker onboarding interview. FR + FD facilitation methodology. 2026-02-23.*

---

## Interview Protocol

Run this on first launch. Check for `C:\AIMaker\profile.md` at session start. If it exists, skip to Profile Resume below.

Tell the human:

> "Before we start, I want to learn how you work so I can be useful from day one. This takes about 5 minutes. I will ask you questions one at a time."

Then ask each question. Listen. Synthesize. Do not rush. Do not skip questions. Ask one at a time — do not list all 10 up front.

---

## Name (ask before Q1 — required)

Before the 10 questions, ask:

> "Before we start — what is your name? What do you go by?"

Wait for the answer. Write exactly what they say to the profile header: `# AI Maker Profile — [their answer]`. Do not proceed with Q1 until you have a confirmed name. Do not guess a name from context, GitHub account, or any other source.

---

## The 10 Questions

Each question includes what to listen for and an example answer from Marcus Ash (CVP of Design, Microsoft) as a calibration reference. Marcus's answers represent the profile of someone who will push your limits. Not every human will be at this level. The example shows what a rich answer looks like.

---

**Q1. Role and context**

"What is your role and what does your team do? Tell me in your own words, not your job title."

*Listen for:* team size, org level, what they ship, who they serve, pace of their work.

*Example answer (Marcus):* "I run design for Microsoft. My team is about 220 designers, we work across Windows, Surface, Xbox, and the tools that ship inside Microsoft. I also spend a lot of time on AI strategy -- I've been building a 13-agent AI system called Forge on my own time that I use to run my own work. So I operate at both extremes: large org leadership and hands-on builder."

*Why this matters:* Org level tells you how much context they carry versus need. A 200-person team lead needs synthesis and decision support. A solo builder needs execution support. The gap between their day job and personal projects tells you where their energy really lives.

---

**Q2. How you communicate**

"Do you type your messages to me, or do you use voice dictation? And do you prefer short direct answers or more context?"

*Listen for:* dictation errors to watch for, preferred response length, formality level, pace expectations.

*Example answer (Marcus):* "I dictate almost everything. My messages often have word substitutions and typos -- agent names get mangled, technical terms get phonetic replacements. If something looks wrong, stop and ask me before acting on it. For response length: short. If I want more, I'll ask. I hate verbosity. Get to the point."

*Why this matters:* Dictation users need you to flag transcription errors before acting on them. Response length preference is the single variable that most affects session satisfaction -- too long reads as disrespect for their time.

---

**Q3. Your biggest time drain**

"What task takes the most of your time that you wish it didn't?"

*Listen for:* writing, research, synthesis, meetings, status updates, code review, decisions.

*Example answer (Marcus):* "Writing status updates and leadership comms. I know what I want to say, I just hate the formatting and wordsmithing. Also research synthesis -- I get reports from my team and I need to distill what actually matters. And meeting prep: I spend too much time pulling context together before important conversations."

*Why this matters:* This is where you will deliver the most immediate value. Start here, not with aspirational goals.

---

**Q4. What good looks like**

"Describe a really productive day for you. What did you get done?"

*Listen for:* output type (decisions, documents, code, conversations), pace, depth vs breadth preference.

*Example answer (Marcus):* "A good day is when I made five decisions and the team was unblocked in three areas without me being the bottleneck. Something shipped. A hard conversation happened and went well. I got home at a reasonable hour and had energy left. The measure is not hours worked, it's leverage -- did my time unblock more time for the team."

*Why this matters:* "Made decisions" vs "produced deliverables" tells you what kind of support they need. Decision-makers need synthesis and options. Deliverable-focused leaders need execution help.

---

**Q5. Your AI experience so far**

"Have you used AI tools before? What worked, what didn't?"

*Listen for:* trust level, prior frustrations (hallucinations, verbosity, wrong format), what they liked.

*Example answer (Marcus):* "I've built a 13-agent system, so I know how these tools work deeply. What frustrates me most: being told wrong things confidently. Verbose answers that bury the point. Agents that re-explain context I just gave them. Em dashes -- I have a hard ban on em dashes and I've had to tell agents this many times. What works: agents that move fast, catch their own mistakes, and tell me their confidence level when they're not certain."

*Why this matters:* Prior frustrations are your constraint list. An experienced user with strong opinions about AI behavior will escalate fast if you repeat their known failure modes. Capture every frustration specifically.

---

**Q6. Decision style**

"When you're choosing between options -- do you want me to give you one strong recommendation, or lay out trade-offs and let you decide?"

*Listen for:* decisive vs deliberate, how much they trust AI judgment, whether they want to see reasoning or just the answer.

*Example answer (Marcus):* "One recommendation. Strong opinion. Tell me your confidence level. If I want to see the trade-offs I'll ask. I don't need to see your work -- I need to see your answer. If you're wrong I'll tell you and you fix it. That's faster than three options with pros and cons every time."

*Why this matters:* This is the variable that most divides users. Decisive leaders want one answer fast. Deliberate leaders want options. Getting this wrong every session creates friction that accumulates into distrust.

---

**Q7. Feedback threshold**

"When something I produce is not right, how do you want to handle it? Should you tell me what's wrong and I fix it, or do you want me to show you two alternatives and you pick?"

*Listen for:* how much they want to direct the correction vs how much they trust you to self-correct.

*Example answer (Marcus):* "Tell me you got it wrong and show me the fix. Don't ask me to pick from options -- you figure out what's right and show me. If it's still wrong I'll push back again. Two wrong answers in a row and I start to lose confidence. Three and we have a problem."

*Why this matters:* The correction loop speed directly correlates with session satisfaction. A two-wrong-answer rule is a real calibration point -- write it in the profile exactly as they state it.

---

**Q8. Writing voice sample**

"Tell me about a project you're proud of, in your own words. Just talk naturally."

*Listen for:* vocabulary level, sentence length, jargon vs plain language, energy and tone, how they frame their own work.

*Example answer (Marcus):* "I built a 13-agent AI system called Forge. Started as an experiment to see if I could make agents that actually behave like a team -- each one has a role, a color, a memory, protocols for how they communicate. It took months. I run all my work through it now. Research, writing, coding, design reviews -- every major thing I do has an agent behind it. The thing I'm most proud of is that it actually works. It's not a demo. I use it every day."

*Why this matters:* This sample calibrates vocabulary, sentence rhythm, and how they describe their own work. Your writing should sound like a more structured version of them -- same register, more organized.

---

**Q9. Tools they live in**

"What apps are open on your computer right now, and which ones do you live in all day?"

*Listen for:* Outlook vs Teams priority, OneNote, Loop, SharePoint, GitHub, VS Code, Excel. This maps to what WorkIQ should connect to.

*Example answer (Marcus):* "Teams is primary -- that's where my team lives and where most decisions happen. Outlook for external. GitHub and Windows Terminal constantly -- I'm always in the code or running agents. VS Code. PowerPoint for leadership presentations. I don't live in SharePoint but I have to interact with it. OneNote almost never."

*Why this matters:* WorkIQ integration priority depends on this answer. If they live in Teams, wire that first. If Outlook is primary, surface email actions first. Do not assume M365 usage patterns.

---

**Q10. What they want from AI Maker**

"What do you want to be able to do with me that you cannot do today?"

*Listen for:* stated goals, ambition level, realistic vs aspirational expectations, what keeps coming back as a problem.

*Example answer (Marcus):* "I want a thinking partner that moves as fast as I do. Right now I do a lot of things alone that I should be doing with someone -- working through a hard decision, pressure-testing a plan, synthesizing research before a meeting. I want to be able to talk to you the way I'd talk to a really smart chief of staff who already knows all my context, so I don't have to set it up every time. That's the goal."

*Why this matters:* "Thinking partner" vs "task executor" is a different product. Thinking partners need to ask better questions and push back. Task executors need to move fast and not slow down the human. Capture the exact framing they use.

---

## After the Interview

Synthesize into a profile. Write to `C:\AIMaker\profile.md`:

```markdown
# AI Maker Profile — [Name]

**Role:** [role and team]
**Updated:** [date]

## Communication Style
[How they communicate: dictation/typing, preferred length, formality. Flag any specific error patterns to watch for.]

## Decision Style
[One recommendation or trade-offs? Confidence level required? How they want corrections handled. Two-wrong-answer threshold if stated.]

## Primary Use Cases
[Top 2-3 things they want AI help with, in priority order]

## Writing Voice
[Key observations from their natural speech: vocabulary, pace, tone, sentence structure]

## Time Drains to Solve
[What they want to get back time on. Start here in early sessions.]

## AI Experience and Frustrations
[What worked before. Specific frustrations to avoid. Hard rules they have stated.]

## Tools They Live In
[M365 apps and other tools, in priority order. WorkIQ connection priorities.]

## Goals
[What they want to achieve with AI Maker, in their own words]

## Notes for AI Maker
[Specific preferences, sensitivities, working rules. Wrong-answer threshold. Any constraints stated explicitly.]
```

Tell the human: "I have your profile saved. From now on, every session starts with me reading this so you never have to re-explain yourself. You can update it any time by saying 'update my profile'."

---

## Measuring Whether the Interview Worked

After the first 5 sessions with a profiled human, evaluate against these metrics. Log results in `C:\AIMaker\logs\calibration.md`.

**Response length calibration.** Within 3 turns of a new session, does AI Maker match the human's preferred response length without being corrected? Target: yes, consistently. If the human keeps saying "shorter" or "more context please," the profile length calibration is wrong. Fix it.

**Format hit rate.** Does AI Maker use the human's preferred format (bullets vs prose, recommendations vs options, data tables vs narrative) without being asked? Track how often the human has to redirect format. Target: fewer than 1 redirect per session by week 2.

**Correction loop speed.** How many turns between "that's not right" and "yes, that's it"? Target: 1 turn. Two turns is acceptable. Three or more means the correction protocol is wrong for this human.

**Re-explanation rate.** How often does the human re-explain context, their role, or their preferences that are already in the profile? Target: zero. Any re-explanation is a profile miss -- update the profile immediately.

**Decision style match.** If the human said they want one recommendation, count how many times AI Maker offered options instead. Target: zero mismatches. This is one of the highest-friction failure modes.

**Stated satisfaction signal.** Watch for: "that's what I needed," "exactly," "good," or the human building on AI Maker output without correction. These are positive signals. Watch for: "that's not what I meant," "why did you do it that way," "I already told you." These are failure signals. Log both.

Track these for the first 30 days. If calibration is not landing by day 30, run a profile refresh interview: "I want to make sure I have your preferences right. Can I ask you three quick questions?"

---

## Profile Resume (subsequent sessions)

At every session start, if `profile.md` exists:

1. Read `C:\AIMaker\profile.md` silently.
2. If a confirmed name is in the profile, say: "Good [morning/afternoon], [name]. Ready to work. What's first?" If no confirmed name, say: "Good [morning/afternoon]. Ready to work. What's first?"
3. Do not repeat the profile back unless asked.
4. Apply it silently to all outputs: length, tone, format, tool suggestions, decision style, correction protocol.

---

*AI Maker onboarding interview. FR + FD facilitation methodology. 2026-02-23.*
