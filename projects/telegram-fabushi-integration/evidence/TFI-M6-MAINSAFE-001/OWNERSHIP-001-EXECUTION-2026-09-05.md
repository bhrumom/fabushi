# TFI-M6-MAINSAFE-001-OWNERSHIP-001 evidence — 2026-09-05

## Identity
- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-OWNERSHIP-001`
- Canonical main readback before implementation: `688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- Architecture records PR/head: `#2337@ea9b5b62d22ed73b9de350075797ea4c54eb69e4`.
- Product PR starting head: `#2336@115cd55065d03b66f14d7e086d454709d24d2286`, base `main@688465e...`, open/unmerged.

## Static repair evidence
- Product repair candidate commit: `bd0fb654212469bf88a95d558ebf12fd11efd658`.
- GitHub compare `115cd550... -> bd0fb654...`: one changed file only, `native/mahayana-messaging/src/engine.rs`, 4 additions / 4 deletions.
- Exact changed sinks:
  - SubscribeChannel audit target: `Some(actor_id.clone())`.
  - UnsubscribeChannel audit target: `Some(actor_id.clone())`.
  - RespondCommunityJoin approved audit target: `Some(requester_id.clone())`.
  - RespondCommunityJoin rejected audit target: `Some(requester_id.clone())`.
- No helper/public API/type/control-flow/error/audit semantic change.
- No second product/test file; no Electron/workflow/Cargo/dependency/version/root-governance change.

## Baseline failure evidence
Messaging Product Gate run `33914564827`, Rust job `101158638727`, exact head `115cd550...`:
- rustfmt PASS;
- `cargo test --all-targets` compile FAIL in `fabushi-messaging-core`;
- E0505 `engine.rs:1789`, E0505 `engine.rs:1825`, E0382 later borrow at `engine.rs:2204` after requester moves at `2171`/`2185`;
- `m6_channels_topics_contract` and `unread_projection_contract` did not execute;
- messaging Clippy was skipped.

Architecture also froze self-hosted messaging and Mahayana Harness failures at that head as downstream manifestations of the same messaging-core compile defect, not separate implementation tasks.

## Open-source-first evidence
Execution follows the already-frozen architecture decision: Rust official E0505/E0382 ownership guidance plus the Ruma/Matrix borrowed identity / retained owned identity boundary pattern. No upstream implementation is copied and no dependency or license surface changes.

## Dynamic acceptance
Pending until the final exact PR head is pushed and all required/selected Actions complete. Old head runs are baseline evidence only and will not be reused as acceptance.

## Local verification policy
No local build/test/rustfmt/clippy/E2E was run. Only GitHub reads and lightweight Git/text/diff/tree checks were used.

## Current classification
`EXECUTION-IN-PROGRESS / FINAL-HEAD-CI-PENDING / REVIEW-BLOCKED / MERGE-BLOCKED`.
