# AI Maker Cross-Session Memory Architecture

**Owner:** FI (Data Lead)
**Requested by:** FR (Research Lead) - T6
**Purpose:** Design how AI Maker profiles persist and evolve across sessions without manual updates. Current design is a static `C:\AIMaker\profile.md` file.

---

## Problem

Current state: AI Maker reads `C:\AIMaker\profile.md` at session start. This file is written once during onboarding and never updated automatically. Problems:

1. User preferences drift over time (communication style changes, role evolves).
2. No mechanism to capture feedback without manual edit.
3. No history - impossible to detect when calibration degrades.
4. Corrections made during one session are lost in the next.

---

## Design: Dynamic Profile System

### Architecture

```
C:\AIMaker\
  profile.md              <- Canonical profile (human-readable, AI Maker reads this)
  profile-history\
    YYYY-MM-DD-profile.md <- Daily snapshot at session start
  session-log\
    YYYYMMDD-HHMM-session-summary.json  <- Per-session summary
  profile-updates\
    YYYYMMDD-HHMM-update.json           <- Pending profile update proposals
  profile.lock            <- Write lock (prevents concurrent updates)
```

### Profile Layers

The profile has three layers that update at different rates:

| Layer | Update frequency | Contents | Who updates |
|-------|-----------------|----------|-------------|
| Core | Never (manual only) | Name, role, org, goals | User in onboarding |
| Calibration | After each session (if delta significant) | Response length, decision style, correction protocol score | AI Maker auto |
| Recent | Overwritten each session | Last 3 sessions, latest feedback, unresolved corrections | AI Maker auto |

### Session Lifecycle

```
Session start:
  1. Read profile.md -> load into working memory
  2. Copy to profile-history/YYYY-MM-DD-profile.md (if not already today's)
  3. Apply any pending updates from profile-updates/ (most recent first)
  4. Begin session

Session end:
  1. Compute session-summary.json (calibration scores, feedback signals)
  2. If calibration delta > threshold, propose update to profile-updates/
  3. Apply update to profile.md if auto-apply conditions met
  4. Write profile-history snapshot
```

### Update Proposal Schema

```typescript
interface ProfileUpdateProposal {
  session_id: string;
  created_at: string;         // ISO 8601
  update_type: UpdateType;
  field: string;              // dot-path into profile: "calibration.response_length"
  old_value: string;
  new_value: string;
  confidence: "high" | "medium" | "low";
  evidence: string;           // Why this update is proposed (human-readable)
  auto_apply: boolean;        // true if confidence=high and field is Calibration layer
}

type UpdateType =
  | "calibration_drift"   // Measured behavior has drifted from profile setting
  | "user_correction"     // User explicitly corrected AI Maker mid-session
  | "preference_signal"   // User expressed a preference (not a correction)
  | "role_update";        // User mentioned role change
```

### Auto-Apply Rules

FI recommends these auto-apply conditions:

| Condition | Action |
|-----------|--------|
| `confidence=high` AND `update_type=user_correction` | Auto-apply immediately |
| `confidence=high` AND `update_type=calibration_drift` AND drift > 2 sessions | Auto-apply |
| `confidence=medium` AND any type | Queue for user review |
| `confidence=low` | Drop (noise) |
| Core layer field | Never auto-apply (always require user confirmation) |

### Calibration Drift Detection

Use the calibration log (see `docs/aimaker/calibration-log-schema.md`) to detect drift:

1. Compare the last 3 sessions' `dominant_decision_style` to the profile's expected style.
2. If 2 of 3 sessions show a different style, propose a `calibration_drift` update.
3. Same logic for `avg_response_words` vs expected length.

### Profile Update Format

When AI Maker auto-updates the profile, it adds a block at the top of `profile.md`:

```markdown
<!-- Auto-updated: 2026-02-24T14:35:00Z | session: abc-123 | field: calibration.response_length | confidence: high -->
<!-- Previous value: short | New value: medium | Evidence: Last 3 sessions averaged 90 words (threshold: 60) -->
```

HTML comments are invisible to the user during normal reading but visible to AI Maker's parser.

---

## Implementation Plan

| Step | Task | File | Owner |
|------|------|------|-------|
| 1 | Profile parser - read layers from profile.md | `src/lib/aimaker-profile.ts` | FI |
| 2 | Session summarizer - write session-summary.json | Extends calibration log pipeline | FI |
| 3 | Update proposer - detects drift, writes proposals | `src/lib/aimaker-profile-updater.ts` | FI |
| 4 | Update applier - applies proposals to profile.md | Part of profile-updater | FI |
| 5 | Session start hook - reads pending updates | AI Maker runtime integration | AIMaker team |

FI can deliver steps 1-4 after Marcus approves the architecture.

---

## Decision Points for Marcus/FR

Before FI builds:

1. **Auto-apply threshold**: Should `confidence=high` updates auto-apply without user confirmation? Recommended: yes for Calibration layer, no for Core.
2. **History retention**: How many daily snapshots to keep? Recommended: 30 days.
3. **Drift threshold**: How many sessions of divergence before a drift update fires? Recommended: 2 consecutive sessions.
4. **User notification**: Should AI Maker mention at session start when it has updated the profile? Recommended: yes, one sentence only.

---

## Alternative Considered (Rejected)

**Database approach**: Store profile in SQLite. Rejected because:
- Profile.md is human-readable and Marcus can edit it directly.
- Breaks the simplicity principle (AI Maker is a text-first tool).
- No multi-agent access needed for v1.

File-based with JSONL update log is the right v1 architecture.
