# TFI-M6-MAINSAFE-001-OWNERSHIP-001 独立代码复审任务

- Review status: `REVIEW-PASS-OWNERSHIP-001`
- Project: `FAB-P0001 / TFI`
- Role: independent code review only
- Product PR: `#2336`
- Product canonical base: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Reviewed exact product head: `8760b7587f6d576262e5993a72b5c5112ff595db`
- Architecture records-only PR: `#2337@ea9b5b62d22ed73b9de350075797ea4c54eb69e4`
- Architecture frozen ownership-blocker product head: `115cd55065d03b66f14d7e086d454709d24d2286`
- Execution final handoff comment: `#2336 comment 5546349771`
- Review date: `2026-09-05`

## 1. Review boundary

This review independently validates the atomic `TFI-M6-MAINSAFE-001-OWNERSHIP-001` execution delta and its GitHub evidence. It does not implement application code, merge, publish, retarget/rebase the product PR, weaken any gate, or substitute for test-release/formal-release work.

Atomic product comparison boundary:

```text
115cd55065d03b66f14d7e086d454709d24d2286
  -> bd0fb654212469bf88a95d558ebf12fd11efd658
  -> 7f7da51fa7a3d91c5df9482d38ca58c50cc0c7cc
  -> 8760b7587f6d576262e5993a72b5c5112ff595db
```

The full product PR has earlier `MAINSAFE-RUST-CANONICAL` reconstruction history. Therefore this review distinguishes the full PR's historical file set from the frozen OWNERSHIP-001 atomic delta above.

## 2. Authoritative inputs read from GitHub

Repository/project governance:

- root `AGENTS.md`
- `projects/PORTFOLIO.json`
- `projects/telegram-fabushi-integration/SOURCE_OF_TRUTH.md`
- `projects/telegram-fabushi-integration/PROJECT.yaml`
- `projects/telegram-fabushi-integration/README.md`

Architecture freeze from `#2337@ea9b5b62d22ed73b9de350075797ea4c54eb69e4`:

- `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-OWNERSHIP-001.md`
- `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/ARCHITECTURE-RUST-BLOCKER-DIAGNOSIS-2026-09-05.md`
- `projects/telegram-fabushi-integration/management/70-2026-09-05-M6-MAINSAFE-RUST-架构交接.md`

Execution records from exact product head `8760b7587f6d576262e5993a72b5c5112ff595db`:

- `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-OWNERSHIP-001-execution-2026-09-05.md`
- `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/OWNERSHIP-001-EXECUTION-2026-09-05.md`
- `projects/telegram-fabushi-integration/management/71-2026-09-05-M6-MAINSAFE-001-OWNERSHIP-001-执行状态与验收.md`
- `projects/telegram-fabushi-integration/management/72-2026-09-05-M6-MAINSAFE-001-OWNERSHIP-001-执行变更日志.md`

GitHub truth also included `#2336` metadata, changed files, commit chain, comments, exact-head workflow runs/jobs, and raw job logs.

## 3. Frozen allowlist and atomic scope result

`compare(115cd550...8760b758...)` is a strict fast-forward delta (`ahead_by=3`, `behind_by=0`) with exactly five paths:

1. `native/mahayana-messaging/src/engine.rs` — `+4/-4`, only four owned-target clone substitutions.
2. `projects/telegram-fabushi-integration/management/tasks/TFI-M6-MAINSAFE-001-OWNERSHIP-001-execution-2026-09-05.md`
3. `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/OWNERSHIP-001-EXECUTION-2026-09-05.md`
4. `projects/telegram-fabushi-integration/management/71-2026-09-05-M6-MAINSAFE-001-OWNERSHIP-001-执行状态与验收.md`
5. `projects/telegram-fabushi-integration/management/72-2026-09-05-M6-MAINSAFE-001-OWNERSHIP-001-执行变更日志.md`

No second product source, test, workflow, Cargo/dependency, version, release, or unrelated governance file appears in the atomic task delta.

## 4. Semantic acceptance

### `Command::SubscribeChannel`

- retained owned audit target changes only from `Some(actor_id)` to `Some(actor_id.clone())`;
- borrowed `&actor_id`, subscription query, permission checks, control flow, audit actor/target/action/detail fields and event semantics remain unchanged.

### `Command::UnsubscribeChannel`

- retained owned audit target changes only from `Some(actor_id)` to `Some(actor_id.clone())`;
- borrowed actor, owner guard, state transition, control flow, audit fields and event semantics remain unchanged.

### `Command::RespondCommunityJoin`

- approved/rejected audit target arms change only from `Some(requester_id)` to `Some(requester_id.clone())`;
- subsequent `community.members.get(&requester_id)` remains in the same semantic flow;
- admin authorization, approve/reject behavior, `JoinRequestNotFound` error behavior, projection and event semantics remain intact.

### Type/helper/control-flow guardrails

- `ActorId` remains String-backed and `Clone`, not `Copy`;
- `append_community_audit` still takes the actor as `&ActorId` and retained target as `Option<ActorId>`;
- no helper/public API/type redesign, `Rc`/`Arc`, dummy construction, visibility change, authorization-field deletion, `allow`/`expect` suppression, control-flow rewrite, Cargo/dependency or workflow weakening was introduced by the atomic delta.

## 5. Exact-head verification requirement

Acceptance is bound to product exact head `8760b7587f6d576262e5993a72b5c5112ff595db`, not old `115cd...`, old PR `#2323`, generic green history, or architecture records-only PR `#2337`.

The exact-head Actions evidence and raw-log findings are recorded in:

- `projects/telegram-fabushi-integration/evidence/TFI-M6-MAINSAFE-001/OWNERSHIP-001-REVIEW-2026-09-05.md`

No local heavy build/test/rustfmt/clippy/E2E was run by this reviewer. Heavy verification provenance is GitHub Actions on the product PR's exact head/merge ref.

## 6. Open-source-first basis

The implementation strategy is consistent with Rust's official ownership diagnostics and mature borrowed/owned identifier design:

- Rust E0382: https://doc.rust-lang.org/stable/error_codes/E0382.html
- Rust E0505: https://doc.rust-lang.org/stable/error_codes/E0505.html
- Clippy CI: https://doc.rust-lang.org/clippy/continuous_integration/index.html
- Ruma `UserId` / `OwnedUserId`: https://docs.rs/ruma-common/latest/ruma_common/identifiers/struct.UserId.html

The selected fix clones only at the retained-owned payload boundary. It does not convert the identifier to `Copy`, suppress lint/compiler diagnostics, add a dependency, or copy external project code.

## 7. Decision and next gate

Decision: `REVIEW-PASS-OWNERSHIP-001`.

This PASS means only that the reviewed exact product head may enter the protected canonical-main MERGE gate. It does **not** mean `#2336` is merged, canonical-main has been read back, packaged E2E has run, test release has passed, or formal release is authorized.

Unique next action after this review handoff: the designated merge/test-release workflow must first perform the protected merge of `#2336` and read back the resulting exact canonical-main SHA. Only after that may the test-release group run packaged build + simulated-user E2E on that exact canonical main and preserve complete video, key screenshots, trace/report/log for return to code review.