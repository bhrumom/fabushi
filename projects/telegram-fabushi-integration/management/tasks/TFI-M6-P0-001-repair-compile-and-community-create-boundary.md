# TFI-M6-P0-001 — repair compile blocker and Community-backed CreateConversation boundary

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M6-P0-001`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `IMPLEMENTED / R1-REPAIR-PUSHED / CI-PENDING / REVIEW-REJECTED(R1) / CLOSURE-BLOCKED`
- **Owner:** Execution project group
- **Audited implementation input:** `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- **Current dependencies:** none
- **Parallel condition:** may run with TFI-M3-P0-001 / TFI-M8-P0-001, but not with another M6 task editing `engine.rs`/`service.rs`.

## Objective
Make the current M6 slice compile and close the Community-backed create-vs-update ownership backdoor without expanding into later admission/journal/protocol work.

## Verified current facts
At the audited head, `RespondCommunityJoin` still forms the optional participant event through a bool/`Option<Event>` expression that is a Rust compile blocker. `native/mahayana-messaging/src/service.rs` also still maps Community-backed `CreateConversation` into the generic `UpsertConversation` path. These are current defects. No-Community `RequestCommunityJoin` is **not** this defect; it already returns `CommunityNotFound` and belongs as a later regression guard.

## Exact implementation scope
- `native/mahayana-messaging/src/engine.rs`: `RespondCommunityJoin` command/event path and focused tests.
- `native/mahayana-messaging/src/service.rs`: `ClientCommand::CreateConversation`, authorization and `project_command` projection boundary; `UpdateConversation` guard only as needed to keep Community ownership invariant.
- `native/mahayana-messaging/src/protocol.rs`: only if an existing typed error/result must be used or minimally extended.
- task-specific tests co-located in these files or existing `native/mahayana-messaging/tests/**` only.

## Implementation steps
1. Re-read the exact implementation head and verify the two defects still exist; if head moved, write the new SHA here before editing.
2. Replace the invalid bool/Option construction with explicit optional-event logic while preserving approved/rejected event ordering.
3. Detect an existing Community-backed conversation before generic `UpsertConversation`; choose and document one explicit idempotent/no-op or typed AlreadyExists behavior.
4. Prove client-supplied `kind`, `owner_id`, or participants cannot retype/re-own the Community through create/update.
5. Preserve intended non-Community create behavior and add focused negative regressions.

## In scope
Compile fix; Community-backed create/update boundary; focused tests/evidence.

## Out of scope
Membership recovery, admission redesign, journal redesign, protocol v3 negotiation, renderer changes, local build/test.

## Acceptance by category
- **Unit:** approved and rejected `RespondCommunityJoin` paths compile and emit the expected optional event sequence; Community create guard unit cases pass.
- **Contract:** existing Community cannot be replaced/retyped/re-owned through `CreateConversation` or Community `UpdateConversation`; non-Community create semantics remain compatible.
- **Integration:** messaging service -> engine path compiles/tests in GitHub Actions with Community and non-Community fixtures.
- **E2E:** exact-main installable Messenger Group/Channel smoke journey after merge proves no create/update regression; it does not substitute for M6-002/003 feature acceptance.
- **Security:** forged owner/kind/participant inputs cannot elevate or capture Community authority.
- **Performance:** no new network/poll/wait loop is introduced; existing messaging packaged smoke/performance checks must not regress.

## Required write-back and evidence
Update this file with actual branch/commit/PR/review head+verdict/CI workflow-run-job/check/evidence/status/changelog and update TFI WBS/acceptance/dependency/status/change/evidence records. `REVIEW-PASS` may only be written from the independent real-diff review; planned is not passed.

Closure requires protected merge plus exact-main **installable/package** evidence with SHA, app version, platform, workflow run/job, journey/test ID, timestamp, full video, step screenshots, trace, HTML/native report and logs. Pass/fail evidence uploads on an `always()`-equivalent path; target 90 days or record the maximum allowed lower limit. Missing evidence blocks pass; source-only results are insufficient.

## Execution fields
Branch: `fix/tfi-m6-p0-001-community-create-boundary`; implementation commit: `30c6104ec1808941bcdf50f226a308c0c737d806`; compile/ownership follow-up: `726b4210ddd4d9a967778193a8d374b5f8bad206`; PR: `#2323` (base `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`). Evidence: `evidence/TFI-M6-P0-001/`. Architecture contract PR #2320 exact head `e2207ee0e59cf9d8c6ef26acf7ffbdd96c60078f` has independent R3 `REVIEW-PASS`; task code review R1 is `REVIEW-REJECTED` and remains authoritative until a fresh independent rereview. Canonical-main/package/release: `pending / blocked`.

