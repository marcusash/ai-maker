---
name: ai-workbench-security
description: "Use this skill to audit code for secrets, set up pre-commit hooks, or harden a GitHub Actions workflow or deployment config. Triggers include: 'scan for secrets', 'credential audit', 'API key leaked', 'pre-commit hook', 'secrets in git history', 'security review', 'harden this workflow', 'dependency vulnerabilities', 'npm audit', 'security checklist', or any request to find and fix security problems in code, configs, or pipelines. Does NOT cover runtime security, network security, or penetration testing."
# version: 1.0.0 / source: FP / category: ai-workbench
---

# AI Workbench Security

Credential audits, secrets scanning, and security hardening for developers. This skill finds and fixes security problems in code, configs, and pipelines — before they become incidents.

## When to invoke

Use this skill when you need to:
- Audit a codebase or repo for accidentally committed secrets or credentials
- Set up pre-commit hooks to prevent secrets from being committed
- Review a PR or deployment config for security issues
- Harden a GitHub Actions workflow or cloud configuration
- Assess the security posture of a project before a release

## What it does

1. **Secrets scanning** — searches code, configs, and git history for API keys, passwords, connection strings, and tokens
2. **Pre-commit hooks** — installs and configures `detect-secrets`, `gitleaks`, or `git-secrets` to prevent future leaks
3. **Workflow hardening** — reviews GitHub Actions for insecure patterns: `pull_request_target`, `GITHUB_TOKEN` overscope, unvalidated inputs
4. **Dependency audit** — runs `npm audit`, `pip-audit`, or equivalent and summarizes critical findings
5. **Security review** — structured review of a PR or config file for authentication, authorization, injection, and data exposure issues

## Key behaviors

- Finds before fixing — always shows what it found before recommending changes
- History-aware — knows that removing a secret from current code doesn't remove it from git history; provides `git filter-repo` guidance
- Severity-ranked — critical (exposed keys) → high (insecure patterns) → medium (hardening gaps) → info
- No false confidence — notes what this scan does NOT cover (runtime security, infra, pentest)

## Output formats

- Secrets audit report with file/line/severity
- Pre-commit hook setup instructions
- Workflow security review
- Dependency vulnerability summary with recommended versions

## Scope

This skill covers static secrets scanning and security hardening for code and pipelines. It does not cover runtime security, network security, or penetration testing.
