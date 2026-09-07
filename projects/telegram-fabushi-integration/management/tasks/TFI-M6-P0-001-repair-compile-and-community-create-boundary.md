# TFI-M6-P0-001 — repair compile blocker and Community-backed CreateConversation boundary

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M6-P0-001`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `IMPLEMENTED / R2-B3-RECORD-REPAIR-PUSHED / CI-BLOCKED / R3-PENDING / CLOSURE-BLOCKED`
- **Owner:** Execution project group
- **Audited implementation input:** `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- **Branch:** `fix/tfi-m6-p0-001-community-create-boundary`
- **PR:** `#2323`, open/unmerged; exact base `9e88a2e9c030fe05147460dfa580366cf9aa433d`
- **Application/compile repair:** `726b4210ddd4d9a967778193a8d374b5f8bad206`
- **R1 repair head verified by Actions:** `4b6218e3aaa385ad0e3ef3ad0f908339c7b684dc`
- **R2 reviewed execution head:** `1dc165489498889504a61b7e07d5164f25188cef`

## Objective and scope
Repair the current M6 compile blocker and Community-backed create/update authority boundary without expanding into membership recovery, admission redesign, journal redesign, protocol v3 negotiation, renderer work, M6-P0-002/003/004/005, M7/M8, MSR or GBF.

The implementation phase allowed `native/mahayana-messaging/src/engine.rs`, `src/service.rs`, existing P0-001 tests, the additive task-specific validation workflow, and project/evidence write-back. **This R2-B3 repair round is records-only:** it changes only `projects/telegram-fabushi-integration/**` plus PR #2323 description/comments. No production source, regression test, or workflow change is permitted in this round. No local Cargo/npm/Gradle/Xcode/build/test/E2E is permitted.

## Implemented boundary
- `RespondCommunityJoin` uses explicit optional-event construction. Approved Group/Channel joins emit `CommunityChanged` then `ConversationParticipantUpserted`; rejected joins emit only `CommunityChanged`.
- Existing Community-backed generic `CreateConversation` is an idempotent service-level no-op and cannot replace/retype/re-own/re-member the Community projection.
- Existing Community-backed `UpdateConversation` remains metadata-only for the protected authority fields.
- Ordinary non-Community create behavior is preserved.
- Missing-Community `RequestCommunityJoin` remains `CommunityNotFound` as a regression guard, not a new admission redesign.

## R1 review input — preserved
Independent R1 remains historical evidence and is not overwritten:
- review-record PR #2325 head `7f594f10570822dcf23a4c3c02ddb0583ea94f14`;
- PR #2323 review id `5114738170` = **REVIEW-REJECTED** on execution head `73a46d3089c4f12dfb2f5659b232d51c674ed5a6`;
- durable records: `evidence/TFI-M6-P0-001/REVIEW-R1-2026-09-04.md`, `REVIEW-R1-HANDOFF.md`, and `management/tasks/TFI-M6-P0-001-review-R1-2026-09-04.md`.
The execution repair does not overwrite or relabel that verdict.

## R1-B1 — CLOSED IN R2
The existing `respond_community_join_emits_participant_projection_only_when_approved` test directly inspects the real `Event::CommunityChanged { community }` payload and uses existing `CommunityAuditEntry`, `CommunityMember` and `CommunityState` fields. It asserts:
- approved `JoinApproved`: `actor_id = human:owner`, `target_actor_id = human:approved`;
- approved member is `Member`, `invited_by = human:owner`, and its pending request is removed;
- rejected `JoinRejected`: `actor_id = human:owner`, `target_actor_id = human:rejected`;
- rejected requester is absent from `members` and removed from `pending_join_requests`.
No new API or runtime product semantic was introduced.

Exact R2-reviewed-head Actions proof: atomic run `33890057159`, job `101079256166` = **SUCCESS** on `1dc165489498889504a61b7e07d5164f25188cef`. Step `Compile M6 contract test binary` passed, then `Run TFI-M6-P0-001 regressions` passed all three named regressions.

## R1-B2 — CLOSED IN R2
Actual official upstream material read:
- repository/revision: `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`;
- exact file: `td/telegram/Requests.h`;
- exact symbols: `td_api::createNewSupergroupChat` handler declaration and `td_api::processChatJoinRequest` handler declaration;
- exact license file: `LICENSE_1_0.txt`, **Boost Software License 1.0**.
Only the create/join-request **boundary principle** was adopted. No TDLib, reconstructed Grok, Grok Bot, Codex, or other upstream implementation code was copied, translated, ported, adapted or transplanted.

## R1-B3 / R2-B3 — RECORD-TRUTH REPAIR INPUT COMPLETED; R3 REQUIRED
R1 correctly required withdrawal of the earlier stronger claim that required rustfmt failures were **entirely inherited-only**. R2 then found that generic durable TFI records and the PR description still retained unsupported `inherited rustfmt` / `inherited audited M6 drift` cause attribution. R2 therefore remained **REVIEW-REJECTED** even though B1/B2 were closed.

