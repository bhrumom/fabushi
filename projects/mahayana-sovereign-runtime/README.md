# Mahayana Sovereign Runtime

## Objective
Turn Mahayana into a Fabushi-owned coding/agent product that absorbs the strongest capabilities of `openai/codex` and `xai-org/grok-build` without making either upstream product the public architecture, identity, protocol, or lifecycle owner.

## Current verified state
- PR #1971 merged to `main` as `5dcfaee4b8fb12896f9ac92c6dbc51317d10b942` and is the canonical convergence implementation baseline.
- `mahayana-kernel`, supervisor, orchestrator, workspace engine, model/native engine, MCP runtime and agent bridge exist on `main`.
- `third_party/mahayana/mahayana-rs/SOURCES.lock` records reviewed upstream provenance and boundaries.
- Migration remains incomplete; implementation presence is not completion evidence.

## 2026-09-04 P0 cross-project contract
Program `FAB-ARCH-P0-20260904` makes MSR the **only** Bot runtime/session/policy owner for TFI/GBF integration. Every canonical Bot identity binds to exactly one durable Mahayana session; conversation/group/topic are contexts inside that session. Device/MiniApp/tool execution passes through MSR policy/approval/audit.

PR #2320 architecture head `21ee56892db48925fe863320a1cd68b51c4596cd` was `REVIEW-REJECTED`; review write-back reached `a0333f32a5d0edc04723c49fc53a5997a3b0fe1e`. This repair is only ready for fresh review. `MSR-201` and `MSR-202` are still `in-progress`; `GBF-409` and `GBF-411` are still `IN_PROGRESS`. Therefore MSR-210/211 are hard-gated and may not be treated as accepted foundations yet.

Authoritative P0 tasks: `MSR-107`, `MSR-210`, `MSR-211`. Each task file is self-contained; shared docs cannot fill missing execution or acceptance conditions.

## Source of truth
See `SOURCE_OF_TRUTH.md`. GitHub `main`, this project folder, accepted ADRs, and live GitHub facts are authoritative.
