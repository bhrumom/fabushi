# TFI-M6-P0-001 execution evidence

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-P0-001`
- Architecture program: `FAB-ARCH-P0-20260904`
- Audited implementation base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Governance contract: PR #2320 head `e2207ee0e59cf9d8c6ef26acf7ffbdd96c60078f`; independent R3 verdict `REVIEW-PASS`.
- Branch: `fix/tfi-m6-p0-001-community-create-boundary`
- Initial implementation commit: `30c6104ec1808941bcdf50f226a308c0c737d806`
- Compile/ownership repair: `726b4210ddd4d9a967778193a8d374b5f8bad206`
- PR: #2323, base `codex/tfi-m6-repair`, open/unmerged.

## Changed implementation
1. `native/mahayana-messaging/src/engine.rs` — explicit optional participant event for `RespondCommunityJoin`.
2. `native/mahayana-messaging/src/service.rs` — existing Community-backed generic create becomes idempotent no-op; Community update remains metadata-only.
3. `native/mahayana-messaging/tests/m6_channels_topics_contract.rs` — focused approval/rejection, authority-boundary, ordinary-create, and `CommunityNotFound` regressions; R1 repair directly asserts CommunityChanged audit/member/pending semantics for approved and rejected join decisions.
4. `.github/workflows/tfi-m6-p0-001-atomic-gate.yml` — minimal PR-only compile/test gate. It is additive evidence and does not replace required repository gates.

## Open-source-first / provenance — R1-B2 corrected
Actual official upstream material read for this repair:
- repository/revision: `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`;
- exact file: `td/telegram/Requests.h`;
- exact symbols inspected in that file: `td_api::createNewSupergroupChat` handler declaration and `td_api::processChatJoinRequest` handler declaration;
- exact license file read at the same revision: `LICENSE_1_0.txt`, **Boost Software License 1.0**.

Only the create-vs-join-request **boundary principle** was adopted. No TDLib source was copied, translated, ported, adapted, or transplanted. No Codex, Grok Bot, reconstructed Grok, or other upstream implementation source was copied, translated, ported, adapted, or transplanted for this task.

## R1 independent review provenance — preserved
- Review-record PR #2325 is open/unmerged at head `7f594f10570822dcf23a4c3c02ddb0583ea94f14`.
- PR #2323 review id `5114738170` records **REVIEW-REJECTED**. Existing execution handoff anchor comment `5542235859` remains historical evidence.
- Durable R1 records: `REVIEW-R1-2026-09-04.md`, `REVIEW-R1-HANDOFF.md`, and `management/tasks/TFI-M6-P0-001-review-R1-2026-09-04.md`. This execution branch does not overwrite those reviewer records.

## R1-B1 semantic regression repair
`respond_community_join_emits_participant_projection_only_when_approved` now directly inspects the real `Event::CommunityChanged { community }` payload and asserts:
- approved audit: `JoinApproved`, `actor_id = human:owner`, `target_actor_id = human:approved`;
- approved member: `Member`, `invited_by = human:owner`, pending request removed;
- rejected audit: `JoinRejected`, `actor_id = human:owner`, `target_actor_id = human:rejected`;
- rejected requester: absent from `members`, pending request removed.
This is test-only strengthening; no runtime/product API or later-M6 semantic was added. Current R1-repair GitHub Actions result is pending until the repair commit is pushed.

## R1-B3 formatter attribution correction
The previous stronger statement that the required rustfmt failures were **entirely inherited-only** is withdrawn. The repository evidence currently proves only:
- required PR-head Rust jobs fail at rustfmt before their compile/test stages;
- audited base `9e88a2e9c030fe05147460dfa580366cf9aa433d` has no recorded formatter check run in this evidence set;
- the P0-001 atomic workflow compiles/tests the task but does not collect an independent base-vs-head formatter comparison.

Therefore this task does not claim that every rustfmt difference is inherited. The required rustfmt failures remain real closure blockers. No required gate is removed, weakened, skipped, or described as green.

## Historical verification facts before R1 repair
- Local heavy verification: **not run**, per repository/task policy.
- Historical local `git diff --check`: PASS before the original implementation commit; no local Cargo/build/test/E2E/native/app command was run.
- Pre-review atomic final run `33886105443`, job `101066138054`: **SUCCESS**. `m6_channels_topics_contract` compiled and all three P0-001 named regressions passed in their then-current form.
- Diagnostic predecessor run `33885625325`, job `101064549625`: crate/test binary compiled; 4/5 whole-file tests passed; only unchanged later-M6 `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine` failed and was not changed by this task.
- Required pre-review head:
  - Mahayana fast checks `33886105678`, job `101066137829`: **FAIL** at rustfmt before Rust compile/test.
  - Messaging Product Gate `33886105464`, Rust job `101066136842`: **FAIL** at rustfmt before Rust compile/test.
  - Messaging Product Gate Electron job `101066137101`: **SUCCESS**.

## Current verdict
`IMPLEMENTED / R1-REPAIR-PUSHED / CI-PENDING / REVIEW-REJECTED(R1) / CLOSURE-BLOCKED`.

No protected-main merge, exact accepted-main packaged E2E, Release, or post-repair independent code `REVIEW-PASS` exists. Task-specific success never substitutes for required CI or exact-main delivery evidence.
