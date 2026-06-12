---
name: ai-workbench-prompt-engineering
description: "Use this skill whenever the user wants to create, improve, or debug an AI skill, system prompt, agent persona, or copilot-instructions.md. Triggers include: 'write a skill', 'create a SKILL.md', 'improve this prompt', 'why is the AI doing X', 'design a system prompt', 'write an eval', 'test this skill', 'make the AI behave like', 'skill authoring', 'prompt engineering', or any request to build or extend AI behavior. Also use when defining what a skill should and should not do (scope fencing) or creating test cases to verify skill behavior."
# --- AI Workbench provenance (App ignores, manifest uses) ---
# version: 1.0.0
# source: FR
# updated: 2026-06-11
# category: ai-workbench
---

# AI Workbench Prompt Engineering & Skill Authoring

The meta-skill: teaches you how to build, test, and maintain AI skills, system prompts, and agent personas. Use this skill to extend the AI Maker / AI Workbench system itself — or to write high-quality prompts for any AI application.

## When to invoke

Use this skill when you need to:
- Write a new SKILL.md file for AI Maker or AI Workbench
- Improve an existing skill that isn't behaving as expected
- Design a system prompt or `copilot-instructions.md` persona
- Evaluate whether a prompt is producing consistent, reliable outputs
- Debug why an AI is doing something unexpected
- Learn prompt engineering principles to apply in your own work

## What it does

1. **SKILL.md authoring** — writes complete, loadable skill files following the App's discovery format (YAML frontmatter + behavior spec + scope definition)
2. **Prompt design** — structures system prompts with clear persona, scope, constraints, and output format
3. **Eval design** — creates test cases to verify a skill or prompt does what it's supposed to do under normal and adversarial conditions
4. **Iteration loop** — diagnoses why a prompt misfires and rewrites it; compares versions with structured eval
5. **Skill boundary definition** — clarifies what a skill should and should not do, preventing scope creep and user confusion

## Key behaviors

- Shows the work — explains *why* a prompt is structured the way it is, not just what it contains
- Teaches by example — produces working artifacts, not just advice
- Evals-first — before finalizing any skill, produces at least 3 test inputs + expected outputs
- Scope explicit — every skill it writes includes a "Scope" section that names what the skill does NOT handle
- Persona-aware — adapts output to the agent identity being built (manager-facing vs developer-facing)

## Prompt engineering principles applied

- **Instruction clarity** — unambiguous action verbs; no hedging in system prompts
- **Scope fencing** — explicit "not this skill" redirects prevent hallucinated cross-skill behavior
- **Format specification** — output format stated explicitly; AI doesn't guess what you want
- **Persona consistency** — system prompt establishes voice, expertise level, and decision authority
- **Failure mode anticipation** — prompts include guidance for edge cases and ambiguous requests

## Output formats

- Complete SKILL.md file (ready to drop into `~/.copilot/skills/{skill-name}/`)
- System prompt or `copilot-instructions.md` draft
- Eval suite: input → expected output pairs for a skill
- Prompt comparison: before/after rewrite with explanation
- Skill boundary document: what this skill does vs adjacent skills

## Scope

This skill covers AI skill authoring, prompt engineering, and eval methodology. It does not cover general coding tasks, CI/CD pipeline setup, or non-AI automation. For those, use the appropriate technical Workbench skill.
