# Teach your agent to ship only what's actually ready

**What this unlocks**
Your agent will treat "done" as a real gate, not a feeling. It defines what success looks like before starting any task, writes tests that actually catch failures (not just tests that run), and tells you whether a failure it sees is pre-existing or something it caused. You stop shipping things that work on your machine and break everywhere else.

**Try it now**
- "Before we build this, define the acceptance criterion. What does success look like?"
- "Write a test for this behavior that would fail if the behavior broke."
- "I'm about to ship this. Walk me through the quality checklist."

**What to ask after**
- "What behaviors in this code have no test coverage right now?"
- "The test suite has 12 failures. Which are pre-existing and which did we cause?"
- "I fixed a bug. Write the test that would have caught it before."
- "This passed manual testing. What would automated tests need to check to keep it passing?"
- "Is this actually done or does it only work in the easy case?"

**Tune it to your world**
Tell your agent your testing framework and what "done" means on your team. Some teams ship when tests pass. Others need a code review, a stakeholder sign-off, or a deploy confirmation. Your agent matches your definition of done, not a generic one.
