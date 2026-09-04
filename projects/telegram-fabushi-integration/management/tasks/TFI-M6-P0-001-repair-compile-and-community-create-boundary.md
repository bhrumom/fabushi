# TFI-M6-P0-001 — repair compile blocker and Community-backed CreateConversation boundary

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M6-P0-001`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `IMPLEMENTED / CI-BLOCKED / REVIEW-PENDING / CLOSURE-BLOCKED`
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
Branch: `fix/tfi-m6-p0-001-community-create-boundary`; implementation commit: `30c6104ec1808941bcdf50f226a308c0c737d806`; PR: `#2323` (base `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`). CI: initial required runs `33884739411` (Mahayana fast checks) and `33884739286` (Messaging Product Gate) = FAIL at inherited rustfmt gate before compile; task-specific compile/test workflow added for this PR and is pending this write-back push. Evidence: `evidence/TFI-M6-P0-001/`. Review: architecture contract PR #2320 exact head `e2207ee0e59cf9d8c6ef26acf7ffbdd96c60078f` has independent R3 `REVIEW-PASS`; task PR #2323 independent real-diff code review = `pending`. Canonical-main/package/release: `pending / blocked`.


## 2026-09-04 execution write-back
- Audited implementation input was re-read at exact `9e88a2e9c030fe05147460dfa580366cf9aa433d`; both scoped defects remained present before editing.
- Chosen create behavior: existing Community-backed `CreateConversation` is an idempotent service-level no-op. It cannot reach generic `UpsertConversation`, so supplied kind/owner/participants cannot retype, re-own or replace the Community projection. Existing Community-backed `UpdateConversation` remains metadata-only.
- `RespondCommunityJoin` now builds `Option<Event>` explicitly: approved Group/Channel joins may append `ConversationParticipantUpserted` after `CommunityChanged`; rejected joins emit only `CommunityChanged`.
- Focused tests cover approved/rejected event order, forged create/update authority inputs, ordinary non-Community create compatibility, and missing-Community `RequestCommunityJoin -> CommunityNotFound`.
- Local verification was limited to `git diff --check` and static diff inspection. No local Cargo/build/test/E2E/native/app command was run.
- Open-source-first: reviewed official `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`, Boost Software License 1.0. TDLib separates group/supergroup creation from join-request processing; only that boundary principle was adopted, with no copied source.
- Initial PR Actions reached rustfmt before compile and failed because the audited M6 base contains pre-existing formatter drift across `engine.rs`/`service.rs`, including many lines outside P0-001. This task does not reformat unrelated M6 logic. A minimal PR-only task gate compiles/runs `m6_channels_topics_contract` without weakening the repository's required rustfmt gate; required-gate failure remains a closure blocker.