## 2026-09-04 execution write-back
- Audited implementation input was re-read at exact `9e88a2e9c030fe05147460dfa580366cf9aa433d`; both scoped defects remained present before editing.
- Chosen create behavior: existing Community-backed `CreateConversation` is an idempotent service-level no-op. It cannot reach generic `UpsertConversation`, so supplied kind/owner/participants cannot retype, re-own or replace the Community projection. Existing Community-backed `UpdateConversation` remains metadata-only.
- `RespondCommunityJoin` now builds `Option<Event>` explicitly: approved Group/Channel joins may append `ConversationParticipantUpserted` after `CommunityChanged`; rejected joins emit only `CommunityChanged`.
- Focused tests cover approved/rejected event order, forged create/update authority inputs, ordinary non-Community create compatibility, and missing-Community `RequestCommunityJoin -> CommunityNotFound`.
- Previous local verification was limited to `git diff --check` and static diff inspection. No local Cargo/build/test/E2E/native/app command was run.
- Open-source-first: reviewed official `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`, Boost Software License 1.0. Only the creation-vs-join-request boundary principle was adopted; no upstream implementation code was copied or adapted.
- Required PR-head workflows fail at rustfmt before their Rust compile/tests. Those failures remain closure blockers. The task-specific gate is additive evidence only and does not weaken or replace the required gates.

### Historical execution evidence before R1 repair
- Application/compile-fix commit: `726b4210ddd4d9a967778193a8d374b5f8bad206`; task-specific verification configuration commit: `75b319160c70db661739560e24134b636608b8cd`.
- Atomic GitHub Actions final pre-review run `33886105443`, job `101066138054`: **SUCCESS**. The M6 contract test binary compiled successfully, then all three TFI-M6-P0-001 named regressions passed.
- Preceding full-file diagnostic run `33885625325`, job `101064549625`: crate/test binary compiled; 4/5 M6 tests passed. The only failure was the unchanged `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine` moderation assertion, outside P0-001; it was not repaired here.
- Required pre-review gates remained **FAIL** before their Rust tests: Mahayana fast checks run `33886105678`, job `101066137829`; Messaging Product Gate run `33886105464`, Rust job `101066136842`. The Electron Messenger job `101066137101` passed.
- The task-specific success above is not required-CI PASS, protected-main merge, exact-main package E2E, or Release evidence.

## 2026-09-04 independent R1 review input — preserved, not overwritten
- Reviewer records: PR #2325, branch `review/pr-2323-r1-record-20260904`, head `7f594f10570822dcf23a4c3c02ddb0583ea94f14`.
- PR #2323 review id `5114738170` is `COMMENTED` with verdict **REVIEW-REJECTED**. Existing execution handoff anchor comment `5542235859` remains historical evidence.
- R1 durable records are `evidence/TFI-M6-P0-001/REVIEW-R1-2026-09-04.md`, `evidence/TFI-M6-P0-001/REVIEW-R1-HANDOFF.md`, and `management/tasks/TFI-M6-P0-001-review-R1-2026-09-04.md`; this execution repair does not modify them.

### R1-B1 — focused ownership semantics
The existing `respond_community_join_emits_participant_projection_only_when_approved` regression is strengthened in place, using the real `Event::CommunityChanged`, `CommunityAuditEntry`, `CommunityMember`, and `CommunityState` fields already present in the repository. It now directly asserts:
- approved `JoinApproved` audit `actor_id = human:owner` and `target_actor_id = human:approved`;
- approved member status `Member`, `invited_by = human:owner`, and removal from `pending_join_requests`;
- rejected `JoinRejected` audit `actor_id = human:owner` and `target_actor_id = human:rejected`;
- rejected requester absent from `members` and removed from `pending_join_requests`.
No new API or product semantic is introduced. GitHub Actions verification is pending for this R1-repair push.

### R1-B2 — exact open-source provenance
Actual upstream material read for this repair:
- repository/revision: `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`;
- exact file: `td/telegram/Requests.h`;
- exact symbols inspected: `td_api::createNewSupergroupChat` handler declaration and `td_api::processChatJoinRequest` handler declaration;
- license file read at the same revision: `LICENSE_1_0.txt`, **Boost Software License 1.0**.
Adoption is limited to the create/join-request **boundary principle**. No TDLib code was copied, translated, ported, or adapted. No reconstructed Grok, Grok Bot, Codex, or other upstream implementation source was copied, translated, ported, or adapted for this repair.

### R1-B3 — rustfmt attribution correction
The prior stronger wording that the required rustfmt failures were **entirely inherited-only** is withdrawn. What is independently proven is narrower:
- required task-head workflows fail at rustfmt before their Rust compile/tests;
- audited base `9e88a2e9c030fe05147460dfa580366cf9aa433d` has no recorded formatter check run in the current evidence set;
- the additive P0-001 atomic workflow does not collect an independent base-vs-head formatter comparison.
Therefore this task does **not** claim that every formatter difference is inherited. No required formatting gate is removed, skipped, downgraded, or represented as green. The rustfmt failures remain closure blockers until a later in-scope owner provides acceptable evidence or repairs them without violating task boundaries.
