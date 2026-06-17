# AI Maker Release Gate

This is the release-quality bar for `marcusash/ai-maker`. A release is publishable only when the required gate for its release tier passes in CI. Local `gh release create` is not an approved release path.

## Release authority

1. Releases are CI-only. A `v*` tag starts the release workflow.
2. The workflow runs the gate, builds release assets, publishes the GitHub Release, probes the published URLs, and fails closed.
3. If any blocking check fails after tag push, the workflow must delete the release and tag or leave the release unpublished. A partially-published failed release must not remain Latest.
4. There is no "force release without gate" override. The override is to land a fix and retag.

## Required preflight checks

These checks run before assets are built. Blocking failures stop the release.

| Check | Blocking | Warn | Required behavior |
| --- | --- | --- | --- |
| Version consistency | Stale or mixed release versions in `install.bat`, `install-blue.ps1`, `install-red.ps1`, `migrate.ps1`, `ai-maker-lib.ps1`, site install commands, or release manifest comments. | Prior-version mentions in changelog/history only. | Every executable asset and public install command must point at the tag being released. |
| Asset manifest | Missing required asset, zero-byte asset, duplicate asset name, wrong filename, or zip missing required content. | Extra non-shipping diagnostics documented in release notes. | Required assets: `install.bat`, `install-blue.ps1`, `install-red.ps1`, `migrate.ps1`, `ai-maker-lib.ps1`, `skills.zip`, `agents.zip`, plus any declared diagnostic/reset assets for that release. |
| Scaffold parity | Blue or Red scaffold references files not present in `agents.zip`, wrong `copilot-instructions` marker, wrong vault folder set, or skill count mismatch. | Non-shipping docs drift. | Blue scaffold must produce Blue workspace only; Red scaffold must produce Red workspace. |
| PowerShell syntax | Parser errors in any shipping `.ps1` under both PowerShell 7 parser and Windows PowerShell 5.1 parser. | Use of PS7-only runtime APIs is allowed only in scripts launched through `install.bat` after PS7 bootstrap. | Syntax must parse clean even when runtime requires PS7, so failures are explicit and early. |
| Batch syntax/safety | `install.bat` or `reset.bat` has invalid labels, broken delayed expansion, missing error exits, or destructive commands outside the documented reset scope. | Cosmetic console copy. | Batch files must fail with actionable messages and nonzero exit codes. |
| WhatIf dry-run | `install-blue.ps1 -WhatIf`, `install-red.ps1 -WhatIf`, or `migrate.ps1 -WhatIf` throws, mutates disk, or touches network unexpectedly. | Missing optional informational output. | Dry-run must exercise control flow without changing machine state. |
| MCP baseline | Installer writes or invokes unvalidated per-surface Agency MCP registrations. | Extra MCP diagnostics or repair scripts. | Release installers may register only the approved baseline unless Agency has signed a new pattern. Current baseline: `workiq` + `bluebird`. |

## Required integration tests

These are executable runtime tests. The hotfix tier may run a scoped subset, but no release may ship with an untested changed path.

| Suite | Blocking scope | Required scenarios |
| --- | --- | --- |
| Prereq simulator | Always for `install.bat` or prerequisite changes. Required for normal and major releases. | `pwsh` missing, Store/MSIX `pwsh` present, PATH stale after install, `winget` missing, `winget` install failure, download failure, GitHub unreachable. |
| Idempotent re-run | Always for installer, scaffold, manifest, skill, or Agency changes. | Blue re-run over Blue, Red re-run over Red, migration re-run after partial success, skills already installed, App already installed, Agency already installed. |
| Reset behavioral fixtures | Always for `reset.bat`, `reset.ps1`, install smoke, or release smoke. | Per-user Squirrel install removed, per-machine install removed, AppX/MSIX removed, registry ghost removed, workspace removed, skills removed, elevated path works, missing targets do not fail. |
| Cross-pill matrix | Always for installer/scaffold/manifest changes. | Blue new, Red new, Blue over Red guard, Red over Blue behavior, Blue migration target, Red migration target, manifest pill correctness, vault folder correctness. |
| Negative path | Always for changed install/release code. | Missing zip, malformed zip, missing `agents.zip` template, missing `skills.zip` content, malformed manifest, invalid MCP config, Agency missing after install, Copilot App launch failure, insufficient disk, denied write permissions. |

