# 65 — 2026-09-05 M6 MAINSAFE Rust blocker milestones

## BM0 — blocker diagnosed
Complete when canonical main, #2335/#2336 lineage and changed-files, execution records, exact-head Actions and failure logs have been read back from GitHub; the three compiler diagnostics are classified as one shared `engine.rs` audit-ownership boundary defect; Mahayana Harness/social Actor failures are classified from logs rather than guessed.

Status: `COMPLETE`.

## BM1 — ownership repair exact-head accepted by Actions
`TFI-M6-MAINSAFE-001-OWNERSHIP-001` changes only `native/mahayana-messaging/src/engine.rs` plus TFI records and satisfies AC01–AC07 on the exact resulting #2336 head. Compile success alone is insufficient: messaging contracts, Clippy and Mahayana Harness must actually execute and pass.

Status: `NOT_STARTED`.

## BM2 — parent MAINSAFE-001 independently reviewed
Only after BM1 may a fresh independent code-review session review the exact main-based #2336 diff. Historical #2323 child-stack review cannot satisfy this milestone.

Status: `BLOCKED_BY_BM1`.

## BM3 — parent MAINSAFE-001 accepted on protected canonical main
Only after BM2 PASS plus all required exact-head Actions PASS may the protected merge queue accept the product PR. Exact canonical-main readback is mandatory before declaring `TFI-M6-MAINSAFE-001-RUST-CANONICAL` complete.

Status: `BLOCKED_BY_BM2`.

## BM4 — upper layers remain locked
`TFI-M6-MAINSAFE-002-ELECTRON-PROJECTION` remains blocked until BM3 exact canonical readback. `003-P0-CREATE-JOIN` remains blocked until 002 is accepted/read back. Test release/formal release remain blocked after that until their own frozen prerequisites are met.
