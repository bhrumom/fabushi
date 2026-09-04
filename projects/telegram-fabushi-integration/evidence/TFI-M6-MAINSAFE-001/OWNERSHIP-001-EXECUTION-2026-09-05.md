# TFI-M6-MAINSAFE-001-OWNERSHIP-001 evidence — 2026-09-05

## Identity
- Project/task: `FAB-P0001 / TFI` / `TFI-M6-MAINSAFE-001-OWNERSHIP-001`.
- Canonical main at execution start: `688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- Architecture records PR/head: `#2337@ea9b5b62d22ed73b9de350075797ea4c54eb69e4`.
- Product PR start: `#2336@115cd55065d03b66f14d7e086d454709d24d2286`, base canonical main, open/unmerged.
- Product repair commit: `bd0fb654212469bf88a95d558ebf12fd11efd658`.
- First verified code-bearing head: `7f7da51fa7a3d91c5df9482d38ca58c50cc0c7cc`.

## Static repair evidence
GitHub compare `115cd550... -> bd0fb654...` reports exactly one changed product file, `native/mahayana-messaging/src/engine.rs`, 4 additions / 4 deletions:
- SubscribeChannel audit target -> `Some(actor_id.clone())`.
- UnsubscribeChannel audit target -> `Some(actor_id.clone())`.
- RespondCommunityJoin approved audit target -> `Some(requester_id.clone())`.
- RespondCommunityJoin rejected audit target -> `Some(requester_id.clone())`.
No helper/public API/type/control-flow/error/audit semantic change and no second product/test file.

## Baseline failure evidence
Messaging Product Gate `33914564827` / Rust job `101158638727` at `115cd550...`:
- rustfmt PASS;
- `cargo test --all-targets` compile FAIL in `fabushi-messaging-core`;
- E0505 `engine.rs:1789`, E0505 `engine.rs:1825`, E0382 later borrow `engine.rs:2204` after requester moves at old `2171`/`2185`;
- `m6_channels_topics_contract` and `unread_projection_contract` did not execute;
- messaging Clippy skipped.

## Code-bearing-head success evidence (`7f7da51...`)
- Messaging Product Gate run `33917477384` SUCCESS.
  - Rust self-hosted product job `101167888840` SUCCESS.
  - Electron Messenger contract job `101167888469` SUCCESS.
  - Rustfmt actually executed and passed.
  - `cargo test --manifest-path native/mahayana-messaging/Cargo.toml --all-targets` actually executed and passed.
  - `m6_channels_topics_contract.rs`: 2/2 tests passed.
  - `unread_projection_contract.rs`: 4/4 tests passed.
  - Messaging Clippy command with `--all-targets -- -D warnings` actually executed and passed.
- Fabushi self-hosted messaging run `33917477418` SUCCESS.
  - Rust messaging core job `101167888795` SUCCESS (rustfmt/test/clippy successful).
  - Mahayana social -> messaging Actor job `101167889079` SUCCESS.
- Mahayana fast checks run `33917477424` SUCCESS.
  - Rust protocol, Host, and bridge fast job `101167888656` SUCCESS.
  - `Test Rust-native Mahayana Harness` actually executed and passed; subsequent direct Host, deterministic feature Host, production adapter and embedded FFI steps also passed.
- CI run `33917477416` SUCCESS.
- Project portfolio governance run `33917477434` SUCCESS.
- Developer Fiat Commerce run `33917477447` SUCCESS.
- Explicit automerge run `33917477381` SUCCESS.

No new non-ownership error or second-source-file requirement appeared.

## Open-source-first and local verification
Execution follows the frozen Rust E0505/E0382 + Ruma/Matrix borrowed/owned identity boundary decision; no upstream implementation copied and no dependency/license surface changed. No local build/test/rustfmt/clippy/E2E was run.

## Final-head rule
The code-bearing head has AC01-AC07 evidence. This evidence update itself will create a records-only final PR head, so that final head must receive its own live required/selected GitHub validation before the task can be handed to independent review. Old-head results are evidence for the unchanged code tree, not a substitute for final-head status checks.
