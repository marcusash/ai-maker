# tests/contract/

Installer regression harness for marcusash/ai-maker.
See design doc: state-capture-library-design.md (FI session files)
PRD: FR pending sign-off from FF + FA.

## Structure

harness/         - AIMakerTestLib.psm1 state-capture library
fixtures/blue/   - Blue pill scenario fixtures (B1 fresh, B2 upgrade)
fixtures/red/    - Red pill scenario fixtures (R1 fresh, R2 upgrade)
assertions/      - Shared assertion helpers
cases/           - Pester test files (one per case: B1, B2, R1, R2)
meta-tests/      - Tests that verify the test harness itself

## Entry point

    .\test-installer.ps1 -Case <B1|B2|R1|R2>

## Tags

VMOnly    - assertions requiring Hyper-V VM (Phase 2)
Sandbox   - runs in CI on every push (Phase 1)
