# TFI-M6-P0-001-MOD-001 — align post-ban send contract with active-member projection

- Project: `FAB-P0001 / TFI`
- Parent: `TFI-M6-P0-001`
- Task ID: `TFI-M6-P0-001-MOD-001`
- Status: `READY_FOR_EXECUTION`
- Priority: `P0 / closure blocker`
- Single owner: `ChatGPT 项目管理 Team 子会话`
- Planning input: execution PR #2323 exact head `ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d`
- Audited base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Dependency: FMT-001 implementation/review scope is complete; required Product Rust remains red at the newly exposed moderation contract test.

## Objective

Repair only the pre-existing post-ban test contract so that it matches the already-existing single-authority state-machine invariant: a `Banned` Community member is no longer an active Group/Channel Conversation participant, and a subsequent send therefore fails at the active-participation guard.

This task does **not** authorize a production moderation redesign, error-precedence redesign, workflow change, or any P0-002+ work.

## Frozen architecture decision

On `ecf79c8...`:
- `participant_for_community_member(MemberStatus::Banned)` returns `None`;
- `ModerateCommunityMember` projects that to `ConversationParticipantRemoved`;
- `execute()` applies the removal before the next command;
- `QueueMessage` checks active Conversation participation before Community member restrictions.

Therefore the post-ban contract for `human:member` is `EngineError::SenderNotParticipant { conversation_id: group:m6, actor_id: human:member }`, not `CommunitySendRestricted(group:m6)`.

The parent branch already contains both this implementation and the contradictory test expectation. #2323 does not introduce this mismatch.

## Allowed change set

### Application/test source — exactly one file
- `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`

Within that file, the execution owner may change only `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine` as required to:
1. after `ModerateCommunityMember(... Banned ...)`, assert the Community member is `MemberStatus::Banned`;
2. assert `human:member` is absent from `engine.state().conversations["group:m6"].participants`;
3. assert the following `QueueMessage` fails with `EngineError::SenderNotParticipant { conversation_id, actor_id }` for `group:m6` / `human:member`;
4. preserve the pre-existing slow-mode, topic and admin-log assertions and the rest of the test's intent.

Use existing public/read-only state access already available through `engine.state()`. If the assertions cannot be expressed without adding/changing production API, stop and hand back `ARCHITECTURE-BLOCKED`; do not expand scope.

### Execution records — append-only
The execution owner may append task/evidence/status records under:
- `projects/telegram-fabushi-integration/**`

Suggested execution evidence path:
- `projects/telegram-fabushi-integration/evidence/TFI-M6-P0-001/MOD-001-EXECUTION-2026-09-05.md`

## Forbidden change set

Explicitly forbidden in this task:
- `native/mahayana-messaging/src/engine.rs`
- `native/mahayana-messaging/src/service.rs`
- every other application/test source file
- `.github/workflows/**`
- `Cargo.toml`, `Cargo.lock`, toolchain/dependency/manifests/package files
- Electron/frontend/mobile/native product code outside the one allowed Rust contract test
- root `AGENTS.md`
- `projects/PORTFOLIO.json`
- Project ID / new project creation
- architecture PR #2328 or its frozen files/history
- R1/R2/R3/FMT/reviewer history rewrites
- P0-002/003/004/005 implementation
- protected merge, packaged E2E, test release, formal release

No required gate may be removed, skipped, weakened, renamed to evade protection, or substituted by Atomic/Electron PASS.

## Execution procedure

1. Re-read this task from its architecture records-only PR/head.
2. Re-read #2323 and verify the intended starting semantic head is still `ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d`. If #2323 has moved for unrelated implementation work, stop and report the new exact head before editing.
3. Make the smallest test-only contract change described above. Do not edit production source.
4. Append execution evidence with exact diff, exact new head and GitHub Actions IDs/results.
5. Push to the existing #2323 execution branch/PR lineage; do not create a competing product implementation PR unless repository policy makes the existing PR technically unavailable and architecture explicitly reassigns the task.
6. Let the normal GitHub Actions validate the new exact execution head. Do not run local build/test/E2E/native app validation.
7. Hand the exact new head to a fresh independent review session after all required checks have produced terminal results.

## Acceptance criteria

`TFI-M6-P0-001-MOD-001` is accepted only when all are true on one exact execution head:

### Diff / semantic acceptance
- only the allowed M6 contract test file is changed among application/test/workflow/product files;
- direct assertions prove Community status is `Banned` and Conversation active participant projection excludes `human:member`;
- the post-ban send asserts `SenderNotParticipant` with both expected conversation and actor identifiers;
- no production behavior/error ordering is changed;
- the existing three P0-001-focused regressions remain intact;
- no historical reviewer/FMT evidence is rewritten.

### GitHub Actions acceptance
- `Mahayana fast checks`: required job **SUCCESS** end-to-end;
- `Messaging Product Gate` Rust:
  - rustfmt **PASS**;
  - `cargo test --manifest-path native/mahayana-messaging/Cargo.toml --all-targets` **PASS**, including the full `m6_channels_topics_contract` binary;
  - previously skipped downstream Product Rust clippy/media/bridge steps actually execute and **PASS**;
- Product Electron job **PASS**;
- TFI M6 P0-001 Atomic gate **PASS**;
- any other required branch-protection checks on that head are **PASS**;
- fresh independent exact-head review returns `REVIEW-PASS` for MOD-001 and confirms required Product Rust is no longer blocked.

Atomic, Mahayana, or Electron green status cannot substitute for the required Product Rust job.

## Failure classification / stop rules

- `SEMANTIC-CONTRADICTION`: Actions or direct state assertions show a behavior inconsistent with the frozen state-path proof. Stop as `ARCHITECTURE-BLOCKED`; do not edit production source.
- `SCOPE-EXPANSION-REQUIRED`: passing the contract would require `engine.rs`, service/API, workflow, dependency, or another test file. Stop and return to architecture.
- `CI-INFRA-BLOCKED`: a clearly external runner/service failure unrelated to repository semantics. Record exact run/job and do not claim acceptance; a normal rerun of the unchanged required workflow is allowed only when the failure is demonstrably infrastructure-only.
- `NEW-SEMANTIC-FAILURE`: Product Rust advances and reveals a different deterministic repository failure. Record the first real failing gate and return to architecture for a new bounded task.
- `PASS`: all acceptance criteria above are satisfied on one exact head and independent review passes.

## Rollback

If MOD-001 must be withdrawn, revert only the MOD-001 test-contract commit(s) and their current-state execution-record assertions. Preserve `d2f97c0...`, `ecf79c8...`, all R1/R2/R3/FMT/reviewer history, and #2328 unchanged. Do not roll back the formatter repair to hide the semantic failure.

## Required execution handoff format

Report exactly:
- Task ID: `TFI-M6-P0-001-MOD-001`
- execution PR and exact base/head
- source commit(s)
- changed filenames and confirmation that only the authorized test file changed outside project records
- before/after contract statement
- direct state assertions added
- every required Actions run/job ID and terminal conclusion, including whether downstream Rust gates executed or were skipped
- independent-review PR/comment/verdict when complete
- execution evidence path
- failure classification, if any
- rollback state
- next owner/action

## Exit condition

MOD-001 completion only removes the moderation-contract CI blocker. It does **not** merge #2323 or complete P0-001. After accepted MOD-001 + fresh independent review + all required CI, the existing closeout chain resumes at `TFI-M6-P0-001-MERGE-001`, then canonical-main packaged E2E/evidence review and formal Release.
