# AI Maker Calibration Log Schema

**Owner:** FI (Data Lead)
**Requested by:** FR (Research Lead) - T5
**Purpose:** Define the schema and aggregation pipeline for AI Maker session calibration logs so FR can analyze calibration drift over time.

---

## Log File Location

```
C:\AIMaker\logs\calibration-{YYYYMMDD}-{HHMM}-{session-id}.jsonl
```

One file per session. JSONL format (one JSON object per line). Append-only during session.

---

## Per-Line Event Schema

Each line in the calibration log is a JSON object conforming to this schema:

```typescript
interface CalibrationEvent {
  // Identity
  session_id: string;           // UUID, stable for session lifetime
  agent_id: string;             // e.g. "AI-Maker-v1"
  timestamp: string;            // ISO 8601, e.g. "2026-02-24T14:35:22Z"
  event_seq: number;            // 1-based event number within session

  // Event classification
  event_type: CalibrationEventType;

  // Behavioral measurements
  response_length_words: number;           // Word count of agent response
  response_length_chars: number;           // Character count
  decision_style: DecisionStyle;           // How agent framed its answer
  correction_protocol_used: boolean;       // Did agent invoke correction protocol?
  confidence_level: "low" | "medium" | "high";  // Self-reported confidence

  // Tone/sentiment snapshot
  sentiment_label: string;                 // "confident", "warm", "direct", "hedging", "corporate", etc.
  sentiment_score: number;                 // -1.0 to 1.0

  // Interview/onboarding specific (null for non-interview sessions)
  interview?: {
    question_id: string;
    question_type: "1-5-spectrum" | "open-ended" | "scenario" | "correction";
    user_response_summary: string;         // Short summary of user answer (not full text)
    calibration_delta: number;             // Change in calibration score this question caused (-10 to +10)
    current_calibration_score: number;     // Running calibration score after this event (0-100)
  };

  // Drift tracking
  drift_from_baseline: number;            // Current score minus session-start score
  cumulative_drift: number;               // Sum of all drift values in session

  // Metadata
  model_version: string;                  // e.g. "gpt-4.1"
  prompt_version: string;                 // Semver of the system prompt used
}

type CalibrationEventType =
  | "session_start"
  | "interview_question"
  | "interview_complete"
  | "user_turn"
  | "agent_turn"
  | "correction_applied"
  | "calibration_checkpoint"
  | "session_end";

type DecisionStyle =
  | "directive"    // Agent makes the call, states it plainly
  | "consultative" // Agent presents options, asks user to choose
  | "deferring"    // Agent defers to user preference without a recommendation
  | "hedging"      // Agent qualifies excessively, no clear stance
  | "neutral";     // No decision required for this turn
```

---

## Session Start Event (required, event_seq: 1)

```json
{
  "session_id": "a1b2c3d4-...",
  "agent_id": "AI-Maker-v1",
  "timestamp": "2026-02-24T14:35:00Z",
  "event_seq": 1,
  "event_type": "session_start",
  "response_length_words": 0,
  "response_length_chars": 0,
  "decision_style": "neutral",
  "correction_protocol_used": false,
  "confidence_level": "high",
  "sentiment_label": "neutral",
  "sentiment_score": 0,
  "drift_from_baseline": 0,
  "cumulative_drift": 0,
  "model_version": "gpt-4.1",
  "prompt_version": "1.2.0"
}
```

---

## Aggregation Pipeline

FR runs analysis against aggregated data, not raw events. FI provides two aggregation outputs:

### 1. Session Summary (`calibration-sessions.jsonl`)

One line per completed session, appended after `session_end` event.

```typescript
interface SessionSummary {
  session_id: string;
  date: string;                        // YYYY-MM-DD
  agent_id: string;
  prompt_version: string;
  model_version: string;

  // Turn counts
  total_turns: number;
  corrections_applied: number;
  interview_questions_answered: number;

  // Calibration outcome
  final_calibration_score: number;     // Score at session end (0-100)
  calibration_drift_total: number;     // Cumulative drift over session
  calibration_drift_max: number;       // Largest single-event drift
  calibration_drift_direction: "improving" | "degrading" | "stable";

  // Tone distribution
  sentiment_distribution: Record<string, number>; // label -> count
  dominant_sentiment: string;

  // Decision style distribution
  decision_style_distribution: Record<string, number>;
  dominant_decision_style: string;

  // Response length stats
  avg_response_words: number;
  p50_response_words: number;
  p95_response_words: number;
}
```

### 2. Drift Trend (`calibration-drift-trend.json`)

Updated daily. Tracks calibration drift over time for FR to detect slow degradation.

```typescript
interface DriftTrend {
  generated_at: string;
  data_through: string;           // YYYY-MM-DD
  sessions_analyzed: number;

  weekly_buckets: {
    week: string;                 // ISO week, e.g. "2026-W08"
    session_count: number;
    avg_final_score: number;
    avg_drift: number;
    correction_rate: number;      // corrections_applied / total_turns
    dominant_sentiment: string;
    dominant_decision_style: string;
  }[];

  alerts: {
    type: "score_drop" | "drift_spike" | "correction_rate_high" | "tone_drift";
    message: string;
    detected_at: string;
    sessions_affected: string[];
  }[];
}
```

---

## FI Implementation Plan

| Step | Task | File | Status |
|------|------|------|--------|
| 1 | Write events to JSONL during session | AIMaker runtime | Not started |
| 2 | Session summarizer (reads JSONL, writes session summary) | `scripts/aimaker-summarize-session.ts` | Not started |
| 3 | Drift trend aggregator (reads session summaries, writes trend file) | `scripts/aimaker-drift-trend.ts` | Not started |
| 4 | FR dashboard input (exports FR-readable CSV) | `scripts/aimaker-export-fr.ts` | Not started |

FI starts step 2-4 after AIMaker runtime is writing events (step 1 is AIMaker team's responsibility).

---

## Notes for FR

- All logs use UTC timestamps.
- `calibration_delta` range is -10 to +10. Negative = user is calibrating agent away from ideal; positive = toward ideal.
- `drift_from_baseline` resets each session. `cumulative_drift` does not.
- Tone alert threshold: if `dominant_sentiment` is "hedging" or "corporate" for 3+ consecutive sessions, FR gets an alert.
- Decision style alert: if `dominant_decision_style` is "deferring" for 5+ sessions, agent may need prompt revision.
