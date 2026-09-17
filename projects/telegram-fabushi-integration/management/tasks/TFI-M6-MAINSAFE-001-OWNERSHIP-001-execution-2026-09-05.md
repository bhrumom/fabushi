# TFI-M6-MAINSAFE-001-OWNERSHIP-001 execution — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Atomic task: `TFI-M6-MAINSAFE-001-OWNERSHIP-001`
- Architecture source: records-only PR `#2337@ea9b5b62d22ed73b9de350075797ea4c54eb69e4`
- Architecture task: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-OWNERSHIP-001.md`
- Architecture handoff: product PR `#2336` comment `5546113012`.
- Canonical base read before implementation and before first push: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- Existing product PR: `#2336`, branch `fix/tfi-m6-mainsafe-001-rust-canonical`, starting exact head `115cd55065d03b66f14d7e086d454709d24d2286`, open/unmerged and based on canonical main.
- Code repair commit: `bd0fb654212469bf88a95d558ebf12fd11efd658`.
- First code-bearing execution head: `7f7da51fa7a3d91c5df9482d38ca58c50cc0c7cc`.
- State after first code-bearing-head verification: `CODE-HEAD-AC01-AC07-PASS / FINAL-RECORD-HEAD-REVALIDATION-REQUIRED / REVIEW-BLOCKED`.

## Frozen scope and implementation
Production allowlist for this atomic task is exactly `native/mahayana-messaging/src/engine.rs`; execution records are limited to `projects/telegram-fabushi-integration/**`.

The repair keeps canonical identities available for borrow-based lookup/control flow and creates a distinct owned value only at the retained audit target sink:
1. `Command::SubscribeChannel`: old E0505 at `engine.rs:1789`; `Some(actor_id)` -> `Some(actor_id.clone())` at the `SubscriptionAdded` audit target.
2. `Command::UnsubscribeChannel`: old E0505 at `engine.rs:1825`; `Some(actor_id)` -> `Some(actor_id.clone())` at the `SubscriptionRemoved` audit target.
3. `Command::RespondCommunityJoin`: old E0382 later borrow at `engine.rs:2204`, caused by audit-target moves at old lines `2171`/`2185`; both mutually exclusive audit targets use `Some(requester_id.clone())` so later participant projection can still borrow `requester_id`.

No helper signature, public API, type, permission check, membership lookup, audit action/field, error text, event order, control flow, dependency or shared-ownership architecture changed. GitHub compare `115cd550... -> bd0fb654...` proved exactly one changed file, `engine.rs`, with 4 additions / 4 deletions. No old #2323 commit or 34-commit stack was moved/cherry-picked.

## Open-source-first decision
Execution follows architecture evidence `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/ARCHITECTURE-RUST-BLOCKER-DIAGNOSIS-2026-09-05.md`: Rust official E0505/E0382 ownership guidance plus the Ruma/Matrix borrowed identity / retained owned identity pattern. No upstream implementation was copied; no dependency or license surface was added.

## Baseline failure evidence (`#2336@115cd550...`)
Messaging Product Gate run `33914564827`, Rust job `101158638727`: rustfmt PASS, then `cargo test --all-targets` failed compiling `fabushi-messaging-core` with E0505/E0505/E0382; `m6_channels_topics_contract`, `unread_projection_contract`, and messaging Clippy did not execute. Architecture also confirmed self-hosted messaging and Mahayana Harness failures at this head were downstream manifestations of the same core compile blocker.

## First code-bearing-head Actions (`#2336@7f7da51...`)
All seven selected workflows completed SUCCESS:
- Messaging Product Gate run `33917477384`: Rust self-hosted product job `101167888840` SUCCESS; Electron Messenger contract job `101167888469` SUCCESS.
  - Rustfmt SUCCESS.
  - `cargo test --manifest-path native/mahayana-messaging/Cargo.toml --all-targets` SUCCESS.
  - `m6_channels_topics_contract.rs` actually executed: 2 passed, 0 failed.
  - `unread_projection_contract.rs` actually executed: 4 passed, 0 failed.
  - `cargo clippy --manifest-path native/mahayana-messaging/Cargo.toml --all-targets -- -D warnings` actually executed and SUCCESS.
- Fabushi self-hosted messaging run `33917477418`: Rust messaging core job `101167888795` SUCCESS; Mahayana social -> messaging Actor job `101167889079` SUCCESS.
- Mahayana fast checks run `33917477424`: Rust protocol, Host, and bridge fast job `101167888656` SUCCESS. `Test Rust-native Mahayana Harness` actually executed and SUCCESS; direct Host, deterministic feature Host, production adapters and embedded FFI also succeeded.
- CI run `33917477416` SUCCESS.
- Project portfolio governance run `33917477434` SUCCESS.
- Developer Fiat Commerce run `33917477447` SUCCESS.
- Explicit automerge run `33917477381` SUCCESS.

No distinct post-repair non-ownership failure appeared. The ownership compile blocker is therefore removed on the code-bearing head without scope expansion.

## Verification policy and finalization
No local build, test, rustfmt, clippy, Electron, native-app or E2E command was run. Only live GitHub reads plus lightweight Git/text/tree/diff checks were used.

This record update is governance-only. Because committing these records changes the PR exact head, the resulting final records-only head must be re-read and its own selected/required GitHub Actions must complete before the execution session may emit `EXECUTION-OWNERSHIP-001-PASS-CANDIDATE`. Until then independent review, merge, test release and formal release remain blocked.
