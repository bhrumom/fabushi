---
name: resource-finder-downloader
description: Use when the user wants to find, verify, download, and prepare legally shareable dharma or learning resources. Supports multi-step resource search, selecting a credible source, downloading readable text, and preparing the result for global dharma sharing or a practice book.
---

# Resource Finder Downloader

Use this skill when a user asks to search for downloadable resources, fetch Buddhist/dharma materials, prepare a resource for global dharma sharing, or save a found resource into a practice book.

## Workflow

1. Clarify the resource target only when it is ambiguous: title, topic, language, format, or whether public-domain/open-access sources are required.
2. Prefer public, canonical, and legally shareable sources. For Buddhist texts, search CBETA first through the Dacheng AI backend.
3. Search before downloading unless the user provides a direct URL.
4. Summarize the candidate source, including title, source name, URL, and why it is appropriate.
5. Download/extract readable text through `scripts/find_and_download_resource.mjs`.
6. Return the local output path and the source URL. If the resource is for the app, mention it can be used for one-click global dharma sharing or saved into the Zen Room practice book.

## Script

Use the bundled script for deterministic backend calls:

```bash
node skills/resource-finder-downloader/scripts/find_and_download_resource.mjs "金刚经" --output /tmp/dharma-resource
```

Options:

- `--backend <url>`: Override the Dacheng AI backend. Defaults to `DACHENG_AI_BACKEND_URL` or `http://144.24.17.21`.
- `--limit <n>`: Search result count. Defaults to `8`.
- `--pick <n>`: Download the nth result, 1-based. Defaults to `1`.
- `--output <dir>`: Output directory. Defaults to the current directory.
- `--json-only`: Write only JSON metadata, without the extracted text file.

## Guardrails

- Do not download obviously pirated, paywalled, private, or login-gated material.
- If the source appears copyrighted, provide the link and a short summary instead of copying large text.
- Preserve source attribution in the generated text file.
- Keep final answers concise: candidate chosen, output path, source URL, and next action.
