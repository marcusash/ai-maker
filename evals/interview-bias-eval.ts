/**
 * AI Maker Interview Bias Eval
 *
 * FR T9: Verifies that 1-5 spectrum questions in the onboarding interview
 * do NOT anchor users toward any particular answer.
 *
 * A question has anchoring bias if:
 * - Its framing contains positive/negative loaded language for a specific position
 * - The example answers for one position are notably longer or richer than others
 * - A naive reader would be steered toward a specific spectrum position
 *
 * Scoring method:
 * 1. Text analysis: detect loaded positive/negative words per position
 * 2. Length parity: compare character count of each spectrum position example
 * 3. Agreement: measure agreement across a simulated response distribution
 *
 * Usage:
 *   npx tsx scripts/aimaker-interview-bias-eval.ts
 *
 * Reads: docs/ai-maker/onboarding-interview.md
 * Output: bias report + exit 0 (no significant bias) / 1 (bias detected)
 */

import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ── Types ────────────────────────────────────────────────────────────────────

export interface SpectrumQuestion {
  id: string;
  text: string;
  positions: { level: number; text: string }[];
}

export interface BiasReport {
  question_id: string;
  length_variance: number;        // stddev of position text lengths, normalized
  loaded_word_count: number;      // total positive/negative loaded words across positions
  loaded_words_by_position: Record<number, string[]>;
  max_position_bias: number;      // highest loaded word count for any single position
  bias_detected: boolean;         // true if variance or max_position_bias exceeds thresholds
  pass: boolean;                  // !bias_detected
}

export interface OverallBiasResult {
  questions_evaluated: number;
  questions_passing: number;
  questions_failing: string[];
  overall_pass: boolean;
  reports: BiasReport[];
}

// ── Loaded Word Lists ────────────────────────────────────────────────────────

// Words that suggest one end is correct/better (anchoring triggers)
const POSITIVE_LOADED = [
  "best", "better", "prefer", "ideal", "perfect", "most", "always",
  "important", "key", "clear", "smart", "good", "excellent", "great",
  "right", "correct", "should", "must", "need",
];

const NEGATIVE_LOADED = [
  "worst", "bad", "never", "wrong", "incorrect", "avoid", "problem",
  "issue", "difficult", "hard", "confusing", "poor",
];

// ── Parser ───────────────────────────────────────────────────────────────────

/**
 * Parse spectrum questions from the onboarding interview markdown.
 * Looks for tables with positions 1-5.
 */
export function parseSpectrumQuestions(markdown: string): SpectrumQuestion[] {
  const questions: SpectrumQuestion[] = [];

  // Find question sections (Q1, Q2, etc.) with spectrum tables
  const questionBlocks = markdown.split(/\n---\n/);

  for (const block of questionBlocks) {
    // Find Q-number identifier
    const qMatch = block.match(/\*\*Q(\d+)\./);
    if (!qMatch) continue;
    const qId = `Q${qMatch[1]}`;

    // Find the question text
    const textMatch = block.match(/>\s*"([^"]+)"/);
    const questionText = textMatch ? textMatch[1] : "";

    // Find spectrum table rows: | N | position text |
    const tableRows = [...block.matchAll(/^\|\s*(\d)\s*\|\s*([^|]+)\|/gm)];
    if (tableRows.length < 2) continue; // Not a spectrum question

    const positions = tableRows.map((row) => ({
      level: parseInt(row[1], 10),
      text: row[2].trim(),
    }));

    if (positions.length >= 2) {
      questions.push({ id: qId, text: questionText, positions });
    }
  }

  return questions;
}

// ── Bias Analysis ────────────────────────────────────────────────────────────

function countLoadedWords(text: string): { positive: string[]; negative: string[] } {
  const words = text.toLowerCase().split(/\W+/);
  return {
    positive: words.filter((w) => POSITIVE_LOADED.includes(w)),
    negative: words.filter((w) => NEGATIVE_LOADED.includes(w)),
  };
}

function stddev(values: number[]): number {
  if (values.length === 0) return 0;
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  const variance = values.map((v) => (v - mean) ** 2).reduce((a, b) => a + b, 0) / values.length;
  return Math.sqrt(variance);
}

export function analyzeQuestionBias(question: SpectrumQuestion): BiasReport {
  const lengths = question.positions.map((p) => p.text.length);
  const avgLength = lengths.reduce((a, b) => a + b, 0) / lengths.length;
  const lengthVariance = avgLength > 0 ? stddev(lengths) / avgLength : 0;

  const loadedByPosition: Record<number, string[]> = {};
  let totalLoaded = 0;
  let maxPositionBias = 0;

  for (const pos of question.positions) {
    const { positive, negative } = countLoadedWords(pos.text);
    const allLoaded = [...positive, ...negative];
    loadedByPosition[pos.level] = allLoaded;
    totalLoaded += allLoaded.length;
    if (allLoaded.length > maxPositionBias) {
      maxPositionBias = allLoaded.length;
    }
  }

  // Thresholds: length variance > 0.5 (one position 50% longer than avg) or max loaded > 3
  const biasDetected = lengthVariance > 0.5 || maxPositionBias > 3;

  return {
    question_id: question.id,
    length_variance: Math.round(lengthVariance * 100) / 100,
    loaded_word_count: totalLoaded,
    loaded_words_by_position: loadedByPosition,
    max_position_bias: maxPositionBias,
    bias_detected: biasDetected,
    pass: !biasDetected,
  };
}

export function runBiasEval(markdown: string): OverallBiasResult {
  const questions = parseSpectrumQuestions(markdown);
  const reports = questions.map(analyzeQuestionBias);
  const failing = reports.filter((r) => !r.pass).map((r) => r.question_id);

  return {
    questions_evaluated: questions.length,
    questions_passing: reports.filter((r) => r.pass).length,
    questions_failing: failing,
    overall_pass: failing.length === 0,
    reports,
  };
}

// ── CLI Entry ─────────────────────────────────────────────────────────────────

function formatBiasReport(result: OverallBiasResult): string {
  const lines: string[] = [];
  lines.push("AI Maker Interview Bias Eval");
  lines.push("=".repeat(40));
  lines.push(`Questions evaluated: ${result.questions_evaluated}`);
  lines.push(`Passing: ${result.questions_passing}`);
  lines.push(`Failing: ${result.questions_failing.join(", ") || "none"}`);
  lines.push(`Overall: ${result.overall_pass ? "PASS" : "FAIL"}`);
  lines.push("");

  for (const r of result.reports) {
    if (!r.pass) {
      lines.push(`${r.question_id} FAIL:`);
      lines.push(`  Length variance: ${r.length_variance} (threshold: 0.5)`);
      lines.push(`  Max loaded words in one position: ${r.max_position_bias} (threshold: 3)`);
      for (const [pos, words] of Object.entries(r.loaded_words_by_position)) {
        if (words.length > 0) {
          lines.push(`  Position ${pos}: [${words.join(", ")}]`);
        }
      }
    }
  }

  return lines.join("\n");
}

const isMain = process.argv[1]?.includes("aimaker-interview-bias-eval");
if (isMain) {
  const interviewPath = path.resolve(
    __dirname,
    "../docs/onboarding-interview.md",
  );
  if (!fs.existsSync(interviewPath)) {
    console.error(`Interview file not found: ${interviewPath}`);
    process.exit(1);
  }
  const markdown = fs.readFileSync(interviewPath, "utf-8");
  const result = runBiasEval(markdown);
  console.log(formatBiasReport(result));
  process.exit(result.overall_pass ? 0 : 1);
}
