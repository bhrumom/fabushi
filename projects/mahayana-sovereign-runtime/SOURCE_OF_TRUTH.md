# Source of Truth

## Authoritative engineering state
1. `bhrumom/fabushi` GitHub `main` for implementation facts.
2. This project folder for durable requirements, WBS, ADRs and evidence indexes.
3. Accepted ADRs/current specs.
4. Live GitHub PR/CI/release facts.
5. External mirrors/chat memory only as inputs.

## Original requirement
Mahayana is a Fabushi-owned product that studies and fuses useful strengths of `openai/codex` and `xai-org/grok-build` while keeping its own public architecture, identity, protocol and lifecycle.

## Canonical convergence and provenance
PR #1971 merged as `5dcfaee4b8fb12896f9ac92c6dbc51317d10b942`. Historical reviewed baselines remain recorded. The 2026-09-04 architecture audit pins Codex `8e85265c39176b6bd498242a33d7b0f9b4b98303` and Grok Build `72a61251fcffb464bcc687aeb5a998e5a98ec0c9`; both root LICENSE files are Apache-2.0. Codex root NOTICE must be preserved when applicable. These revision-level facts are inventory inputs, **not** permission to copy arbitrary files and not implementation provenance by themselves.

### Implementation-time exact-file provenance gate
Any execution task that actually adapts, ports, copies, substantially derives from, or directly studies an upstream implementation must record **before acceptance**: upstream repository; exact upstream file path; exact revision; file/applicable license; required LICENSE/NOTICE/attribution disposition; whether the implementation is adapted/reimplemented/rejected; and a concrete adaptation note mapping upstream concept to Fabushi-owned code. This record belongs in that execution task and its evidence ledger. Architecture-level SHA/license pins cannot substitute for exact-file evidence.

If license/rights for a file are unclear, that file is not used. `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d` is not an implementation source: missing root LICENSE/provenance uncertainty means only clean-room observable behavior/UI/IPC evidence may be referenced; implementation code must not be copied.

## 2026-09-04 cross-project authority and live gates
MSR owns the only Bot execution/runtime/session/policy plane; TFI owns messaging/MiniApp projection; GBF owns behavior and same-account device/App MCP capability semantics.

PR #2320 reviewed head `21ee56892db48925fe863320a1cd68b51c4596cd` remains `REVIEW-REJECTED` until fresh review of the latest repair head. Canonical `MSR-201` and `MSR-202` are currently `in-progress` with commit/PR/CI evidence pending. Canonical `GBF-409` and `GBF-411` are `IN_PROGRESS` with required GitHub CI/E2E/exact-main delivery evidence pending. Accordingly, MSR-210/211 cannot close on “existing/reuse” prose; their task-local hard gates must be satisfied first, followed by their own review/merge/CI/exact-main packaged evidence.

## Conflict rule
When project docs conflict with actual code/CI, record the discrepancy and correct the project record using live evidence; never rewrite history or promote planned/pending work to passed.
