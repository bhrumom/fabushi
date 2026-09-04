# TFI-M6-P0-001 — repair compile blocker and Community-backed CreateConversation boundary

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M6-P0-001`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `IMPLEMENTED / R1-B1-B2-B3-REPAIRED / CI-BLOCKED / REREVIEW-READY / CLOSURE-BLOCKED`
- **Owner:** Execution project group
- **Audited implementation input:** `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- **Branch:** `fix/tfi-m6-p0-001-community-create-boundary`
- **PR:** `#2323`, open/unmerged; exact base `9e88a2e9c030fe05147460dfa580366cf9aa433d`
- **Application/compile repair:** `726b4210ddd4d9a967778193a8d374b5f8bad206`
- **R1 repair head verified by Actions:** `4b6218e3aaa385ad0e3ef3ad0f908339c7b684dc`

## Objective and scope
Repair the current M6 compile blocker and Community-backed create/update authority boundary without expanding into membership recovery, admission redesign, journal redesign, protocol v3 negotiation, renderer work, M6-P0-002/003/004/005, M7/M8, MSR or GBF.

Allowed implementation surface is `native/mahayana-messaging/src/engine.rs`, `src/service.rs`, existing P0-001 tests, the additive task-specific validation workflow, and project/evidence write-back. No local Cargo/npm/Gradle/Xcode/build/test/E2E is permitted.

## Implemented boundary
- `RespondCommunityJoin` uses explicit optional-event construction. Approved Group/Channel joins emit `CommunityChanged` then `ConversationParticipantUpserted`; rejected joins emit only `CommunityChanged`.
- Existing Community-backed generic `CreateConversation` is an idempotent service-level no-op and cannot replace/retype/re-own/re-member the Community projection.
- Existing Community-backed `UpdateConversation` remains metadata-only for the protected authority fields.
- Ordinary non-Community create behavior is preserved.
- Missing-Community `RequestCommunityJoin` remains `CommunityNotFound` as a regression guard, not a new admission redesign.

## R1 review input — preserved
Independent R1 remains historical and authoritative until fresh rereview:
- review-record PR #2325 head `7f594f10570822dcf23a4c3c02ddb0583ea94f14`;
- PR #2323 review id `5114738170` = **REVIEW-REJECTED**;
- durable records: `evidence/TFI-M6-P0-001/REVIEW-R1-2026-09-04.md`, `REVIEW-R1-HANDOFF.md`, and `management/tasks/TFI-M6-P0-001-review-R1-2026-09-04.md`.
The execution repair does not overwrite or relabel that verdict.

## R1-B1 — CLOSED FOR REREVIEW
The existing `respond_community_join_emits_participant_projection_only_when_approved` test now directly inspects the real `Event::CommunityChanged { community }` payload and uses existing `CommunityAuditEntry`, `CommunityMember` and `CommunityState` fields. It asserts:
- approved `JoinApproved`: `actor_id = human:owner`, `target_actor_id = human:approved`;
- approved member is `Member`, `invited_by = human:owner`, and its pending request is removed;
- rejected `JoinRejected`: `actor_id = human:owner`, `target_actor_id = human:rejected`;
- rejected requester is absent from `members` and removed from `pending_join_requests`.
No new API or runtime product semantic was introduced.

GitHub Actions proof on repair head `4b6218e3...`: atomic run `33889474580`, job `101077337394` = **SUCCESS**. Step `Compile M6 contract test binary` passed, then `Run TFI-M6-P0-001 regressions` passed all three named regressions.

## R1-B2 — CLOSED FOR REREVIEW
Actual official upstream material read:
- repository/revision: `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`;
- exact file: `td/telegram/Requests.h`;
- exact symbols: `td_api::createNewSupergroupChat` handler declaration and `td_api::processChatJoinRequest` handler declaration;
- exact license file: `LICENSE_1_0.txt`, **Boost Software License 1.0**.
Only the create/join-request **boundary principle** was adopted. No TDLib, reconstructed Grok, Grok Bot, Codex, or other upstream implementation code was copied, translated, ported, adapted or transplanted.

## R1-B3 — CLOSED BY CONSERVATIVE ATTRIBUTION CORRECTION
The previous stronger wording that required rustfmt failures were **entirely inherited-only** is withdrawn. Current evidence proves only:
- required PR-head Rust workflows fail at formatter steps before their Rust compile/tests;
- exact audited base `9e88a2e9c030fe05147460dfa580366cf9aa433d` has no independent formatter run recorded in this task evidence;
- the additive atomic workflow proves task compile/regressions but does not independently compare base-vs-head formatter output.
Therefore no claim is made that every formatter difference is inherited. No required formatter gate is deleted, skipped, weakened, downgraded or represented as green.

## Current Actions evidence on R1 repair head
- **Task-specific atomic:** run `33889474580`, job `101077337394` — **SUCCESS**; full M6 contract binary compile + all three P0-001 named regressions PASS.
- **Required Mahayana fast checks:** run `33889474470`, job `101077337527` — **FAIL** at `Verify formatting before native package setup`; subsequent Rust checks skipped.
- **Required Messaging Product Gate:** run `33889474495`; Rust job `101077337752` — **FAIL** at `Rustfmt self-hosted messaging`, subsequent tests/clippy skipped; Electron Messenger job `101077337355` — **SUCCESS**.
- Historical pre-review atomic `33886105443` / `101066138054` = SUCCESS; historical required failures `33886105678` / `101066137829` and `33886105464` / `101066136842` remain provenance only.

## Six-category acceptance state
- **Unit:** task-specific PASS on `33889474580` / `101077337394`.
- **Contract:** task-specific PASS, including direct approved/rejected owner→requester audit and member/pending invariants.
- **Integration:** task-specific compile/test PASS; required repository Rust gates still FAIL before their integration/test stages.
- **E2E:** PENDING; no exact accepted-main installable/package Messenger Group/Channel journey exists because PR is unmerged.
- **Security:** task-specific negative authority tests + ownership/audit assertions PASS; independent rereview still required.
- **Performance:** no dedicated microbenchmark claimed; no network/poll/timer/retry/wait/unbounded traversal added. Exact-main packaged regression remains PENDING.

## Closure / handoff
Current state is **CI-BLOCKED / REREVIEW-READY / CLOSURE-BLOCKED**. Atomic PASS does not substitute for required CI, independent `REVIEW-PASS`, protected canonical-main merge, or exact-main package/E2E/Release evidence. Do not merge or release from this execution group. M6-P0-002 remains blocked until `FULL-CLOSE(M6-P0-001)`.
