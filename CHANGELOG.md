# Changelog

## v3.0.6

- Adds a Blue Pill cross-pill workspace guard so `install-blue.ps1` refuses to run over an existing Red Pill workspace manifest.
- Fixes Red Pill disk-space status copy so the reported free space is shown in actual GB instead of raw bytes labeled as GB.
- Bumps installer release links and manifest metadata from v3.0.5 to v3.0.6.
- Adds the v3 release installer scripts to the repository as the source of record for release asset generation.
- Includes the validated post-v3.0.5 site and documentation updates already merged to `main`: Matrix-themed README, pill selector copy and spacing fixes, feedback issue templates, account setup refresh, migration guide draft updates, install/reset link updates, and copy-button styling fixes.
- Ports FD/FS website polish into source, including the legacy CLI migration callout in the install guide and confirmed copy cleanup for onboarding and site wording.
- Clarifies the migration PRD report requirement for legacy-install reassurance versus no-candidate rerun guidance.
