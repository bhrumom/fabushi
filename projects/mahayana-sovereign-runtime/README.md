# Mahayana Sovereign Runtime

## Objective
Turn Mahayana into a Fabushi-owned coding/agent product that absorbs the strongest capabilities of `openai/codex` and `xai-org/grok-build` without making either upstream product the public architecture, identity, protocol, or lifecycle owner.

## Current verified state
- PR #1971 merged to `main` as `5dcfaee4b8fb12896f9ac92c6dbc51317d10b942` and is the canonical convergence implementation baseline.
- `mahayana-kernel`, supervisor, orchestrator, workspace engine, model/native engine, MCP runtime and agent bridge exist on `main`.
- `third_party/mahayana/mahayana-rs/SOURCES.lock` records reviewed upstream provenance and boundaries.
- The migration is **not complete**: `mahayana-product` still contains Codex login/secrets compatibility dependencies, and full native parity / upstream isolation remains to be proven by CI and E2E evidence.

## Current stage
`M1 — capability inventory and native-boundary closure`

Next gate: complete a source-backed capability matrix for current Codex/Grok Build revisions, then close the remaining product-level Codex dependency boundaries without regressing existing Fabushi Electron/native paths.

## Scope
In scope: sovereign kernel/runtime, sessions, workspace, tools, memory, workflows, extensions, models, policy, headless/CLI/ACP, Electron/iOS/Android/Web integration, migration from upstream-specific types, conformance tests, provenance/license gates.

Non-goals: cosmetic renaming of vendor code; wholesale history merge of upstream repositories; restoring retired Flutter/Tauri product architecture; claiming parity without objective evidence.

## Source of truth
See `SOURCE_OF_TRUTH.md`. GitHub `main`, this project folder, accepted ADRs, and live CI facts are authoritative.

## Navigation
- Product/engineering specs: `docs/`
- Roadmap/WBS/status: `management/`
- Decisions: `decisions/`
- Evidence: `evidence/`
- Runbooks: `runbooks/`