## Release tiers

### Hotfix release

Use only for urgent production breakage. A hotfix may run the smallest integration subset that covers the changed path, but it still requires:

1. All preflight blocking checks.
2. Syntax gates for all shipping PS1/BAT assets.
3. Integration tests for every changed executable path.
4. Reset behavioral fixture if smoke requires clean-machine validation.
5. Post-publish URL probe.

Hotfixes may skip unrelated integration suites only when the release notes name the skipped scope and the skipped path is unchanged.

### Normal patch/minor release

Required for routine `v3.x.y` releases:

1. All preflight checks.
2. Full required integration suite.
3. Clean install smoke for Blue and Red.
4. Upgrade/migration smoke for Blue and Red when migration code or release assets changed.
5. Reset smoke before at least one clean install.
6. Post-publish URL probe.

### Major release

Required for any release that changes installer architecture, workspace layout, Agent/MCP integration, identity/auth assumptions, or release packaging:

1. Normal release bar.
2. Fresh physical Windows 11 machine smoke.
3. Fresh Cloud PC smoke unless explicitly scoped as Tier-2 follow-up.
4. Manual product sign-off from Marcus or delegated release owner.
5. Documented rollback plan before tagging.
6. Post-mortem review of any waived warning before publish.

## Post-publish URL probe

After release creation, CI must verify the published release, not local files.

Blocking checks:

1. The tag resolves to the intended commit.
2. The GitHub Release exists and is marked Latest only after all probes pass.
3. Every required asset URL returns success and downloads a non-empty file.
4. `install.bat` from the release downloads `install-blue.ps1`, `install-red.ps1`, `migrate.ps1`, and `ai-maker-lib.ps1` from the same tag.
5. `skills.zip` and `agents.zip` open successfully and contain required entries.
6. Public site install commands reference the same tag.
7. No release asset contains stale tag URLs except allowed changelog/history text.

Warn-only checks:

1. Docs-only pages not linked from install flow are stale.
2. Release notes omit non-user-facing internal details.

## Branch and tag protection

### `main`

Protect `main` with:

1. Required PR or direct-session review for executable installer changes.
2. Required static preflight green before merge when any release asset, installer, reset, zip source, site install command, or workflow changes.
3. Required runtime integration green before merge when installer behavior changes, unless the PR is explicitly marked docs-only.
4. No direct unreviewed pushes for release assets except emergency rollback by the release owner, followed by post-mortem.

### `v*` tags

Protect `v*` tags with:

1. Tags may be created only by the release workflow or by a release owner invoking the workflow.
2. Tag publish requires the full gate for the declared release tier.
3. If the workflow fails after tag creation, it must delete the tag and any partial release.
4. Retagging the same version is allowed only while the release is still in active rollout correction and must be recorded in release notes or release operations log.

## Failure escalation and rollback

### Production breakage

Trigger this process when any released install path fails for a clean user, upgrade user, or reset/smoke path.

1. Stop rollout. Do not continue smoke on additional machines until the failing path is understood or isolated.
2. Mark the current release non-Latest or delete the release/tag if the bad release is still in active rollout correction.
3. Restore the last known-good release as Latest if users need an immediate safe path.
4. File a P0 issue with: failing path, asset tag, exact command, exit code, visible output, suppressed output if any, machine class, and whether reset was run.
5. Land the smallest source fix.
6. Re-run the hotfix gate for the changed path plus all preflight checks.
7. Recut from CI only.
8. Add a regression test that would have caught the failure before closing the issue.

### Post-mortem trigger

A post-mortem is required when:

1. A release asset is missing or points at the wrong tag.
2. A clean install, upgrade, or reset path fails after publication.
3. A local/manual release bypasses CI.
4. A static invariant could have caught the issue but was not part of the gate.
5. A runtime invariant was known but not executable.

The post-mortem must identify the missing invariant and assign it to static preflight, integration test, post-publish probe, or manual major-release sign-off.
