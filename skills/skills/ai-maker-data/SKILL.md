---
name: ai-maker-data
description: "Use this skill when the user needs to interpret metrics, understand what data means, build a data visualization, or define what to measure. Triggers include: 'what does this data mean', 'interpret these metrics', 'build a chart', 'create a dashboard', 'show me a trend', 'what should we measure', 'data summary', 'metrics report', 'anomaly in the data', or any request to make sense of numbers for a business decision. Do NOT use for building technical data pipelines or processing large datasets — use ai-workbench-data for that."
# version: 1.0.0 / source: FI / category: ai-maker
---

# AI Maker Data

Data pipelines, metrics interpretation, and dashboard creation for managers. This skill helps you understand what your data means, build visualizations to share it, and make decisions from it.

## When to invoke

Use this skill when you need to:
- Interpret a metrics report or dashboard and explain what it means
- Build a simple data visualization or summary table from raw data
- Define what metrics matter for a project or initiative
- Spot trends, anomalies, or gaps in a dataset
- Design a dashboard layout for a team or executive audience

## What it does

1. **Interprets metrics** — explains what numbers mean in context, flags anomalies, and identifies trends
2. **Builds visualizations** — creates HTML/CSS charts, tables, and dashboards from provided data
3. **Defines metrics** — recommends what to measure for a given goal and how to instrument it
4. **Finds patterns** — identifies correlations, outliers, and signals in structured data
5. **Formats for audience** — executive dashboard vs engineering metrics board vs team health scorecard

## Key behaviors

- Context-first — never interprets a number without knowing what it's measuring and why
- Anomaly-flagging — calls out data that doesn't fit the pattern before presenting the trend
- Honest about uncertainty — distinguishes "the data shows" from "this could indicate"
- Actionable — connects metrics to decisions; data without implication is not the goal

## Output formats

- Metrics interpretation summary
- HTML dashboard or visualization
- Trend analysis with anomaly notes
- Metrics definition framework (what to track + why)

## Scope

This skill covers business metrics and data interpretation for managers. For technical data pipeline construction, sentiment analysis, or large-scale data processing, use **AI Workbench Data**.
