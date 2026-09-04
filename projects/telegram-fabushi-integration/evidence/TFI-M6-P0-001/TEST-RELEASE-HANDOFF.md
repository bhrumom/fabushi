# TFI-M6-P0-001 test/release handoff

## Six-category acceptance state
| Category | Current evidence | State / owner |
|---|---|---|
| Unit | exact R2-reviewed-head atomic `33890057159` / `101079256166`; approved/rejected join-decision assertions include audit actor/target, approved member/invited_by/pending removal, rejected absence/pending removal | `PASS task-specific`; Execution/Test owner |
| Contract | forged create/update authority boundary + ordinary create + missing-Community regression + direct join-decision ownership semantics | `PASS task-specific`; R2 B1 CLOSED |
| Integration | full `m6_channels_topics_contract` binary compiled and all three P0-001 named regressions ran in atomic gate | `PASS task-specific`; required repository Rust gates still FAIL before later checks |
| E2E | exact accepted-main installable Messenger Group/Channel smoke | `PENDING AFTER PROTECTED MERGE`; Release/Test owner |
| Security | forged owner/kind/participant negatives plus owner→requester audit attribution | `PASS task-specific`; R3 independent review required |
| Performance | no new network/poll/timer/retry/wait/unbounded traversal; existing packaged messaging regression required after merge | static evidence only; packaged `PENDING` |

## Review continuity
- Preserve independent R1: PR #2325 head `7f594f10570822dcf23a4c3c02ddb0583ea94f14`; PR #2323 review id `5114738170` = **REVIEW-REJECTED** on historical head `73a46d3089c4f12dfb2f5659b232d51c674ed5a6`.
- Preserve independent R2: reviewer PR #2326 head `dfbae8a16531f325ab482e7dc4bdf6940b6f5f87`; PR #2323 comment `5543006832` = **REVIEW-REJECTED** on exact head `1dc165489498889504a61b7e07d5164f25188cef`.
- R2 disposition: B1 **CLOSED**, B2 **CLOSED**, B3 **OPEN/BLOCKING** because generic TFI records and PR description retained unsupported inherited formatter attribution.
- This execution round repairs only B3 record truthfulness. It does not overwrite R1/R2 records and does not relabel R2 as passed. Fresh R3 review is required.

## R2-B3 evidence-bounded formatter handoff
The historical `inherited` / `entirely inherited-only` formatter cause attribution is withdrawn. Proven facts only:
- exact base `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`;
- exact R2-reviewed head `1dc165489498889504a61b7e07d5164f25188cef`;
- no independent exact base-vs-head formatter comparison exists in this evidence set, so formatter provenance cannot be classified as base-only, PR-only, or mixed.

## Required CI blocker handoff — exact R2-reviewed head
- Mahayana fast checks `33890057133`, job `101079256711`: **FAIL** at `Verify formatting before native package setup`; subsequent native/Rust checks skipped.
- Messaging Product Gate `33890057218`: Rust job `101079257348` **FAIL** at `Rustfmt self-hosted messaging`; subsequent Rust tests/clippy skipped. Electron Messenger job `101079257046` **SUCCESS**.
- Task atomic `33890057159` / `101079256166` **SUCCESS** is additive compile/regression evidence only. It is not a waiver and must never be reported as required-CI green.

## Required exact-main package evidence
Before closure, record exact accepted canonical-main SHA, app version, platform, workflow run/job, journey/test ID, UTC timestamp, installable artifact identity, full video, step screenshots, trace, HTML/native report, logs, and pass/fail evidence upload on an `always()`-equivalent path. Target retention: 90 days or record the maximum lower limit and reason.

Current delivery state is **PENDING/BLOCKED**: PR #2323 remains open/unmerged; no canonical-main package, screenshot/video/trace/report/log bundle, test Release, or formal Release exists for this task.

## Next owner
Independent code-review group R3: reread the real PR #2323 diff at the new record-repair head, verify that R2 B3 unsupported cause attribution is consistently withdrawn/superseded, verify exact-head GitHub Actions without treating atomic/Electron PASS as a required-CI waiver, and issue a fresh verdict. Execution group must not merge, test-release, or release.
