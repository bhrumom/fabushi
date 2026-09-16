# TFI-M6-MAINSAFE-001-OWNERSHIP-001 独立复审证据

- Verdict: `REVIEW-PASS-OWNERSHIP-001`
- Project: `FAB-P0001 / TFI`
- Product PR: `#2336`
- Canonical base: `688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Reviewed exact product head: `8760b7587f6d576262e5993a72b5c5112ff595db`
- Product PR merge ref observed in raw logs: `5348ba5276123d9357dd282089a5677cbad5fa17 = Merge 8760b758... into 688465e946...`
- Architecture freeze PR: `#2337@ea9b5b62d22ed73b9de350075797ea4c54eb69e4`
- Execution handoff: `#2336 comment 5546349771`
- Review date: `2026-09-05`

## 1. PR truth and topology

At review lock, GitHub reports `#2336` as:

- state: open
- merged: false
- mergeable: true
- base: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- head branch: `fix/tfi-m6-mainsafe-001-rust-canonical`
- head: `8760b7587f6d576262e5993a72b5c5112ff595db`
- full PR commits: 9
- full PR changed files: 15

The 15-file full PR historical set is not itself the OWNERSHIP-001 atomic scope. The architecture diagnosis froze the blocker at `115cd55065d03b66f14d7e086d454709d24d2286`; compare of that frozen product point to the final execution head is a three-commit fast-forward with exactly five paths: one production file plus four TFI execution records.

Atomic commit chain:

1. `bd0fb654212469bf88a95d558ebf12fd11efd658` — code-only ownership repair in `engine.rs`.
2. `7f7da51fa7a3d91c5df9482d38ca58c50cc0c7cc` — execution/evidence records.
3. `8760b7587f6d576262e5993a72b5c5112ff595db` — execution status/change-log closure records.

No atomic-delta test/workflow/Cargo/dependency/version/release file exists.

## 2. Line-level production delta

File: `native/mahayana-messaging/src/engine.rs`

Atomic diff is `+4/-4`, with only these retained-target ownership substitutions:

- SubscribeChannel audit target: `Some(actor_id.clone())`
- UnsubscribeChannel audit target: `Some(actor_id.clone())`
- RespondCommunityJoin approved audit target: `Some(requester_id.clone())`
- RespondCommunityJoin rejected audit target: `Some(requester_id.clone())`

The surrounding code was read at final exact head and confirms:

- `append_community_audit` still receives actor identity by borrow and retained target by value;
- Subscribe/Unsubscribe policy queries and guards are unchanged;
- RespondCommunityJoin admin check, approve/reject operation, later `community.members.get(&requester_id)`, compatibility projection and error semantics are unchanged;
- `ActorId` remains a String-backed non-`Copy` identifier with `Clone`.

No `allow`, `expect`, lint suppression, dummy replacement identity, publicization, real authorization-field deletion, helper/API/type change, or workflow weakening appears in the atomic delta.

## 3. Exact-head GitHub Actions evidence

All evidence below is associated with product exact head `8760b7587f6d576262e5993a72b5c5112ff595db`; raw logs repeatedly show checkout of PR merge ref `5348ba5276123d9357dd282089a5677cbad5fa17`, whose message is `Merge 8760b758... into 688465e946...`.

### Messaging Product Gate

Run: `33918213459`

Key job: `101170221805`

Raw-log facts:

- `cargo fmt --check` executed successfully.
- `cargo test --all-targets` executed successfully for `fabushi-messaging-core`.
- `m6_channels_topics_contract` actually executed and passed.
- `unread_projection_contract` actually executed and passed.
- `cargo clippy --all-targets -- -D warnings` executed successfully.

This is the primary exact-head Rust product acceptance evidence.

### Self-hosted Rust core

Run: `33918213326`

Key job: `101170221175`

Raw-log facts:

- checked out the same `#2336` merge ref for exact head `8760...`;
- reran Rust formatting/test/Clippy gates rather than reusing a historical green result;
- messaging core tests and `-D warnings` completed successfully.

### Self-hosted social Actor

Run: `33918213374`

Key job: `101170221071`

Raw-log result: success on the same exact-head PR merge ref. The earlier social failure diagnosed at `115cd...` was therefore downstream of the messaging compilation blocker and is cleared at the reviewed head.

### Mahayana fast Rust-native Harness

Run: `33918213332`

Key jobs include `101170221944`, `101170220685`, `101170257270`, `101170257286`.

Raw-log result: success on the same exact-head PR merge ref. Existing ordinary warnings in unrelated crates do not replace or negate the dedicated messaging `clippy --all-targets -- -D warnings` gate, which independently passed.

### Selected required/general gates

Additional exact-head successful runs/jobs reviewed include:

- run `33918213331` — CI/general validation; key jobs `101170257302`, `101170257324`, `101170257356`, `101170506077`.
- run `33918213363` — additional repository product/quality validation, exact-head success.
- run `33918213336` — additional repository validation, exact-head success.
- governance/architecture jobs checked out the same merge ref and completed successfully.

The CI path classifier force-ran broader checks because the full PR relative to main includes non-doc messaging paths; OWNERSHIP-001 was not treated as docs-only to evade product validation.

### Protected-merge authorization workflow

Job `101170221194` completed successfully but the raw log explicitly says:

`PR #2336 does not have the automerge label; skipping.`

Therefore this workflow did **not** merge, enqueue, or silently authorize the PR. The product PR remained open/unmerged during review. This review decision is what permits only the next protected MERGE gate; it does not claim merge completion.

## 4. Open-source-first / official-basis review

Official Rust evidence:

- E0382: https://doc.rust-lang.org/stable/error_codes/E0382.html — moving a non-`Copy` value consumes it; cloning is a normal way to retain an independently owned value when both uses are required.
- E0505: https://doc.rust-lang.org/stable/error_codes/E0505.html — moving a value while borrowed is invalid; making the whole identifier `Copy` is not an appropriate fix for a String-backed identity type and would violate the frozen type contract.
- Clippy CI: https://doc.rust-lang.org/clippy/continuous_integration/index.html — treating Clippy warnings as CI failures with `-D warnings` is an official supported pattern.

Mature Rust ownership boundary reference:

- Ruma/Matrix identifiers distinguish borrowed `UserId` from retained `OwnedUserId`; obtaining owned identity at a storage/retention boundary is an established API pattern. Reference: https://docs.rs/ruma-common/latest/ruma_common/identifiers/struct.UserId.html

Conclusion: cloning only the audit sink's retained target is the minimal maintainable clean-room repair. No copied external implementation code was introduced.

## 5. Record reproducibility audit

The architecture and execution records collectively provide enough information for a new engineer to reproduce the review:

- Task ID and project identity (`TFI-M6-MAINSAFE-001-OWNERSHIP-001`, `FAB-P0001 / TFI`)
- frozen product allowlist
- canonical base and diagnosed/final exact heads
- execution commit chain
- exact product PR and execution handoff comment
- exact Actions run/job IDs and raw-log interpretation
- relationship from E0505/E0382 blocker to the four clone substitutions
- explicit statement that no local heavy verification was used as acceptance
- risks and prohibition on scope expansion
- next gate: protected merge, canonical-main readback, then packaged/simulated-user E2E by test-release group

## 6. Final evidence judgment

`REVIEW-PASS-OWNERSHIP-001`.

No P0/P1/P2 review defect was found inside the frozen atomic scope. Remaining work is procedural and intentionally outside this review: protected canonical-main merge and readback, followed by exact-main packaged build + simulated-user E2E with full video/screenshots/trace/report/log returned to code review before any formal release.