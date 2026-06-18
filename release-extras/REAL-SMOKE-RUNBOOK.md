# AI Maker v3.0.11 — Real-Machine Smoke Runbook

**Your job:** Prove v3.0.11 installs cleanly on a real Windows laptop AND a Cloud PC, with both Blue and Red pills, including the rerun (upgrade) case.

**Time per machine:** ~5 minutes.

---

## What you do (per machine)

1. **Download the bundle** (one-click):
   <https://github.com/marcusash/ai-maker/releases/download/v3.0.11/ai-maker-v3.0.11.zip>

2. **Unzip** to anywhere (Downloads is fine). Right-click the zip → "Extract All".

3. **Right-click `install.bat` → Run as administrator.**
   - Pick **1** (Blue Pill) the first round.
   - Wait for "INSTALL COMPLETE" + agency tray icon.

4. **Double-click `verify.bat`.**
   - Reads green PASS lines → reply **"Done"** in chat.
   - Any red FAIL line → upload `C:\Temp\ai-maker-smoke\verify-<timestamp>.log` (path printed at end).

5. **Run `install.bat` AGAIN as administrator** (same Blue Pill choice).
   - This is the v3.0.11 idempotency test. Should finish in <30s without doubling anything.

6. **Run `verify.bat` AGAIN.** Should still be ALL GREEN. (Probe #5 specifically catches the v3.0.10 nested-dir bug if it ever comes back.)

7. **Run `install.bat` a THIRD time, choose `2` (Red Pill)** — this is the Blue→Red upgrade.
   - `verify.bat` again. Should pass with skill count flipping from 11 → 22 and `ai-workbench.md` appearing.

---

## What's automated (you don't have to test)

- All 37 assertions per pill (B1/B2/R1/R2) — covered by the contract harness in CI.
- Idempotent-rerun assertion (#6 untagged in v3.0.11 — passes against fixed lib).
- URL coherence, SHELL env-var presence, Velopack glob, MCP scope, Blue Purity — pre-flight gate enforces all 10 invariants before tagging.
- Hash drift between source and published assets — release script verifies post-publish with rollback on mismatch.

## What is NOT automated (your test surface)

- UAC prompt + Run-as-Administrator path
- `winget install Microsoft.PowerShell` when pwsh missing
- Real Velopack agency.exe install (network, signature, %APPDATA%)
- Real Copilot CLI workspace pickup
- CPC-specific quirks: OneDrive-backed APPDATA, M365 SSO seed, hostname patterns
- The actual experience of clicking install.bat and waiting

`verify.ps1` Probe #10 captures hostname + Laptop/CloudPC type into the log so we know which surface each run came from. Probe #11 flags OneDrive-backed APPDATA before it bites.

---

## What `verify.ps1` checks (12 probes)

1. Pill detected (Blue or Red workspace present)
2. Workspace structure complete (`.github/`, `agents/`, `skills/`)
3. `copilot-instructions.md` has correct pill marker
4. Skill count matches pill (Blue: 11 maker, 0 workbench · Red: 11 + 11)
5. **No nested skill dirs** — the v3.0.11 idempotency fix
6. Agent identity files — Blue: `ai-maker.md` only · Red: + `ai-workbench.md`
7. `SHELL` env var set to Git Bash `sh.exe` (User scope, per FP v3.0.4 scar)
8. Velopack `agency.exe` locatable via `$env:APPDATA\agency\*\agency.exe` glob (per FP v3.0.5 scar)
9. `m-mcp-servers.json` has **workiq + bluebird only** (per FP v3.0.6 scar — no M365 surface expansion)
10. Hostname + machine type (Laptop vs CloudPC) captured for log triage
11. `APPDATA` not OneDrive-backed (CPC quirk — Velopack file-lock risk)
12. Lib version = 3.0.11 (if lib is co-located)

---

## If something fails

Upload the single log file:

```
C:\Temp\ai-maker-smoke\verify-<timestamp>.log
```

That + your "failed at step N" in chat is the entire handoff. Don't paste output — the log has everything we need including hostname, pill, and which probes failed with details.

---

## Total surface

- **Laptop:** 3 install + 3 verify cycles. ~10 min.
- **Cloud PC:** 3 install + 3 verify cycles. ~10 min.

**No PowerShell. No git. No editing files.** Right-click, double-click, reply Done.
