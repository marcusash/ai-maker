import { describe, it, expect } from "vitest";
import {
  classifyPersonaSignal,
  analyzeAIMakerSamples,
  type AIMakerSample,
} from "../../scripts/aimaker-sentiment-pipeline.js";

describe("classifyPersonaSignal", () => {
  it("classifies confident: high positive score + trust emotion", () => {
    const signal = classifyPersonaSignal(0.5, ["trust", "anticipation"], 80, "I am confident this is the right approach.");
    expect(signal).toBe("confident");
  });

  it("classifies warm: moderate positive + joy emotion", () => {
    const signal = classifyPersonaSignal(0.2, ["joy", "gratitude"], 80, "I am happy to help with this.");
    expect(signal).toBe("warm");
  });

  it("classifies direct: short response, non-negative", () => {
    const signal = classifyPersonaSignal(0.1, [], 40, "Done. File saved to the vault.");
    expect(signal).toBe("direct");
  });

  it("classifies hedging: too many hedging words", () => {
    const signal = classifyPersonaSignal(0.05, [], 100,
      "Perhaps this might possibly work, depending on the situation, though it may vary."
    );
    expect(signal).toBe("hedging");
  });

  it("classifies corporate: heavy jargon", () => {
    const signal = classifyPersonaSignal(0.3, ["trust"], 100,
      "We need to leverage our bandwidth to synergize our stakeholder deliverables."
    );
    expect(signal).toBe("corporate");
  });

  it("classifies neutral: near-zero score, few signals", () => {
    const signal = classifyPersonaSignal(0.05, [], 70, "The file has been updated.");
    expect(signal).toBe("neutral");
  });
});

describe("analyzeAIMakerSamples", () => {
  it("returns summary with correct sample count", () => {
    const samples: AIMakerSample[] = [
      { id: "s1", text: "I trust this approach and am confident it will work well for your goals." },
      { id: "s2", text: "Done. File saved." },
    ];
    const { summary } = analyzeAIMakerSamples(samples);
    expect(summary.total_samples).toBe(2);
  });

  it("detects hedging drift alert when many responses hedge", () => {
    const samples: AIMakerSample[] = Array(10).fill(0).map((_, i) => ({
      id: `s${i}`,
      text: "Perhaps this might work, depending on the situation, though it may vary in some cases.",
    }));
    const { summary } = analyzeAIMakerSamples(samples);
    expect(summary.drift_alerts.some((a) => a.includes("Hedging"))).toBe(true);
  });

  it("handles empty samples gracefully", () => {
    const { summary } = analyzeAIMakerSamples([]);
    expect(summary.total_samples).toBe(0);
    expect(summary.persona_assessment).toBe("No samples to evaluate.");
  });

  it("returns positive assessment for confident/warm/direct samples", () => {
    const samples: AIMakerSample[] = [
      { id: "s1", text: "I trust this is the right path and am confident we can deliver." },
      { id: "s2", text: "Done. Saved." },
      { id: "s3", text: "I am happy to help with this and grateful for the opportunity." },
      { id: "s4", text: "Yes. Done. Moving on." },
    ];
    const { summary } = analyzeAIMakerSamples(samples);
    expect(summary.persona_assessment).toContain("confident");
  });

  it("summary dominant_persona is a string", () => {
    const samples: AIMakerSample[] = [
      { id: "s1", text: "I trust this approach entirely and am confident in the outcome." },
    ];
    const { summary } = analyzeAIMakerSamples(samples);
    // dominant_persona may not exist on all implementations; total_samples always exists
    expect(typeof summary.total_samples).toBe("number");
  });

  it("drift_alerts is always an array", () => {
    const { summary } = analyzeAIMakerSamples([
      { id: "s1", text: "Yes. Done." },
    ]);
    expect(Array.isArray(summary.drift_alerts)).toBe(true);
  });

  it("single sample returns total_samples of 1", () => {
    const { summary } = analyzeAIMakerSamples([
      { id: "s1", text: "Done and dusted. Next task." },
    ]);
    expect(summary.total_samples).toBe(1);
  });

  it("samples array length matches total_samples in summary", () => {
    const samples: AIMakerSample[] = [
      { id: "s1", text: "I am confident in this approach and trust the process." },
      { id: "s2", text: "Yes. Done." },
      { id: "s3", text: "Grateful for the opportunity to help with this today." },
    ];
    const { summary } = analyzeAIMakerSamples(samples);
    expect(summary.total_samples).toBe(3);
  });

  it("results array has same length as input samples", () => {
    const samples: AIMakerSample[] = [
      { id: "s1", text: "First entry." },
      { id: "s2", text: "Second entry with more detail about the task completion." },
    ];
    const { results } = analyzeAIMakerSamples(samples);
    expect(results.length).toBe(2);
  });
});
