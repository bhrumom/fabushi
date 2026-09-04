# TFI-M6-MAINSAFE-001-OWNERSHIP-001 — repair audit ownership boundary

- Project: `FAB-P0001 / TFI`
- Parent task: `TFI-M6-MAINSAFE-001-RUST-CANONICAL`
- Type: product-code atomic repair task
- Priority: P0 / blocker repair inside MAINSAFE layer 001
- Status: `READY-AFTER-ARCHITECTURE-HANDOFF`
- Execution object: existing product PR `#2336`, diagnosed exact head `115cd55065d03b66f14d7e086d454709d24d2286`, base canonical `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Owner model: one fresh execution-group session; only after exact-head Actions acceptance may one fresh independent code-review session begin

## Goal
Remove the three current Rust ownership compile errors in `engine.rs` without changing business semantics, public API, helper signatures, event ordering, protocol versioning, dependencies, tests, workflows, Cargo configuration, or any other product file. This repair exists only because the prior execution session hit its frozen third deterministic Rust failure and correctly stopped `MAINSAFE-RUST-BLOCKED / SCOPE-EXPANSION-REQUIRED`.

## Root-cause contract
`append_community_audit` deliberately accepts the acting identity as borrowed `&ActorId` while `target_actor_id` is an owned `Option<ActorId>` retained by the audit entry. Three call sites violate that ownership boundary:

1. `Command::SubscribeChannel`: the same `actor_id` is borrowed as audit actor and moved as the owned target in the same call, producing E0505.
2. `Command::UnsubscribeChannel`: the same pattern produces E0505.
3. `Command::RespondCommunityJoin`: `requester_id` is moved into the owned audit target in either approved/rejected branch, then must still be borrowed for `community.members.get(&requester_id)` when producing the participant compatibility projection, producing E0382.

These are one common ownership-boundary defect, not three independent semantic tasks. Preserve the original identity for authorization/state lookup and later projection; create a distinct owned value only at the retained audit-target boundary where a second owner is semantically required. Do not alter control flow or move the projection before audit merely to satisfy borrow checking.

## Frozen allowlist
Production — exactly one file:
- `native/mahayana-messaging/src/engine.rs`

Records:
- `projects/telegram-fabushi-integration/**` only for this execution task's factual status/evidence/handoff.

No other product or test file is authorized. In particular, do **not** touch:
- `native/mahayana-messaging/src/community.rs`
- `native/mahayana-messaging/src/conversation.rs`
- `native/mahayana-messaging/src/protocol.rs`
- `native/mahayana-messaging/src/service.rs`
- `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`
- `native/mahayana-messaging/tests/unread_projection_contract.rs`
- any Electron source
- `.github/workflows/**`
- any Cargo manifest/lock/toolchain/dependency/lint configuration
- version/release/generated-package files
- root `AGENTS.md`, `projects/PORTFOLIO.json`, project identity files.

## Explicitly forbidden implementation strategies
- no retarget, rebase, force-push, base rewrite, or whole-stack cherry-pick of #2323;
- no `ActorId` representation/trait change and no attempt to make the `String`-backed ID `Copy`;
- no `append_community_audit` signature redesign or broad call-site cleanup;
- no `Rc`/`Arc`/interior-mutability/shared-ownership redesign;
- no dependency addition;
- no event, authorization, membership, subscriber, audit, protocol or projection semantic change;
- no opportunistic cleanup outside the three failing ownership sinks;
- no local build/test/rustfmt/clippy/E2E.

## Requirements / acceptance IDs
- `MS001-OWN-AC01-SCOPE`: final `main..#2336` delta introduced by this repair changes only `engine.rs` plus TFI records; the PR remains based on the same canonical main lineage and historical #2323 remains untouched.
- `MS001-OWN-AC02-OWNERSHIP`: the two E0505 and one E0382 failures diagnosed at `engine.rs` around subscription audit and join-response projection are absent without business-contract changes.
- `MS001-OWN-AC03-MSG-GATE`: on the exact repair head, Messaging Product Gate Rust self-hosted product job reaches and passes rustfmt, `cargo test --all-targets`, and messaging Clippy `-D warnings`; Clippy must not be skipped. Electron Messenger contract must remain green.
- `MS001-OWN-AC04-CONTRACTS`: `m6_channels_topics_contract` and `unread_projection_contract` must actually execute and pass; compile-only progress is not acceptance.
- `MS001-OWN-AC05-SELFHOSTED`: Fabushi self-hosted messaging exact-head run has both Rust messaging core and Mahayana social → messaging Actor jobs green; the latter must no longer fail through `fabushi-messaging-core` compilation.
- `MS001-OWN-AC06-HARNESS`: Mahayana fast exact-head run reaches and passes `Test Rust-native Mahayana Harness`, proving the previously observed harness failure was removed with the messaging-core compile blocker; any new harness-specific failure is a new blocker, not in-scope for this task.
- `MS001-OWN-AC07-REQUIRED-CI`: repository-required exact-head gates, including current `CI result`, Explicit automerge, Developer Fiat Commerce and Project portfolio governance when selected, are green. Their success never substitutes for AC03-AC06.
- `MS001-OWN-AC08-REVIEW`: only after AC01-AC07 are evidenced may a fresh independent code-review session review the exact main-based diff; no old #2323/FMT/MOD/UNREAD/CLIPPY review is reused as full acceptance.
- `MS001-OWN-AC09-MERGE`: after review PASS, use the active protected-main merge queue with no bypass. Read back the accepted exact canonical `main` before declaring parent task 001 complete.
- `MS001-OWN-AC10-SEQUENCE`: MAINSAFE-002 remains forbidden until 001 is accepted on canonical main; MAINSAFE-003 remains forbidden until 002 is accepted/read back. Test release/formal release remain blocked.

## Failure-stop rules
- If any product/test file outside `engine.rs` is required: STOP `MAINSAFE-RUST-BLOCKED / SCOPE-EXPANSION-REQUIRED` and return to architecture.
- If compilation advances and reveals a new independent semantic/security/supply-chain/API failure: STOP and record it; do not widen this task.
- If Mahayana Harness fails after `fabushi-messaging-core` compiles for a different reason: STOP and hand back a separate blocker; do not repair it here.
- If canonical main or #2336 base/head lineage changes before execution starts, re-read GitHub first. Any non-fast-forward/retarget/rebase condition invalidates this frozen handoff.
- Red or pending required Actions, skipped required contract/clippy steps, review rejection, merge conflict, missing queue acceptance or missing canonical readback all block closure.

## Open-source-first basis
Architecture compared the failure against Rust's official E0505/E0382 ownership guidance and the mature Matrix/Ruma borrowed-vs-owned identifier pattern. The adopted principle is to borrow the canonical identity for lookups and create a separate owned identity only at a retained payload boundary. No upstream implementation code is copied, no type is imported, and no dependency is added. Source/license details are recorded in the architecture diagnosis evidence.
