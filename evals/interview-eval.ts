/**
 * AI Maker Interview Calibration Eval Harness
 *
 * FR T1: Measures whether the onboarding interview correctly calibrates
 * agent behavior across three dimensions:
 *   1. Response length (short/medium/long per Q2 calibration)
 *   2. Decision style (directive/consultative/deferring per Q6 calibration)
 *   3. Correction protocol (confirm-before-act per Q2 dictation flag)
 *
 * Usage:
 *   npx tsx scripts/aimaker-interview-eval.ts <path-to-session-log.jsonl>
 *
 * Input: JSONL file where each line is a CalibrationEvent (see calibration-log-schema.md)
 * Output: Eval report to stdout + exit code 0 (pass) / 1 (fail)
 */

import * as fs from "fs";
import * as path from "path";

// ── Types ────────────────────────────────────────────────────────────────────

interface CalibrationEvent {
  event_type: string;
  response_length_words: number;
  decision_style: string;
  correction_protocol_used: boolean;
  interview?: {
    question_id: string;
    question_type: string;
    current_calibration_score: number;
  };
}

export interface InterviewCalibrationScore {
  responseLength: {
    expected: "short" | "medium" | "long" | "unknown";
    actual_avg_words: number;
    compliant: boolean;
    score: number; // 0-100
  };
  decisionStyle: {
    expected: string;
    dominant_actual: string;
    compliant: boolean;
    score: number; // 0-100
  };
  correctionProtocol: {
    dictation_flagged: boolean;
    protocol_used_when_expected: boolean;
    score: number; // 0-100
  };
  overall_score: number; // 0-100
  pass: boolean;         // overall_score >= 70
}

// ── Constants ────────────────────────────────────────────────────────────────

/** Q2 spectrum -> expected response length */
const Q2_SPECTRUM_TO_LENGTH: Record<number, "short" | "medium" | "long"> = {
  1: "long",
  2: "long",
  3: "medium",
  4: "short",
  5: "short",
};

/** Q6 spectrum -> expected decision style */
const Q6_SPECTRUM_TO_STYLE: Record<number, string> = {
  1: "consultative",
  2: "consultative",
  3: "directive",
  4: "directive",
  5: "deferring",
};

const RESPONSE_LENGTH_THRESHOLDS = {
  short: { max: 60 },   // <= 60 words
  medium: { min: 40, max: 150 }, // 40-150 words
  long: { min: 100 },   // >= 100 words
};

const PASS_THRESHOLD = 70;

// ── Scoring Logic ─────────────────────────────────────────────────────────────

/** Determine if avg words falls in the expected length category */
function scoreLengthCompliance(
  expected: "short" | "medium" | "long" | "unknown",
  avgWords: number,
): boolean {
  if (expected === "unknown") return true;
  const t = RESPONSE_LENGTH_THRESHOLDS[expected];
  if (expected === "short") return avgWords <= (t as { max: number }).max;
  if (expected === "long") return avgWords >= (t as { min: number }).min;
  // medium: within range
  return avgWords >= (t as { min: number; max: number }).min &&
    avgWords <= (t as { min: number; max: number }).max;
}

/** Find the most common value in an array */
function dominant<T>(values: T[]): T | undefined {
  const counts = new Map<T, number>();
  for (const v of values) {
    counts.set(v, (counts.get(v) ?? 0) + 1);
  }
  let max = 0;
  let result: T | undefined;
  for (const [k, v] of counts) {
    if (v > max) {
      max = v;
      result = k;
    }
  }
  return result;
}

// ── Main Eval Function ────────────────────────────────────────────────────────

