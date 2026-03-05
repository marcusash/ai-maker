/**
 * AI Maker Sentiment Pipeline
 *
 * FR T4: Runs the Inkwell sentiment scorer against a sample of AI Maker outputs.
 * FR wants to know if the AI Maker persona reads as confident, warm, and direct,
 * or if it drifts toward corporate or hedging tone.
 *
 * Input: JSON file with array of { id: string, text: string } sample responses
 *        OR pass samples directly via the exported analyzeAIMakerSamples() function
 *
 * Output: Persona profile report showing tone distribution and drift signals
 *
 * Usage:
 *   npx tsx scripts/aimaker-sentiment-pipeline.ts <samples.json>
 *
 * Owned by FI (Data Lead). FR reads the output for persona calibration decisions.
 */

import { scoreText, familiesToLabels } from "../src/lib/sentiment.js";

// ── Types ────────────────────────────────────────────────────────────────────

export interface AIMakerSample {
  id: string;
  text: string;
}

export interface SampleResult {
  id: string;
  score: number;
  label: string;
  emotions: string[];
  confidence: "high" | "medium" | "low";
  word_count: number;
  // Persona signals derived from score
  reads_as: PersonaSignal;
}

export type PersonaSignal =
  | "confident"   // score > 0.3, emotions include trust/anticipation
  | "warm"        // score > 0.15, emotions include joy/gratitude
  | "direct"      // short response (<= 60 words), positive/neutral
  | "hedging"     // near-zero score + many qualifiers
  | "corporate"   // positive score but zero personal emotion families
  | "neutral";    // score between -0.15 and 0.15, no strong signal

const HEDGING_WORDS = [
  "perhaps", "maybe", "possibly", "might", "could", "somewhat", "fairly",
  "rather", "quite", "generally", "usually", "typically", "often",
  "in some cases", "depending", "it depends", "may vary",
];

const CORPORATE_WORDS = [
  "leverage", "synergy", "stakeholder", "deliverable", "bandwidth", "utilize",
  "scalable", "robust", "actionable", "streamline", "optimize", "paradigm",
  "circle back", "deep dive", "touch base", "move the needle", "low-hanging fruit",
];

// ── Persona Classification ────────────────────────────────────────────────────

export function classifyPersonaSignal(
  score: number,
  emotions: string[],
  wordCount: number,
  rawText: string,
): PersonaSignal {
  const text = rawText.toLowerCase();
  const hedgeCount = HEDGING_WORDS.filter((w) => text.includes(w)).length;
  const corpCount = CORPORATE_WORDS.filter((w) => text.includes(w)).length;

  // Corporate: positive score but heavy jargon
  if (corpCount >= 2) return "corporate";

  // Hedging: near-neutral score or too many qualifiers
  if (hedgeCount >= 3 || (Math.abs(score) < 0.1 && hedgeCount >= 2)) return "hedging";

  // Confident: positive score + trust/anticipation emotions
  const confidentEmotions = ["trust", "anticipation", "courage", "pride"];
  if (score > 0.3 && emotions.some((e) => confidentEmotions.includes(e))) return "confident";

  // Warm: positive + joy/gratitude family
  const warmEmotions = ["joy", "gratitude", "love"];
  if (score > 0.15 && emotions.some((e) => warmEmotions.includes(e))) return "warm";

  // Direct: short, not negative, no hedging
  if (wordCount <= 60 && score >= 0) return "direct";

  // Neutral otherwise
  return "neutral";
}

// ── Main Analysis Function ────────────────────────────────────────────────────

export function analyzeAIMakerSamples(samples: AIMakerSample[]): {
  results: SampleResult[];
  summary: PersonaSummary;
} {
  const results: SampleResult[] = samples.map((s) => {
    const scored = scoreText(s.text);
    const words = s.text.trim().split(/\s+/).filter(Boolean).length;
    const emotions = familiesToLabels(scored.dominantEmotions);
    const signal = classifyPersonaSignal(scored.score, emotions, words, s.text);

    return {
      id: s.id,
      score: scored.score,
      label: scored.label,
      emotions,
      confidence: scored.confidence,
      word_count: words,
      reads_as: signal,
    };
  });

  const summary = buildSummary(results);
  return { results, summary };
}

// ── Summary ───────────────────────────────────────────────────────────────────

