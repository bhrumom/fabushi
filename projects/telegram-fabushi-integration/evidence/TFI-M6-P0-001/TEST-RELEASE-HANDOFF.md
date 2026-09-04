# TFI-M6-P0-001 test/release handoff

## Six-category acceptance state
| Category | Current evidence | State / owner |
|---|---|---|
| Unit | focused approved/rejected `RespondCommunityJoin` now directly asserts approved/rejected CommunityChanged audit actor/target, approved `Member` + `invited_by` + pending removal, and rejected absence + pending removal; current R1-repair Actions pending | `PENDING current repair CI`; Execution/Test owner |
| Contract | forged create/update cannot retype/re-own/re-member Community; ordinary create compatibility; R1 semantic ownership assertions strengthened in the same existing fixture | previous task-specific PASS; strengthened regression `PENDING current repair CI`; Execution/Test owner |
| Integration | atomic gate compiles the full M6 contract test binary, then runs the three P0-001 named regressions | previous task-specific PASS; current repair `PENDING`; required repository gates remain blockers; GitHub Actions/Test owner |
| E2E | exact accepted-main installable Messenger Group/Channel smoke | `PENDING AFTER PROTECTED MERGE`; Release/Test owner |
| Security | forged owner/kind/participant negative cases; no Community synthesis; approved/rejected owner-to-requester audit attribution now directly asserted | previous task-specific PASS; strengthened regression `PENDING current repair CI`; independent rereview required; Security/Code-review owner |
| Performance | dedicated microbenchmark is N/A: this patch adds no network request, polling loop, timer, retry, wait, or unbounded traversal. Substitute checks: static diff review now + existing packaged messaging smoke/performance after merge | static check applicable; packaged regression `PENDING`; Execution then Release/Test owner |

## Required exact-main package evidence (both pass and fail)
Before closure, record exact accepted canonical-main SHA, app version, platform, workflow run and job, journey/test ID, UTC timestamp, installable artifact identity, full video, step screenshots, trace, HTML/native report, logs, and `always()`-equivalent evidence upload. Target retention: 90 days; if GitHub plan/workflow permits less, record the actual maximum and reason.

## R1 review handoff input
- Reviewer PR #2325 head `7f594f10570822dcf23a4c3c02ddb0583ea94f14` and PR #2323 review id `5114738170` remain **REVIEW-REJECTED** historical/active review evidence until a fresh rereview.
- R1-B1 is repaired by strengthening the existing Rust regression only; no new API/product semantic is introduced.
- R1-B2 provenance now records actual TDLib material read at `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`: `td/telegram/Requests.h`, symbols `createNewSupergroupChat` and `processChatJoinRequest`, plus `LICENSE_1_0.txt` / Boost Software License 1.0. Only the boundary principle was adopted; no upstream code or reconstructed Grok code was copied/translated/ported/adapted.
- R1-B3 uses the reviewer-authorized conservative resolution: the execution record withdraws the stronger `inherited-only` attribution because no independent base-vs-head formatter comparison exists. Required rustfmt failures remain closure blockers.

## Required-gate blocker handoff
Required PR-head messaging workflows have been observed failing at rustfmt before their Rust compile/test stages. The audited base `9e88a2e9c030fe05147460dfa580366cf9aa433d` has no recorded formatter check run in the current evidence set, and the atomic workflow does not provide an independent base/head formatter comparison. Therefore this handoff does **not** attribute every formatter difference to the base. It also does not waive, delete, weaken, or mark green any required gate.

### Historical diagnostic / non-waiver note
- Pre-review atomic run `33886105443` / job `101066138054` compiled the full M6 contract binary and passed all three then-current P0-001 regressions.
- Full-file diagnostic run `33885625325` / job `101064549625` compiled and passed four of five tests; its sole failure was the unchanged later-M6 moderation assertion `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine`, outside this task.
- Required pre-review runs `33886105678` / job `101066137829` and `33886105464` / Rust job `101066136842` failed at rustfmt before Rust tests; Electron job `101066137101` passed.
- Current R1-repair head must obtain fresh GitHub Actions evidence before handoff to rereview; no local Cargo/npm/Gradle/Xcode/build/test/E2E is used.
