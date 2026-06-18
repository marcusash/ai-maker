## v3.0.10

- **BLOCKER FIX:** Agency MCP Settings canvas no longer fails with "Unexpected end of JSON input" on fresh Windows installs. Sets `SHELL` user env var to Git Bash so `agency-mcp-settings` extension can spawn `agency mcp list` (extension defaulted to `/bin/sh` which does not exist on Windows).
- **BLOCKER FIX:** Velopack-installed `agency.exe` (lives at `%APPDATA%\agency\<version>\agency.exe`, not on PATH) is now discovered via versioned-folder probe. Previous `Get-Command agency.exe` checks failed silently.
- Post-registration verifies `m-mcp-servers.json` lists `workiq` and `bluebird` — silent install-success with broken MCP state is no longer possible.
- Auto-enables Agency built-in MCPs `teams`, `outlook`, `planner` (ship with `defaultEnabled: false`).
- Blue copilot-instructions and ai-maker.md scrubbed of all AI workbench / Red Pill cross-references — Blue Pill is now Blue-pure.
- Session naming hard rule: agent calls `rename_session(title="AI maker")` as first action in every session. Sentence case, locked.
# Changelog

## v3.0.6

- Adds a Blue Pill cross-pill workspace guard so `install-blue.ps1` refuses to run over an existing Red Pill workspace manifest.
- Fixes Red Pill disk-space status copy so the reported free space is shown in actual GB instead of raw bytes labeled as GB.
- Bumps installer release links and manifest metadata from v3.0.5 to v3.0.6.
- Adds the v3 release installer scripts to the repository as the source of record for release asset generation.
- Includes the validated post-v3.0.5 site and documentation updates already merged to `main`: Matrix-themed README, pill selector copy and spacing fixes, feedback issue templates, account setup refresh, migration guide draft updates, install/reset link updates, and copy-button styling fixes.
- Ports FD/FS website polish into source, including the legacy CLI migration callout in the install guide and confirmed copy cleanup for onboarding and site wording.
- Clarifies the migration PRD report requirement for legacy-install reassurance versus no-candidate rerun guidance.
- Adds the FS-reviewed first-session onboarding guidance to the install guide with the current two-question interview copy.
- Adds the FS-reviewed `existing-install-guide.html` artifact and the migrate.ps1 PRD §9b clarification to the release source.
- Replaces the brittle individual M365 MCP `agency config set` installer step with the shared Agency MCP registration path for `workiq` and `bluebird`.
