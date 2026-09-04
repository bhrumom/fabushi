# TFI-M6-P0-001-UNREAD-001 — align Group management fixture with Community authority

## Identity
- Project: `FAB-P0001 / TFI`.
- Parent: `TFI-M6-P0-001`.
- Stable Task ID: `TFI-M6-P0-001-UNREAD-001`.
- Authority path: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-001-UNREAD-001-align-group-management-fixture-with-community-authority.md`.
- Owner: `ChatGPT 项目管理 Team 子会话` execution group, exactly one execution session.
- Frozen starting point: execution PR #2323 exact head `553c5efd5a6119298d0a0da8512a1ac931fcc61c`, base `9e88a2e9c030fe05147460dfa580366cf9aa433d`.
- State: `READY_FOR_EXECUTION` only after this architecture PR is read at its exact final head.

## Problem contract
Required Messaging Product run `33903316015` / Rust job `101122272928` passes the MOD-001 target and full M6 contract binary, then fails at `unread_projection_contract.rs::conversation_management_enforces_owner_admin_boundaries_and_removal` because the fixture creates a Group Conversation without the now-required Community state. This is a parent/base latent stale-fixture mismatch introduced when `af6fb35...` made Community membership canonical; it is not a MOD-001/FMT regression or CI environment issue.

## Only authorized product/test change
Exactly one source/test file may change:
- `native/mahayana-messaging/tests/unread_projection_contract.rs`.

Within that file, modify only `conversation_management_enforces_owner_admin_boundaries_and_removal`. A tiny test-local helper in the same file is allowed only if it is used exclusively by this test and strictly reduces duplication; inline setup is preferred.

After existing `CreateConversation`, establish the Group's first `CommunityState` using the existing public `ClientCommand::UpdateCommunity` as `human:owner`. The requested seed must preserve the fixture's original management intent by ensuring the existing `human:admin` is projected as `MemberStatus::Administrator` with `AdminRights.add_admins = true`; all other rights stay minimal/default unless the existing public command requires them. Do not directly mutate private engine state.

Preserve and prove these original boundaries:
1. `human:admin` may add `human:new` as a normal member.
2. `human:member` cannot edit Group metadata.
3. `human:owner` may promote `human:new` to admin.
4. `human:admin` cannot remove another administrator.
5. `human:owner` may remove `human:member`.
6. removed `human:member` no longer receives `group:management-contract` in sync.
7. Community and Conversation projections remain consistent across add/promote/remove; do not restore a Conversation-only authority path.

## Forbidden changes
- `native/mahayana-messaging/src/**`, including `engine.rs` and `service.rs`.
- every other test file, including `m6_channels_topics_contract.rs`.
- `.github/workflows/**`, CI gates, runner configuration.
- Cargo manifests, lockfiles, toolchains, dependency versions.
- Electron, mobile, frontend, backend, protocol or Host product source.
- root `AGENTS.md`, `projects/PORTFOLIO.json`, Project ID/Key.
- historical R1/R2/R3, FMT-001, MOD-001 or architecture PR #2330 records.
- MERGE-001, canonical-main merge, E2E, test/formal Release, or P0-002+ implementation.

## Dependencies
- MOD-001 target implementation remains preserved and passing within its full M6 binary.
- Existing public `UpdateCommunity` first-create path remains the fixture construction mechanism.
- No production semantics are authorized to change.

## Verification policy
No local build/test/E2E/native/app execution. Validation is GitHub Actions only on one exact execution head.

Required acceptance evidence:
- scope diff shows exactly the authorized test body plus TFI project records;
- required Mahayana fast = SUCCESS;
- Messaging Product Rust: rustfmt SUCCESS; `cargo test --all-targets` SUCCESS, including this management test and all five `m6_channels_topics_contract` tests; messaging clippy, media tests, media clippy, production Feature Host bridge/contact projection all actually execute and SUCCESS;
- Product Electron = SUCCESS;
- TFI M6 P0-001 Atomic = SUCCESS;
- every other required PR-head check = SUCCESS;
- only after all required CI is green: fresh independent exact-head review may start. This task does not itself authorize merge/E2E/release.

## Failure classification / stop rules
- `UNREAD-FIXTURE-FAILURE`: the authorized test still fails but can be corrected inside the same frozen fixture scope; execution may iterate only in the authorized test body.
- `SCOPE-EXPANSION-REQUIRED`: passing requires production source, another test, workflow, manifest/dependency, or semantic fallback. **STOP** and return architecture; do not improvise.
- `SEMANTIC-CONTRADICTION`: Actions show the current Community-authority behavior differs from the frozen source proof. **STOP** with exact run/job/log and state trace.
- `NEW-SEMANTIC-FAILURE`: the target passes and Product Rust advances to a different deterministic repository failure. **STOP** and return architecture; do not expand scope.
- `CI-INFRA-BLOCKED`: runner/service/network failure without product assertion. Record exact evidence and retry only under normal CI policy; do not convert it into product work.

## Rollback
If UNREAD-001 is rejected, revert only the UNREAD-001 test commit(s) and its execution-state addenda. Preserve parent #2323 history, FMT-001, MOD-001 and all prior review/architecture evidence unchanged.

## Execution handoff format
Report: exact starting SHA; exact source commit(s); final exact head; changed-file list; concise state-path proof; each required run/job/conclusion; confirmation that Product Rust downstream steps actually executed; any stop classification; and explicit confirmation that no merge/E2E/release/P0-002+ work was started.