export function evalInterviewCalibration(
  events: CalibrationEvent[],
): InterviewCalibrationScore {
  // Extract interview question events
  const interviewEvents = events.filter(
    (e) => e.event_type === "interview_question" && e.interview,
  );
  const postInterviewEvents = events.filter(
    (e) => e.event_type === "agent_turn",
  );

  // Determine expected behavior from Q2 and Q6 answers
  let expectedLength: "short" | "medium" | "long" | "unknown" = "unknown";
  let dictationFlagged = false;
  let expectedDecisionStyle = "directive"; // default

  for (const e of interviewEvents) {
    const qi = e.interview!;
    if (qi.question_id === "Q2") {
      // Q2 score maps 0-100 to spectrum 1-5: 0=pos1, 25=pos2 ... 100=pos5
      const spectrum = Math.min(5, Math.max(1, Math.round(qi.current_calibration_score / 25) + 1));
      expectedLength = Q2_SPECTRUM_TO_LENGTH[spectrum] ?? "medium";
      dictationFlagged = spectrum >= 4;
    }
    if (qi.question_id === "Q6") {
      const spectrum = Math.min(5, Math.max(1, Math.round(qi.current_calibration_score / 25) + 1));
      expectedDecisionStyle = Q6_SPECTRUM_TO_STYLE[spectrum] ?? "directive";
    }
  }

  // Score: Response length
  const wordCounts = postInterviewEvents.map((e) => e.response_length_words).filter((w) => w > 0);
  const avgWords = wordCounts.length > 0
    ? wordCounts.reduce((a, b) => a + b, 0) / wordCounts.length
    : 0;
  const lengthCompliant = scoreLengthCompliance(expectedLength, avgWords);
  const lengthScore = lengthCompliant
    ? 100
    : Math.max(0, 100 - Math.abs(
        expectedLength === "short" ? avgWords - 60 :
        expectedLength === "long" ? 100 - avgWords :
        0
      ) * 2);

  // Score: Decision style
  const styles = postInterviewEvents.map((e) => e.decision_style).filter((s) => s && s !== "neutral");
  const dominantStyle = dominant(styles) ?? "neutral";
  const styleCompliant = dominantStyle === expectedDecisionStyle;
  const styleScore = styleCompliant ? 100 : 50; // partial credit if close

  // Score: Correction protocol
  const correctionOpportunities = postInterviewEvents.filter((e) => e.decision_style !== "neutral").length;
  const correctionUsed = postInterviewEvents.filter((e) => e.correction_protocol_used).length;
  const protocolCompliant = !dictationFlagged || correctionUsed > 0;
  const correctionScore = !dictationFlagged ? 100 : (correctionUsed > 0 ? 100 : Math.max(0, 100 - correctionOpportunities * 10));

  const overallScore = Math.round((lengthScore + styleScore + correctionScore) / 3);

  return {
    responseLength: {
      expected: expectedLength,
      actual_avg_words: Math.round(avgWords),
      compliant: lengthCompliant,
      score: Math.round(lengthScore),
    },
    decisionStyle: {
      expected: expectedDecisionStyle,
      dominant_actual: dominantStyle,
      compliant: styleCompliant,
      score: Math.round(styleScore),
    },
    correctionProtocol: {
      dictation_flagged: dictationFlagged,
      protocol_used_when_expected: protocolCompliant,
      score: Math.round(correctionScore),
    },
    overall_score: overallScore,
    pass: overallScore >= PASS_THRESHOLD,
  };
}

// ── CLI Entry ─────────────────────────────────────────────────────────────────

function formatReport(score: InterviewCalibrationScore): string {
  const lines: string[] = [];
  lines.push("AI Maker Interview Calibration Eval");
  lines.push("=".repeat(40));
  lines.push("");
  lines.push(`Overall: ${score.overall_score}/100 ${score.pass ? "PASS" : "FAIL"}`);
  lines.push("");
  lines.push("Response Length:");
  lines.push(`  Expected: ${score.responseLength.expected}`);
  lines.push(`  Actual avg: ${score.responseLength.actual_avg_words} words`);
  lines.push(`  Score: ${score.responseLength.score}/100`);
  lines.push("");
  lines.push("Decision Style:");
  lines.push(`  Expected: ${score.decisionStyle.expected}`);
  lines.push(`  Dominant actual: ${score.decisionStyle.dominant_actual}`);
  lines.push(`  Score: ${score.decisionStyle.score}/100`);
  lines.push("");
  lines.push("Correction Protocol:");
  lines.push(`  Dictation flagged: ${score.correctionProtocol.dictation_flagged}`);
  lines.push(`  Protocol used when expected: ${score.correctionProtocol.protocol_used_when_expected}`);
  lines.push(`  Score: ${score.correctionProtocol.score}/100`);
  return lines.join("\n");
}

const isMain = process.argv[1]?.includes("aimaker-interview-eval");
if (isMain) {
  const logPath = process.argv[2];
  if (!logPath) {
    console.error("Usage: npx tsx scripts/aimaker-interview-eval.ts <session-log.jsonl>");
    process.exit(1);
  }
  const raw = fs.readFileSync(path.resolve(logPath), "utf-8");
  const events: CalibrationEvent[] = raw
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));

  const score = evalInterviewCalibration(events);
  console.log(formatReport(score));
  process.exit(score.pass ? 0 : 1);
}
