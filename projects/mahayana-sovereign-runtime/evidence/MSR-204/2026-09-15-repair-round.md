# MSR-204 repair round — 2026-09-15

This record binds the repair round to the live draft PR `#2620` and its unique canonical branch `feat/msr-204-hermes-gateway-transcript`.

## Bound state

- Canonical `main` observed before this round: `944461ea020966dd76905c7e601d9e6c121ae4b3`.
- PR: `#2620` (`feat/msr-204-hermes-gateway-transcript`).
- Exact PR head observed before this repair: `6e09d852127f429e9916108c53f478fa9d98bdf7`.
- Current Hermes upstream `main` observed during this round: `78d338b9ee917b73468c38ba4633ed53de4942e6`.
- Existing Hermes architecture audit remains a pinned historical audit until its upstream delta is explicitly reviewed; no unreviewed upstream code is silently imported.

## Failure-driven repair target

Exact-head CI and manifest readback narrowed this round to two concrete regressions:

1. `Mahayana fast checks` reaches the direct Host test and then invokes nonexistent crate features (`test-host`, later also `production-host` / `desktop`) even though the canonical crate manifests expose `local-only`, `production`, and `desktop-full`. The workflow must use real feature names rather than manufacturing CI-only names.
2. `mahayana-gateway-peer` merges Rust-locked clarify answers before client answers, allowing a stale reconnect response to overwrite a server-owned locked answer. Rust authority requires applying client answers first and locked answers last, with a regression test.

Temporary self-modifying repair plumbing is permitted only to perform this one bounded source correction and must remove itself. The canonical end state must restore read-only workflow permissions and ordinary source-controlled CI.

## Acceptance for this repair round

- Locked clarify answers win over stale client answers and are covered by `mahayana-gateway-peer` tests.
- Temporary `MSR-204 peer authority repair` / branch-writing repair plumbing is deleted after applying the bounded fix.
- `Mahayana fast checks` uses only features present in the corresponding Cargo manifests.
- Gateway/protocol/peer tests, direct Host, feature Host, FFI boundary, CLI gateway compilation, TypeScript/build, and Desktop E2E pass on one exact PR head.
- No routine Workbench completion card is restored to the main Messenger transcript.

This evidence record does **not** claim full Hermes parity or task completion. MSR-204 remains in progress until the broader parity matrix, Rust session/replay authority, common stdio/WebSocket/native semantics, protected-main merge, and canonical-main packaged evidence are closed.
