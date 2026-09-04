# 70 — 2026-09-05 M6 MAINSAFE Rust architecture handoff

Handoff state: `ARCHITECTURE-RUST-BLOCKER-DIAGNOSED / NEXT-ATOMIC-TASK-FROZEN`.

Product remains: `MAINSAFE-RUST-BLOCKED / SCOPE-EXPANSION-REQUIRED / CI-BLOCKED / CLOSURE-BLOCKED`.

## What architecture verified
- canonical main remained `688465e94647d4c866f6b1d7b4884145b2f4a9da` at freeze time;
- #2336 remained open/unmerged, base canonical main, diagnosed exact head `115cd55065d03b66f14d7e086d454709d24d2286`;
- #2336 retained only the original seven Rust source/test allowlist paths plus four TFI execution records;
- current exact-head Rust failure is one shared `engine.rs` audit ownership boundary defect: E0505 at subscription add/remove audit calls and E0382 after join-response audit target ownership transfer;
- current social Actor and Mahayana Harness failures are downstream compilation failures through the same messaging core at this baseline;
- generic CI/governance/automerge successes do not satisfy the failed Rust gates.

## Frozen next atomic task
`TFI-M6-MAINSAFE-001-OWNERSHIP-001`

Task path:
`projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-OWNERSHIP-001.md`

Only allowed production file:
`native/mahayana-messaging/src/engine.rs`

Additional allowed records:
`projects/telegram-fabushi-integration/**`

The fresh execution session must use the existing #2336 canonical-main lineage and re-read current main/base/head before modifying anything. If any second product/test file is needed or any new independent failure appears after compilation advances, STOP and return to architecture.

## Acceptance before code review
The exact repaired #2336 head must prove all of the following before code review begins:
- scope still matches the one-file repair allowlist;
- the three diagnosed ownership errors are gone without semantic/API/helper changes;
- Messaging Product Gate Rust job reaches and passes rustfmt, all-target cargo test and Clippy `-D warnings`;
- `m6_channels_topics_contract` and `unread_projection_contract` actually execute and pass;
- Fabushi self-hosted messaging Rust core and social Actor jobs pass;
- Mahayana fast Rust-native Harness passes, or any distinct new failure is stopped and re-planned;
- all current selected/required repository gates are green.

Only then may a fresh independent code-review session start. A review PASS still does not authorize direct merge: protected merge queue acceptance and exact canonical-main readback are required to finish parent 001.

## Locked work
Do not start MAINSAFE-002, MAINSAFE-003, code review, merge, canonical E2E, test release or formal release now. 002 remains dependent on accepted/read-back canonical 001; 003 remains dependent on accepted/read-back canonical 002.

## Unique next action after architecture handoff completes
Start one fresh execution-group session for `TFI-M6-MAINSAFE-001-OWNERSHIP-001`; nothing else.
