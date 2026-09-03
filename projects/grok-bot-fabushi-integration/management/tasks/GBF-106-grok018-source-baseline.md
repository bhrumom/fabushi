# GBF-106 — Pin and classify Grok Bot 0.18 reconstructed source

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-106`
- Status: `RELEASED`
- Started: `2026-08-24 17:36 +08:00`
- Updated: `2026-08-24 17:57 +08:00`
- Completed: `2026-08-24 17:57 +08:00`
- Branch: `codex/gbf-grok018-fusion`
- Commit / PR: `d9ec679d2` / [#2105](https://github.com/bhrumom/fabushi/pull/2105) / merge `4520415a8a7e6beb6e5906ad547c692ad2dde0f3`

## Objective

Pin the user-specified reconstructed repository, recursively classify every tracked path, identify net-new observable capabilities, and establish the legal/provenance boundary before implementation.

## Source requirements

- `source/2026-08-24-grok-bot-018-reconstructed-fusion.md`
- `GBR-001`, `GBR-002`, `GBR-008`, `GBR-009`

## In scope

- Exact source commit/tree identity.
- Full Git tree manifest with capability domain and per-path decision.
- NOTICE/PROVENANCE/license assessment.
- Delta mapping into existing GBF/Mahayana architecture.

## Out of scope

- Copying installer binaries, packaged renderer, recovered/generated code, or unlicensed source verbatim.
- Building or running either desktop app locally.

## Dependencies

- Canonical Fabushi `main` at `92deb4dd63efae607b54d14e9e83750248b74a4f`.
- Source commit `a9f633e09d49a85829b8236331b9e21f7e612634`.

## Acceptance criteria and verification

1. Source commit/tree are exact and immutable — Git object verification: locally passed.
2. Every tracked path has a non-empty domain and reuse decision — deterministic manifest validation: 2,111 / 2,111 passed.
3. No path is classified for direct copying — summary assertion: passed.
4. Net-new features have target tasks/architecture owners — WBS/ADR readback: GBF-307/308/408/506/805 + ADR-0007 recorded.
5. Project records and evidence merge through protected `main` — passed; PR #2105 merged and canonical-main readback matched.

## Open-source survey and decision

- Primary candidate: `bhrum/grok-bot-0.18-reconstructed`, the user-specified public repository. It is a source-oriented reconstruction with no asserted/granted upstream source license; use as behavior/API evidence only.
- Existing candidate: `xai-org/grok-build` (Apache-2.0), already reviewed in GBF Round 12. It informs Rust agent architecture but is not a desktop Messenger/Router implementation.
- Decision: retain Fabushi Electron + Rust Mahayana sovereign runtime; clean-room adapt observable Router, MCP routing, usage, sandbox, and UI behavior. Do not vendor a second Node/Grok runtime.

## Evidence

- Generated: `evidence/GBF-106/manifest.tsv` (SHA-256 `8efec1d11bc87188e9945c5336d66ae0232d1511561a7e9ead3175b7fa564985`), `summary.json`, `README.md`.
- Result: 2,111 entries; 29 `ADAPT_DESIGN`, 1,693 `CLEAN_ROOM_SPEC`, 347 `LEARN`, 42 `REJECT`; all five deterministic validation assertions true.
- GitHub PR/CI/main: PR #2105; CI run `32713096020` passed, portfolio run `32713095842` passed, security run `32713095963` passed, rollback run `32713095954` passed; merged as `4520415a8a7e6beb6e5906ad547c692ad2dde0f3` and read back from canonical `main`.
- Post-main product delivery: N/A for the audit-only portion; subsequent runtime/UI implementation tasks own packaged E2E and Release evidence.

## Risks / blockers

- Unlicensed reconstructed and recovered material is reference-only.
- A path manifest proves coverage, not behavioral parity; downstream implementation tasks remain required.

## Next action

Continue GBF-307/506 provider-router vertical slice; GBF-106 itself has no remaining gate.