This records-only round synchronizes those durable records and PR metadata to the following evidence-bounded facts:
- exact reviewed base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`;
- exact R2-reviewed head: `1dc165489498889504a61b7e07d5164f25188cef`;
- required PR-head Rust workflows fail at formatter steps before later Rust checks;
- this evidence set contains **no independent exact base-vs-head formatter comparison**, so it cannot determine whether the formatter differences originate from the base, the PR, or both;
- task-specific atomic PASS and Electron PASS are additive only and do not waive required Rust CI.

Historical wording is not silently erased: affected current records explicitly mark the prior attribution as **withdrawn/superseded**, and the append-only changelog retains the original event text plus a dated correction.

R2 provenance is preserved separately and unmodified in reviewer PR #2326 head `dfbae8a16531f325ab482e7dc4bdf6940b6f5f87`:
- `evidence/TFI-M6-P0-001/REVIEW-R2-2026-09-04.md`;
- `evidence/TFI-M6-P0-001/REVIEW-R2-HANDOFF.md`;
- `management/tasks/TFI-M6-P0-001-review-R2-2026-09-04.md`.
PR #2323 R2 comment `5543006832` remains the live reviewer handoff. This execution group does **not** relabel R2 as passed; a fresh independent R3 is required after the record repair lands.

## Exact R2-reviewed-head Actions evidence
- **Task-specific atomic:** run `33890057159`, job `101079256166` — **SUCCESS**; full M6 contract binary compile + all three P0-001 named regressions PASS.
- **Required Mahayana fast checks:** run `33890057133`, job `101079256711` — **FAIL** at `Verify formatting before native package setup`; subsequent native/Rust checks skipped.
- **Required Messaging Product Gate:** run `33890057218`; Rust job `101079257348` — **FAIL** at `Rustfmt self-hosted messaging`, subsequent tests/clippy skipped; Electron Messenger job `101079257046` — **SUCCESS**.
- Developer Fiat Commerce `33890057119` and Explicit automerge `33890057132` were successful on that reviewed head, but neither substitutes for the failed required Rust gates.

## Six-category acceptance state
- **Unit:** task-specific PASS on `33890057159` / `101079256166` at R2-reviewed head.
- **Contract:** task-specific PASS, including direct approved/rejected owner→requester audit and member/pending invariants.
- **Integration:** task-specific compile/test PASS; required repository Rust gates FAIL before their later integration/test stages.
- **E2E:** PENDING; no exact accepted-main installable/package Messenger Group/Channel journey exists because PR is unmerged.
- **Security:** task-specific negative authority tests + ownership/audit assertions PASS; R2 found no new application-code blocker, but R3 review remains required.
- **Performance:** no dedicated microbenchmark claimed; no network/poll/timer/retry/wait/unbounded traversal added. Exact-main packaged regression remains PENDING.

## Closure / handoff
Current state is **REVIEW-REJECTED(R2) / CI-BLOCKED / R3-PENDING / CLOSURE-BLOCKED**. The B3 record-truth repair input is now prepared in this execution round, but only an independent fresh review may close the review finding. Atomic/Electron PASS does not substitute for required CI, independent `REVIEW-PASS`, protected canonical-main merge, or exact-main package/E2E/Release evidence. Do not merge or release from this execution group. M6-P0-002 remains blocked until `FULL-CLOSE(M6-P0-001)`.

## 2026-09-05 TFI-M6-P0-001-FMT-001 execution addendum — append-only
Architecture PR #2328 at exact head `7b1964294f15ff9aba352116a166ceef5ae499ae` froze the formatter-only child task `TFI-M6-P0-001-FMT-001`. Execution started from PR #2323 head `c32a0bd80922a2be6e62c2722fbbd3b14a18a252` and produced pure-format commit `d2f97c0c22411a49ef926c0bb9c049be18348b10`, changing exactly `engine.rs`, `service.rs`, and `m6_channels_topics_contract.rs` with 59 insertions / 36 deletions and no semantic/workflow/dependency/lock changes.

Exact implementation-head Actions prove both required formatter steps now pass. Mahayana `33898023332` / `101105207119` is **SUCCESS** end-to-end. Messaging Product `33898023373` Rust `101105208748` passes `Rustfmt self-hosted messaging`, then fails at `Test messaging library and server binaries` because later-M6 `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine` fails at line 632; three P0-001 regressions pass. Product Electron `101105208586` and atomic `33898023127` / `101105205848` are **SUCCESS** but do not waive Product Rust failure.

FMT-001 therefore repaired the formatter baseline but exposed a subsequent required-CI blocker outside its frozen semantic scope. Current child-task execution handoff is **REQUIRED-RUST-STILL-BLOCKED**; do not relabel parent P0-001 FULL-CLOSE, do not merge/release, and do not start P0-002. Detailed evidence: `evidence/TFI-M6-P0-001/FMT-001-EXECUTION-2026-09-05.md`. Historical R1/R2/R3 conclusions above remain unchanged.
