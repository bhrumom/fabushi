# TFI-M6-P0-001-CLIPPY-001 — repair production Clippy gate

## Identity
- Project: `FAB-P0001 / TFI` (reuse existing project; Project ID/Key remain immutable).
- Parent: `TFI-M6-P0-001`.
- Stable Task ID: `TFI-M6-P0-001-CLIPPY-001`.
- Authority path: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-001-CLIPPY-001-repair-production-clippy-gate.md`.
- Owner: `ChatGPT 项目管理 Team 子会话` execution group, exactly one execution session.
- Frozen starting point: execution PR #2323 exact head `373bc52ad1cc2052c32acd81be4606c0a18dd89b`, base `9e88a2e9c030fe05147460dfa580366cf9aa433d`.
- State: `READY_FOR_EXECUTION` only after the execution session reads this records-only architecture PR at its exact final head and the architecture handoff comment on #2323.

## Problem contract
UNREAD-001 completed its authorized fixture change and proved its target plus `cargo test --all-targets` green, then the required Messaging Product Rust job reached production Clippy and failed at two deterministic pre-existing production-source diagnostics:
1. `native/mahayana-messaging/src/engine.rs:597` — `CommunityAdminAction::PostMessages` is never constructed; `-D dead-code` is implied by `-D warnings`.
2. `native/mahayana-messaging/src/service.rs:684` — `clippy::collapsible_match`; the nested `RemoveConversationParticipant` authorization check can be expressed without the extra nested conditional.

Current-head Product run `33905958987`, Rust job `101131173899`, and semantic-head Product run `33905736673`, Rust job `101130104184`, both show the same sequence: rustfmt PASS, full messaging tests PASS, then the same two Clippy errors. The current-head `unread_projection_contract` is 4/4 PASS and `m6_channels_topics_contract` is 5/5 PASS.

Both lint sites already exist on audited execution base `9e88a2e9c030fe05147460dfa580366cf9aa433d`. Historical source proof attributes the dead selector to `6160971cb3c477b809ae470d60f1e3c601606329` and the nested service authorization form to `af6fb35c30f9d64d6f731c8a0d1ebef959f95a73`. FMT/MOD/UNREAD did not semantically introduce either diagnostic; those tasks only removed earlier gates that had prevented Product Rust from reaching Clippy.

Canonical classification: `PARENT-BASE-LATENT / HISTORICAL-PRODUCTION-CLIPPY-DEBT / TEST-FIXTURE-UNRELATED / NOT-CI-FLAKE`.

## Only authorized production changes
Exactly two production files may change, plus task-scoped TFI execution/evidence records.

### 1. `native/mahayana-messaging/src/engine.rs`
Modify only the private `CommunityAdminAction` selector and its `require_community_admin` mapping:
- remove the unused private variant `CommunityAdminAction::PostMessages`;
- remove only its corresponding mapping arm `CommunityAdminAction::PostMessages => member.admin_rights.post_messages`.

Must preserve:
- `AdminRights.post_messages` as a real domain permission;
- the existing direct message-send authorization that reads `member.admin_rights.post_messages`;
- every other `CommunityAdminAction` variant and all current call sites;
- message/community permission behavior and error contracts.

Do **not** construct `PostMessages` artificially and do **not** add `#[allow(dead_code)]`, `#[expect(dead_code)]`, crate-level lint suppression, or public visibility merely to silence the warning. There is no current generic-admin-dispatch call that requires this private selector, while the actual post permission remains live through the direct send path.

### 2. `native/mahayana-messaging/src/service.rs`
Modify only the Community-backed management preflight inner branch for `ClientCommand::RemoveConversationParticipant` around the current Clippy diagnostic. Express the existing predicate in a Clippy-clean equivalent form, preferably a match-arm guard exactly matching Clippy's suggested control-flow shape.

Must preserve, byte-for-byte where practical and semantically without exception:
- lookup of `target_actor_id` in `community.members`;
- protected statuses `MemberStatus::Owner | MemberStatus::Administrator`;
- the `!caller_is_owner` condition;
- the denial text `admins cannot remove owner/admin members`;
- surrounding caller membership/admin-right checks;
- the `SetConversationParticipant` branch and every other service command;
- owner/admin/member authorization outcomes.

No authorization weakening, fallback, new branch, new error type, or changed audit/state transition is authorized.

## Test policy
No test source changes are authorized. Existing tests are the regression oracle for this semantics-preserving cleanup. In particular, preserve UNREAD-001 and MOD-001 test files unchanged.

