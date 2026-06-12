---
name: ai-workbench-data
description: "Use this skill to build data pipelines, instrument applications, process structured data files, or automate report generation. Triggers include: 'build a pipeline', 'ETL', 'process this CSV', 'parse this JSON', 'instrument this app', 'emit metrics', 'data transformation', 'automate this report', 'query this data', 'data processing script', or any request to construct the technical systems that collect, transform, or serve data. Do NOT use for interpreting what metrics mean for a manager audience — use ai-maker-data for that."
# version: 1.0.0 / source: FI / category: ai-workbench
---

# AI Workbench Data

Technical data pipeline construction, metrics instrumentation, and large-scale data processing for developers. This skill builds the systems that collect, transform, and serve data — not just interpret it.

## When to invoke

Use this skill when you need to:
- Build a data pipeline: ingest → transform → store → serve
- Instrument an application to emit metrics or telemetry
- Parse and process structured data (CSV, JSON, JSONL, Parquet)
- Set up a dashboard backend or data query layer
- Automate report generation from a data source

## What it does

1. **Pipeline construction** — designs and implements ETL pipelines with clear stage contracts (output of each stage is the input of the next)
2. **Instrumentation** — adds logging, metrics emission, and telemetry to an application
3. **Data processing** — writes scripts to parse, transform, filter, and aggregate structured data sets
4. **Query layer** — builds SQL queries, data views, and API endpoints to serve processed data
5. **Report automation** — generates reports from data sources on a schedule or trigger

## Key behaviors

- Stage contracts — every pipeline stage has a defined input schema and output schema
- Idempotent pipelines — re-running a pipeline produces the same result, doesn't duplicate data
- Error isolation — pipeline failures are logged with the record that caused them; don't fail the whole run for one bad record
- Schema-explicit — data structures are typed and documented, not implicit

## Output formats

- Pipeline design document (stages, contracts, error handling)
- Processing script (Python, PowerShell, or TypeScript)
- SQL query or view definition
- Instrumentation addition to existing code

## Scope

This skill covers technical data pipeline and processing work. For interpreting metrics and building business dashboards for non-technical audiences, use **AI Maker Data**.
