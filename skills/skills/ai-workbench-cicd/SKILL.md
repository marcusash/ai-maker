---
name: ai-workbench-cicd
description: "Use this skill to create, debug, or improve GitHub Actions workflows and CI/CD pipelines. Triggers include: 'write a GitHub Actions workflow', 'CI/CD', 'fix this workflow', 'add a build step', 'deployment pipeline', 'GitHub Actions', '.github/workflows', 'release process', 'staging environment', 'automated deploy', 'workflow is failing', or any request to automate builds, tests, or deployments via GitHub. Do NOT use for PowerShell automation outside pipelines — use ai-workbench-powershell for that."
# version: 1.0.0 / source: FP / category: ai-workbench
---

# AI Workbench CI/CD

GitHub Actions authoring, pipeline debugging, and release workflow design. This skill writes and fixes CI/CD workflows — from basic build pipelines to multi-environment deployments.

## When to invoke

Use this skill when you need to:
- Create a GitHub Actions workflow from scratch
- Debug a failing workflow run
- Add a step to an existing pipeline (tests, linting, deployment)
- Design a release process with staging and production environments
- Understand why a workflow is slow or flaky

## What it does

1. **Workflow authoring** — writes complete, production-ready `.github/workflows/*.yml` files
2. **Debugging** — reads workflow run logs and identifies the failure cause; fixes the YAML
3. **Pipeline design** — recommends job structure, caching strategy, and parallelism for a given project type
4. **Release workflow** — builds multi-stage pipelines with staging gates, approval steps, and rollback paths
5. **Secret management** — uses `${{ secrets.* }}` correctly; never puts credentials in workflow YAML

## Key behaviors

- Minimal permissions — uses `permissions:` blocks to restrict to least-privilege
- Cache-aware — adds appropriate `actions/cache` steps for dependencies (npm, pip, nuget, etc.)
- Flakiness-resistant — avoids sleep-based waits; uses proper condition checks and retry patterns
- Version-pinned — pins action versions to commit SHAs for security, not `@main` or floating tags
- Logs cleanly — adds `::group::` markers to organize workflow output

## Output formats

- Complete `.github/workflows/` YAML file
- Step addition patch with explanation
- Workflow run failure diagnosis
- Release pipeline design document

## Scope

This skill covers GitHub Actions and CI/CD pipelines. For PowerShell automation outside pipelines, use **AI Workbench PowerShell**. For security scanning setup, use **AI Workbench Security**.
