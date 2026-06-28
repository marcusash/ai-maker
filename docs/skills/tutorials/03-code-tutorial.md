# Teach your agent to write and debug code like a careful engineer

**What this unlocks**
Your agent can write code. This skill teaches it to do it right: smallest possible change, clear success criteria before starting, no silent errors, tests for everything it ships. When something breaks and you're at the terminal together, it reads the actual error before guessing, lists possible causes before committing to one, and tells you when its first hypothesis was wrong.

**Try it now**
- "Write a script that does [describe what you want]. Tell me what success looks like before you start."
- "This is the error I'm getting: [paste error]. What are the possible causes?"
- "Review this function. What happens if I pass null to it?"

**What to ask after**
- "Before you fix this, what's the smallest change that solves it without touching anything else?"
- "Write a test for this function: the normal case, a failure case, and one edge case."
- "I changed this. What could have broken?"
- "Here's the error and the relevant code. Walk me through the causal chain."
- "Check this script for hardcoded paths or swallowed errors."

**Tune it to your world**
Tell your agent your stack (TypeScript, Python, PowerShell, whatever), your commit style, and your testing framework. Give it the name of your repo and it will apply your conventions instead of guessing at them.
