---
name: ai-workbench-github
description: "Use this skill for GitHub repository operations, branch management, pull requests, GitHub Pages, and git workflows. Triggers include: 'create a repo', 'set up GitHub Pages', 'manage branches', 'PR workflow', 'branch protection', 'merge strategy', 'gh CLI', 'rebase', 'cherry-pick', 'git conflict', 'publish to GitHub', 'release tag', 'repo settings', or any request to work with GitHub as a platform. Do NOT use for GitHub Actions pipeline authoring — use ai-workbench-cicd for that."
# version: 1.0.0 / source: FP / category: ai-workbench
---

# AI Workbench GitHub

Repositories, branches, pull requests, GitHub Actions, and Pages workflows for developers. This skill helps you work effectively with GitHub — from day-to-day git operations to repo administration and platform configuration.

## When to invoke

Use this skill when you need to:
- Create, configure, or administer a GitHub repository
- Manage branches, PRs, and merge strategies
- Set up GitHub Pages for a repository
- Configure repo settings: branch protection, rulesets, required checks
- Understand what a PR, commit history, or diff is actually doing
- Work through a complex git situation (rebase, cherry-pick, conflict resolution)

## What it does

1. **Repository management** — creates repos, sets visibility/topics/description, configures settings via `gh` CLI
2. **Branch and PR workflow** — manages branch strategy, PR creation, review requests, merge approach (squash/merge/rebase)
3. **GitHub Pages** — sets up Pages from a branch or `/docs` folder; configures custom domains and `.nojekyll`
4. **Branch protection** — configures rulesets, required status checks, and merge requirements
5. **Git operations** — handles rebase, cherry-pick, conflict resolution, history rewriting, and tag management
6. **GitHub API** — uses `gh` CLI and REST API for automation: issue creation, label management, release publishing

## Key behaviors

- `gh` CLI first — prefers the `gh` CLI over raw `git` + API calls for GitHub operations
- Destructive-operation confirmation — always describes what a `--force-push` or history rewrite will do before providing the command
- Branch strategy opinionated — recommends trunk-based development with short-lived feature branches
- Merge strategy explicit — explains the difference between merge commit / squash / rebase for each scenario
- Permissions-aware — notes when an operation requires admin or write permission

## Output formats

- `gh` CLI command sequence with explanations
- Branch protection ruleset configuration
- Git command sequence for complex operations (rebase, cherry-pick)
- GitHub Actions workflow integration (triggers, secrets, Pages deploy)
- Repository setup checklist

## Scope

This skill covers GitHub platform operations. For GitHub Actions pipeline authoring specifically, use **AI Workbench CI/CD**. For secrets scanning, use **AI Workbench Security**.
