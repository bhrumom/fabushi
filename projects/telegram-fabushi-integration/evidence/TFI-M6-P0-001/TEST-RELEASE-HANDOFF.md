# TFI-M6-P0-001 test/release handoff

## Six-category acceptance state
| Category | Current evidence | State / owner |
|---|---|---|
| Unit | repair-head atomic `33889474580` job `101077337394`; approved/rejected join-decision assertions include audit actor/target, approved member/invited_by/pending removal, rejected absence/pending removal | `PASS task-specific`; Execution/Test owner |
| Contract | forged create/update authority boundary + ordinary create + missing-Community regression + direct join-decision ownership semantics | `PASS task-specific`; Execution/Test owner |
| Integration | full `m6_channels_topics_contract` binary compiled and all three P0-001 named regressions ran in atomic gate | `PASS task-specific`; required repository Rust gates still FAIL before tests |
| E2E | exact accepted-main installable Messenger Group/Channel smoke | `PENDING AFTER PROTECTED MERGE`; Release/Test owner |
| Security | forged owner/kind/participant negatives plus owner→requester audit attribution | `PASS task-specific`; independent rereview required |
| Performance | no new network/poll/timer/retry/wait/unbounded traversal; existing packaged messaging regression required after merge | static evidence only; packaged `PENDING` |

## R1 handoff
- Preserve independent R1: PR #2325 head `7f594f10570822dcf23a4c3c02ddb0583ea94f14`; PR #2323 review id `5114738170` = **REVIEW-REJECTED**.
- **B1 repaired:** existing Rust fixture now directly proves approved/rejected CommunityChanged audit/member/pending ownership semantics; atomic `33889474580` / `101077337394` **SUCCESS**.
- **B2 repaired:** actual TDLib material read is `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`, `td/telegram/Requests.h`, `createNewSupergroupChat`, `processChatJoinRequest`, and `LICENSE_1_0.txt` / Boost Software License 1.0. Only the boundary principle was adopted; no upstream/reconstructed-Grok source was copied/translated/ported/adapted.
- **B3 repaired by conservative wording:** the unproven `entirely inherited-only` rustfmt attribution is withdrawn. No independent exact-base formatter comparison exists in this task evidence.

## Required CI blocker handoff
- Mahayana fast checks `33889474470`, job `101077337527`: **FAIL** at `Verify formatting before native package setup`; subsequent native checks skipped.
- Messaging Product Gate `33889474495`: Rust job `101077337752` **FAIL** at `Rustfmt self-hosted messaging`; subsequent Rust tests/clippy skipped. Electron Messenger job `101077337355` **SUCCESS**.
- These required failures remain closure blockers. The atomic gate is not a waiver and must never be reported as required-CI green.

## Required exact-main package evidence
Before closure, record exact accepted canonical-main SHA, app version, platform, workflow run/job, journey/test ID, UTC timestamp, installable artifact identity, full video, step screenshots, trace, HTML/native report, logs, and pass/fail evidence upload on an `always()`-equivalent path. Target retention: 90 days or record the maximum lower limit and reason.

## Next owner
Independent code-review group: reread PR #2323 real diff at the new execution head, preserve R1 history, verify B1/B2/B3, and issue a fresh verdict. Execution group must not merge or release.
