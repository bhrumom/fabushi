# 67 — 2026-09-05 M6 MAINSAFE Rust blocker risks and dependencies

## R1 — scope inflation — critical
The observed compiler diagnostics are local to `engine.rs`. Expanding into community/conversation/protocol/service/tests/workflows/Cargo would destroy atomicity and exceed this repair's evidence. Mitigation: one production-file allowlist; any need for another file is `SCOPE-EXPANSION-REQUIRED` and returns to architecture.

## R2 — semantic repair disguised as borrow fix — critical
Moving participant projection earlier, changing audit target semantics, changing authorization/order, or redesigning `append_community_audit` could compile while altering business behavior. Mitigation: preserve current control-flow/event semantics; create independent owned identity only where audit storage requires ownership.

## R3 — stale Actions identifiers — high
Several run/job IDs in the execution handoff no longer describe the latest attempt. Mitigation: acceptance records both the handed snapshot and current exact-head GitHub readback; workflow name + exact head + latest attempt are authoritative.

## R4 — generic green CI false closure — critical
`CI result` and auxiliary governance/automerge checks are green while three Rust workflows fail. Mitigation: AC03–AC06 are mandatory and non-substitutable.

## R5 — downstream failure misclassification — high
The Mahayana Harness and current social Actor jobs fail while compiling `fabushi-messaging-core`. Treating them as independent would create duplicate work; treating a later different error as the same would hide scope expansion. Mitigation: current baseline classifies them as derived; after compile advances, any distinct failure stops and returns to architecture.

## R6 — ownership overengineering / supply chain — critical
Changing `ActorId` to shared ownership, adding dependencies, or importing upstream code is unnecessary. Mitigation: no Cargo/dependency/type redesign. External research contributes design principles only; no copied implementation.

## R7 — sequencing bypass — critical
Starting 002/003, review, merge, test-release, or formal release before 001's exact Actions/review/queue/readback would violate the protected-main-safe dependency chain. Mitigation: strict BM1→BM2→BM3→002→003 chain.

## Dependencies
1. This records-only architecture handoff must be committed, pushed, opened as a main-based records PR and read back.
2. A fresh execution-group session may then perform only `TFI-M6-MAINSAFE-001-OWNERSHIP-001` on the existing #2336 lineage.
3. Fresh code review is blocked until that task has exact-head Actions evidence satisfying AC01–AC07.
4. 002 is blocked until parent 001 is protected-merged and canonical main is read back; 003 is blocked on 002.