export interface PersonaSummary {
  total_samples: number;
  avg_score: number;
  signal_distribution: Record<PersonaSignal, number>;
  dominant_signal: PersonaSignal;
  drift_alerts: string[];
  persona_assessment: string;
}

function buildSummary(results: SampleResult[]): PersonaSummary {
  if (results.length === 0) {
    return {
      total_samples: 0,
      avg_score: 0,
      signal_distribution: {
        confident: 0, warm: 0, direct: 0, hedging: 0, corporate: 0, neutral: 0,
      },
      dominant_signal: "neutral",
      drift_alerts: [],
      persona_assessment: "No samples to evaluate.",
    };
  }

  const avgScore = results.reduce((a, b) => a + b.score, 0) / results.length;
  const distribution: Record<PersonaSignal, number> = {
    confident: 0, warm: 0, direct: 0, hedging: 0, corporate: 0, neutral: 0,
  };
  for (const r of results) {
    distribution[r.reads_as]++;
  }

  const dominant = (Object.entries(distribution) as [PersonaSignal, number][])
    .sort(([, a], [, b]) => b - a)[0][0];

  const alerts: string[] = [];
  const hedgeRate = distribution.hedging / results.length;
  const corpRate = distribution.corporate / results.length;

  if (hedgeRate > 0.3) alerts.push(`Hedging detected in ${Math.round(hedgeRate * 100)}% of responses. Persona may lack confidence.`);
  if (corpRate > 0.2) alerts.push(`Corporate jargon in ${Math.round(corpRate * 100)}% of responses. Persona sounds impersonal.`);
  if (avgScore < -0.1) alerts.push("Average sentiment is negative. Persona may read as cold or critical.");

  const positiveSignals = distribution.confident + distribution.warm + distribution.direct;
  const positiveRate = positiveSignals / results.length;
  let assessment: string;
  if (positiveRate >= 0.7) assessment = "Persona reads as confident, warm, and direct. On target.";
  else if (dominant === "hedging") assessment = "Persona is over-qualifying. Revise system prompt to be more direct.";
  else if (dominant === "corporate") assessment = "Persona sounds corporate. Remove jargon from examples.";
  else assessment = `Persona is mostly ${dominant}. Review samples for tone consistency.`;

  return {
    total_samples: results.length,
    avg_score: Math.round(avgScore * 1000) / 1000,
    signal_distribution: distribution,
    dominant_signal: dominant,
    drift_alerts: alerts,
    persona_assessment: assessment,
  };
}

// ── CLI Entry ─────────────────────────────────────────────────────────────────

function formatReport(results: SampleResult[], summary: PersonaSummary): string {
  const lines: string[] = [];
  lines.push("AI Maker Persona Sentiment Report");
  lines.push("=".repeat(40));
  lines.push(`Samples: ${summary.total_samples}`);
  lines.push(`Avg score: ${summary.avg_score}`);
  lines.push(`Dominant signal: ${summary.dominant_signal}`);
  lines.push("");
  lines.push("Signal distribution:");
  for (const [signal, count] of Object.entries(summary.signal_distribution)) {
    if (count > 0) {
      lines.push(`  ${signal}: ${count} (${Math.round((count / summary.total_samples) * 100)}%)`);
    }
  }
  lines.push("");
  if (summary.drift_alerts.length > 0) {
    lines.push("DRIFT ALERTS:");
    for (const alert of summary.drift_alerts) {
      lines.push(`  - ${alert}`);
    }
    lines.push("");
  }
  lines.push(`Assessment: ${summary.persona_assessment}`);
  return lines.join("\n");
}

const isMain = process.argv[1]?.includes("aimaker-sentiment-pipeline");
if (isMain) {
  const samplesPath = process.argv[2];
  if (!samplesPath) {
    console.error("Usage: npx tsx scripts/aimaker-sentiment-pipeline.ts <samples.json>");
    process.exit(1);
  }
  const { readFileSync } = await import("fs");
  const { resolve } = await import("path");
  const samples: AIMakerSample[] = JSON.parse(readFileSync(resolve(samplesPath), "utf-8"));
  const { results, summary } = analyzeAIMakerSamples(samples);
  console.log(formatReport(results, summary));
  process.exit(summary.drift_alerts.length > 0 ? 1 : 0);
}
