# TFI-M6-P0-001 test/release handoff

## Six-category acceptance state
| Category | Current evidence | State / owner |
|---|---|---|
| Unit | focused approved/rejected `RespondCommunityJoin` + create guard tests; atomic run `33885842476` job `101065268536` | `PASS task-specific`; Execution/Test owner |
| Contract | forged create/update cannot retype/re-own/re-member Community; ordinary create compatibility; atomic run `33885842476` | `PASS task-specific`; Execution/Test owner |
| Integration | atomic gate compiles the full M6 contract test binary, then runs the three P0-001 named regressions; run `33885842476` job `101065268536` | `PASS task-specific`; required repository gates still FAIL; GitHub Actions/Test owner |
| E2E | exact accepted-main installable Messenger Group/Channel smoke | `PENDING AFTER PROTECTED MERGE`; Release/Test owner |
| Security | forged owner/kind/participant negative cases; no Community synthesis; atomic run `33885842476` | `PASS task-specific`; independent code review still PENDING; Security/Code-review owner |
| Performance | dedicated microbenchmark is N/A: this patch adds no network request, polling loop, timer, retry, wait, or unbounded traversal. Substitute checks: static diff review now + existing packaged messaging smoke/performance after merge | static check DONE; packaged regression `PENDING`; Execution then Release/Test owner |

## Required exact-main package evidence (both pass and fail)
Before closure, record exact accepted canonical-main SHA, app version, platform, workflow run and job, journey/test ID, UTC timestamp, installable artifact identity, full video, step screenshots, trace, HTML/native report, logs, and `always()`-equivalent evidence upload. Target retention: 90 days; if GitHub plan/workflow permits less, record the actual maximum and reason.

## Current blocker handoff
Required PR-head messaging workflows currently stop at inherited rustfmt drift before compiling the task. This remains a real CI blocker; the narrow task-specific compile/test workflow exists only to expose task correctness without modifying unrelated M6 formatter drift. It is not a waiver and cannot satisfy protected-main/package/release closure by itself.

### Diagnostic/non-waiver note
Full-file diagnostic run `33885625325` / job `101064549625` compiled the crate/test binary and passed four of five tests. Its sole failure was the unchanged later-M6 moderation assertion `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine`. This task did not change that test or its moderation path. Required repository runs `33885842392` and `33885842303` still fail at inherited rustfmt before Rust test execution, so no closure pass is claimed.
