# TFI-M6-P0-001 test/release handoff

## Six-category acceptance state
| Category | Current evidence | State / owner |
|---|---|---|
| Unit | focused approved/rejected `RespondCommunityJoin` + create guard tests committed | `PENDING CI`; Execution/Test owner |
| Contract | forged create/update cannot retype/re-own/re-member Community; ordinary create compatibility test committed | `PENDING CI`; Execution/Test owner |
| Integration | task-specific Actions runs the full `m6_channels_topics_contract` through messaging crate compile/test | `PENDING`; GitHub Actions/Test owner |
| E2E | exact accepted-main installable Messenger Group/Channel smoke | `PENDING AFTER PROTECTED MERGE`; Release/Test owner |
| Security | forged owner/kind/participant negative cases committed; no Community synthesis added | `PENDING CI`; Security/Code-review owner |
| Performance | dedicated microbenchmark is N/A: this patch adds no network request, polling loop, timer, retry, wait, or unbounded traversal. Substitute checks: static diff review now + existing packaged messaging smoke/performance after merge | static check DONE; packaged regression `PENDING`; Execution then Release/Test owner |

## Required exact-main package evidence (both pass and fail)
Before closure, record exact accepted canonical-main SHA, app version, platform, workflow run and job, journey/test ID, UTC timestamp, installable artifact identity, full video, step screenshots, trace, HTML/native report, logs, and `always()`-equivalent evidence upload. Target retention: 90 days; if GitHub plan/workflow permits less, record the actual maximum and reason.

## Current blocker handoff
Required PR-head messaging workflows currently stop at inherited rustfmt drift before compiling the task. This remains a real CI blocker; the narrow task-specific compile/test workflow exists only to expose task correctness without modifying unrelated M6 formatter drift. It is not a waiver and cannot satisfy protected-main/package/release closure by itself.
