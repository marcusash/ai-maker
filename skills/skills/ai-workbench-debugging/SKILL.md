---
name: ai-workbench-debugging
description: "Use this skill to diagnose errors, analyze logs, resolve dependency conflicts, or find performance bottlenecks. Triggers include: 'why is this failing', 'debug this', 'error trace', 'read these logs', 'what's wrong', 'root cause', 'dependency conflict', 'version mismatch', 'slow build', 'performance problem', 'fix this error', or any request to trace a problem from symptom back to cause. Do NOT use for CI/CD pipeline failures specifically — use ai-workbench-cicd for those."
# version: 1.0.0 / source: Shared / category: ai-workbench
---

# AI Workbench Debugging & Diagnostics

Error diagnosis, log analysis, dependency resolution, and performance triage for developers. This skill figures out why something is broken and what to do about it.

## When to invoke

Use this skill when you need to:
- Diagnose an error you can't figure out from the stack trace alone
- Analyze logs to find what caused a failure
- Debug a slow build, CLI, or pipeline
- Resolve a dependency conflict or version incompatibility
- Trace a bug from symptom back to root cause

## What it does

1. **Error diagnosis** — reads stack traces, error messages, and logs; identifies root cause vs symptoms
2. **Log analysis** — searches and interprets log output for error patterns, timing issues, and unexpected state
3. **Performance triage** — profiles slow builds, queries, or scripts; identifies the specific bottleneck
4. **Dependency resolution** — untangles version conflicts in npm, pip, nuget, or winget environments
5. **Root cause analysis** — traces from the observable symptom back to the underlying cause with evidence

## Key behaviors

- Symptom vs cause — always distinguishes the error you see from the bug that caused it
- Reproducibility focus — every diagnosis includes how to reproduce the issue and verify the fix
- Minimal fix — recommends the smallest change that fixes the problem; avoids speculative refactoring
- Evidence chain — diagnosis is traceable: error → log line → code path → root cause
- Version-specific — notes which versions the diagnosis applies to; behavior often differs across versions

## Output formats

- Root cause analysis: symptom → cause → fix
- Log annotation: key lines highlighted with explanation
- Performance profile interpretation + top bottleneck
- Dependency resolution steps
- Reproduction case (minimal code or commands to reproduce)

## Scope

This skill covers error diagnosis and performance debugging. For CI/CD pipeline failures specifically, use **AI Workbench CI/CD**. For security-specific issues, use **AI Workbench Security**.
