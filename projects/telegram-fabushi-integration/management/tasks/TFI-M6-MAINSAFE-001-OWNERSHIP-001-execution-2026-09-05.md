# TFI-M6-MAINSAFE-001-OWNERSHIP-001 execution — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Atomic task: `TFI-M6-MAINSAFE-001-OWNERSHIP-001`
- Group: execution
- Architecture source: records-only PR `#2337@ea9b5b62d22ed73b9de350075797ea4c54eb69e4`
- Architecture task: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-OWNERSHIP-001.md` at that exact architecture head.
- Architecture handoff: product PR `#2336` comment `5546113012`.
- Canonical base: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da` (live GitHub readback before implementation).
- Existing product PR: `#2336`, branch `fix/tfi-m6-mainsafe-001-rust-canonical`, starting exact head `115cd55065d03b66f14d7e086d454709d24d2286`, open/unmerged and still based on canonical main.
- Code repair commit prepared from that exact head: `bd0fb654212469bf88a95d558ebf12fd11efd658`.
- Status at initial record creation: `EXECUTION-IN-PROGRESS / FINAL-HEAD-CI-PENDING / REVIEW-BLOCKED`.

## Frozen scope
Production allowlist for this atomic task is exactly:
- `native/mahayana-messaging/src/engine.rs`.

Execution records may be added only under `projects/telegram-fabushi-integration/**`.

Forbidden: any other application source, test source, Electron file, workflow, Cargo/dependency/toolchain/lint configuration, version/release logic, root `AGENTS.md`, `projects/PORTFOLIO.json`, old task-record rewriting, retarget/rebase/force-push, or moving/cherry-picking the historical #2323 34-commit stack.

## Minimal ownership repair
The repair keeps canonical identities available for borrow-based lookup/control flow and creates a distinct owned value only at the retained audit target sink:
1. `Command::SubscribeChannel`: `Some(actor_id)` -> `Some(actor_id.clone())` at the `SubscriptionAdded` audit target (diagnosed E0505 at old line 1789).
2. `Command::UnsubscribeChannel`: `Some(actor_id)` -> `Some(actor_id.clone())` at the `SubscriptionRemoved` audit target (diagnosed E0505 at old line 1825).
3. `Command::RespondCommunityJoin`: both mutually exclusive audit target sinks use `Some(requester_id.clone())`, preserving `requester_id` for the later participant projection lookup whose old borrow failed at line 2204 (source moves were old lines 2171 and 2185).

No helper signature, public API, type, permission check, membership lookup, audit action/field, error text, event order, control flow, dependency or shared-ownership architecture is changed.

GitHub candidate comparison `115cd550... -> bd0fb654...` reports exactly one changed file, `engine.rs`, with 4 additions / 4 deletions. The patch is exactly the four `.clone()` substitutions above. The resulting file blob already existed in repository history (`f0a664dfbefc5c158c6ebb6e52120b5750b70bb3`); it was used only after GitHub proved exact four-line equivalence. No historical commit or #2323 stack is cherry-picked or attached to this branch.

## Open-source-first decision
Architecture evidence `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/ARCHITECTURE-RUST-BLOCKER-DIAGNOSIS-2026-09-05.md` records the governing external references:
- Rust official E0505 guidance: preserve a borrow when the original value remains needed; avoid moving the borrowed value.
- Rust official E0382 guidance: values with ownership semantics are not reusable after move; clone only when a genuinely independent owned value is required.
- Ruma/Matrix demonstrates a mature borrowed identity (`UserId`) versus retained owned identity (`OwnedUserId`) boundary; architecture adopts the pattern only.

No upstream code is copied, no upstream type is imported, and no dependency/license surface is added. Ruma's repository license is MIT as recorded by architecture; Rust documentation contributes language semantics/guidance only.

## Diagnosed baseline Actions (starting head `115cd550...`)
- Messaging Product Gate run `33914564827`: Rust self-hosted product job `101158638727` FAIL. Rustfmt PASS; `cargo test --all-targets` fails compiling `fabushi-messaging-core` with E0505/E0505/E0382; `m6_channels_topics_contract` and `unread_projection_contract` do not dynamically execute; messaging Clippy is SKIPPED. Electron Messenger contract job `101158639006` PASS.
- Fabushi self-hosted messaging run `33914564790`: Rust messaging core job `101158721014` FAIL and Mahayana social -> messaging Actor job `101158720692` FAIL through the same messaging-core compile blocker.
- Mahayana fast run `33914564807`: Rust protocol/Host/bridge fast job `101158616359` reaches Rust-native Harness and FAILS through the same messaging-core compile blocker.
- Generic/auxiliary exact-head greens do not substitute for the Rust failures: CI run `33914564928` / CI result job `101158917285` PASS; Explicit automerge `33914564792` PASS; Developer Fiat Commerce `33914564803` PASS; Project portfolio governance `33914564951` PASS.

## Verification policy
No local build, test, rustfmt, clippy, Electron, native-app or E2E command is run in this task. Only live GitHub reads plus lightweight Git/text/tree/diff checks are permitted. Heavy acceptance must come from GitHub Actions on the exact pushed PR head.

## Stop / handoff rule
If exact-head Actions expose a distinct non-ownership error or require any second product/test source file, record `EXECUTION-OWNERSHIP-001-BLOCKED / SCOPE-EXPANSION-REQUIRED` and return only to architecture. A fresh independent code-review session is the sole next action only after AC01-AC07 are all evidenced green on the final exact PR head; merge, test release and formal release remain forbidden here.
