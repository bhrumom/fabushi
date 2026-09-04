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

## 2026-09-04 P0 cross-project contract

Program `FAB-ARCH-P0-20260904` makes MSR the **only** Bot runtime owner for TFI/GBF integration. Every canonical Bot identity must bind to exactly one durable Mahayana session; conversation/group/topic context is scoped inside that session. All device/MiniApp/tool execution passes through MSR policy/approval/audit.

Read `docs/2026-09-04-bot-runtime-contract.md`, `management/09-2026-09-04-P0-WBS.md`, `management/tasks/MSR-107-upstream-capability-refresh.md`, `management/tasks/MSR-210-bot-durable-session-binding.md`, and `management/tasks/MSR-211-bot-capability-policy-plane.md`.

## Source of truth
See `SOURCE_OF_TRUTH.md`. GitHub `main`, this project folder, accepted ADRs, and live CI facts are authoritative.

## Navigation
- Product/engineering specs: `docs/`
- Roadmap/WBS/status: `management/`
- Decisions: `decisions/`
- Evidence: `evidence/`
- Runbooks: `runbooks/`
