---
name: ai-workbench-vision
description: "Use this skill to extract text or data from images, scanned documents, or PDFs using OCR. Triggers include: 'extract text from this image', 'OCR', 'read this scan', 'PDF extraction', 'parse this form', 'digitize this document', 'extract fields from', 'process these scanned pages', 'vision', 'what does this image say', or any request to get structured data out of an image or document. Do NOT use for data transformation after extraction — use ai-workbench-data for that."
# version: 1.0.0 / source: Shared / category: ai-workbench
---

# AI Workbench Vision & Scanning

OCR, PDF extraction, image processing, and document digitization for developers. This skill reads documents and images to extract structured data that can feed into pipelines or analyses.

## When to invoke

Use this skill when you need to:
- Extract text or data from a scanned document, image, or PDF
- Convert a handwritten or printed form into structured data
- Build a pipeline that ingests document images and produces structured output
- Process a batch of PDF files to extract specific fields
- Interpret image content for downstream automation

## What it does

1. **OCR** — extracts text from images, scanned PDFs, and photos using available vision tools
2. **PDF extraction** — pulls structured text, tables, and field values from PDF documents
3. **Form parsing** — identifies form fields and their values from document images
4. **Batch pipeline design** — designs a scan → OCR → extract → validate → output pipeline for document processing
5. **Quality assurance** — validates OCR output against expected patterns; flags low-confidence extractions

## Key behaviors

- Confidence-rated output — flags extractions that are uncertain or low-quality
- Structured output — returns data in a defined schema (JSON, CSV), not raw text dumps
- Pipeline-ready — output is designed to feed the next stage; zero manual cleanup required
- Error isolation — bad pages or low-quality images are logged separately, don't halt the pipeline
- Format-specific — knows the difference between digital PDFs (extractable) and scanned PDFs (requires OCR)

## Output formats

- Extracted text or structured data (JSON/CSV)
- Form field extraction result
- Batch pipeline design with stage contracts
- OCR quality report with flagged low-confidence fields

## Scope

This skill covers document digitization and image-based data extraction. For data transformation after extraction, use **AI Workbench Data**. For general file processing automation, use **AI Workbench PowerShell**.