## Forbidden changes
- Every production file other than the two exact files/ranges above.
- Every test file, including `unread_projection_contract.rs` and `m6_channels_topics_contract.rs`.
- `.github/workflows/**`, CI gates, runner configuration, action versions.
- Cargo manifests, lockfiles, rust-toolchain files, dependency versions or lint configuration.
- Electron, mobile, frontend, backend, protocol, media or Feature Host product source.
- root `AGENTS.md`, `projects/PORTFOLIO.json`, `PROJECT.yaml` identity fields, or any other project.
- R1/R2/R3, FMT-001, MOD-001, UNREAD-001, architecture PR #2330/#2331 historical records.
- code review, MERGE-001, canonical-main merge, E2E, test release, formal release, or P0-002+ implementation in this execution session.

## Dependencies
- Preserve #2323 starting semantics at exact head `373bc52ad1cc2052c32acd81be4606c0a18dd89b`.
- Preserve UNREAD-001 semantic commit `7d158e1742b2d9e56d101c90d3d81408dcd41947` and its 4/4 passing unread contract.
- Preserve MOD-001 continuity: `m6_channels_topics_contract` 5/5 PASS.
- Preserve the live `AdminRights.post_messages` domain field/direct send-path check.
- Required verification remains `.github/workflows/messaging-product-gate.yml` with stable Rust/Clippy and `cargo clippy --manifest-path native/mahayana-messaging/Cargo.toml --all-targets -- -D warnings`; the workflow itself is read-only for this task.

## Verification policy
No local build/test/E2E/native/app execution. Heavy validation is GitHub Actions only on one exact execution head after the two source edits are committed and pushed.

Required acceptance evidence on the final exact execution head:
1. scope diff shows only the two authorized production locations plus append-only `projects/telegram-fabushi-integration/**` execution records;
2. no test/workflow/manifest/lock/toolchain/dependency changes;
3. required Mahayana fast checks = SUCCESS;
4. Messaging Product Rust: rustfmt = SUCCESS;
5. `cargo test --manifest-path native/mahayana-messaging/Cargo.toml --all-targets` = SUCCESS;
6. `unread_projection_contract` = 4/4 PASS, including `conversation_management_enforces_owner_admin_boundaries_and_removal`;
7. `m6_channels_topics_contract` = 5/5 PASS;
8. messaging Clippy actually executes and = SUCCESS, with neither the `dead_code` nor `collapsible_match` diagnostic remaining and without lint suppression;
9. downstream deterministic media test = SUCCESS, media Clippy = SUCCESS, and production Feature Host bridge/contact projection = SUCCESS rather than skipped;
10. Product Electron = SUCCESS;
11. TFI M6 P0-001 Atomic = SUCCESS;
12. Developer Fiat Commerce and Explicit automerge = SUCCESS;
13. every other required PR-head check = SUCCESS.

Only after all required CI is green may a fresh independent exact-head code review begin. This task itself does not authorize review, merge, E2E or release.

## Failure classification / stop rules
- `CLIPPY-TARGET-REMAINS`: either of the same two diagnostics remains; execution may iterate only inside the corresponding exact authorized source range.
- `SEMANTIC-REGRESSION`: an existing test/contract now fails or an authorization outcome changes. **STOP** and return architecture with exact run/job/test/error; do not change tests or broaden source scope.
- `NEW-SEMANTIC-FAILURE`: Product Rust advances and exposes another deterministic repository failure. **STOP** and return architecture; do not patch a third site opportunistically.
- `SCOPE-EXPANSION-REQUIRED`: passing requires another production file, any test, workflow, manifest/dependency/toolchain/lint configuration, or behavior change. **STOP**.
- `CI-INFRA-BLOCKED`: runner/service/network failure without a product diagnostic. Record exact evidence and retry only under normal CI policy; do not convert it into source work.

## Rollback
If CLIPPY-001 is rejected, revert only the CLIPPY-001 production semantic/cleanup commit(s). Preserve append-only execution evidence and all parent #2323, R1/R2/R3, FMT-001, MOD-001 and UNREAD-001 history unchanged. Do not rewrite history or reset the shared execution branch.

## Execution handoff format
Report: exact starting SHA; exact production commit(s); final exact head; changed-file list and exact hunks; explicit proof that `AdminRights.post_messages` and direct send authorization remain; explicit before/after predicate proof for the service removal guard; each required run/job/conclusion; confirmation that messaging Clippy and every downstream Rust step actually executed; any stop classification; and explicit confirmation that no review/merge/E2E/release/P0-002+ work was started.