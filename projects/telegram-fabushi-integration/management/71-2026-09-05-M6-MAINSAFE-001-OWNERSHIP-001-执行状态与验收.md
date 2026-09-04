# 71 — TFI-M6-MAINSAFE-001-OWNERSHIP-001 执行状态与验收 — 2026-09-05

Current state: `EXECUTION-IN-PROGRESS / FINAL-HEAD-CI-PENDING / REVIEW-BLOCKED / MERGE-BLOCKED`.

## Identity
- Project: `FAB-P0001 / TFI`.
- Task: `TFI-M6-MAINSAFE-001-OWNERSHIP-001`.
- Canonical base at execution start: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- Architecture source: records-only PR `#2337@ea9b5b62d22ed73b9de350075797ea4c54eb69e4`.
- Existing product PR: `#2336`, starting exact head `115cd55065d03b66f14d7e086d454709d24d2286`, base canonical main, open/unmerged.

## Acceptance matrix
| Acceptance | Required evidence | Current state |
| --- | --- | --- |
| `OWN-AC01-SCOPE` | task delta only `engine.rs` + TFI records; no retarget/rebase/force-push | STATIC-PASS / PUSH-READBACK-PENDING |
| `OWN-AC02-OWNERSHIP` | Subscribe/Unsubscribe E0505 and RespondCommunityJoin E0382 ownership defects removed without behavior change | STATIC-PASS / ACTIONS-PENDING |
| `OWN-AC03-MSG-GATE` | Messaging Product Gate Rust job passes rustfmt, `cargo test --all-targets`, Clippy `-D warnings` | PENDING |
| `OWN-AC04-CONTRACTS` | `m6_channels_topics_contract` and `unread_projection_contract` actually execute and pass | PENDING |
| `OWN-AC05-SELFHOSTED` | Fabushi self-hosted messaging Rust core + social Actor exact-head jobs pass | PENDING |
| `OWN-AC06-HARNESS` | Mahayana fast Rust-native Harness actually executes and passes | PENDING |
| `OWN-AC07-REQUIRED-CI` | all selected/required exact-head CI/governance/fiat/automerge gates pass | PENDING |
| `OWN-AC08-REVIEW` | fresh independent code review of exact final #2336 head | BLOCKED until AC01-07 |
| `OWN-AC09-MERGE` | protected merge/canonical-main readback | BLOCKED; out of this session |

## Static implementation acceptance
- Candidate product repair commit `bd0fb654212469bf88a95d558ebf12fd11efd658` is a direct child of starting head `115cd550...`.
- GitHub compare reports exactly one product file changed and exactly four ownership substitutions: two `actor_id.clone()` retained audit targets and two `requester_id.clone()` retained audit targets.
- Acting audit identity remains `&ActorId`; helper signatures and public APIs are unchanged.
- Permission checks, member/subscriber lookup, audit actions/fields, event order, errors and participant projection control flow are unchanged.
- No local build/test/rustfmt/clippy/E2E was run.

## Baseline dynamic state
At `#2336@115cd550...`, Messaging Product Gate run `33914564827` / Rust job `101158638727` has rustfmt PASS followed by three ownership compile errors; the two required contract test binaries and Clippy do not execute. Architecture froze self-hosted messaging and Mahayana Harness failures at that head as the same downstream compile blocker.

## Stop rule
Any distinct non-ownership error after the repair, or any need for a second product/test source file, immediately changes this task to `EXECUTION-OWNERSHIP-001-BLOCKED / SCOPE-EXPANSION-REQUIRED` and returns it to architecture. No independent review, merge, task 002/003, test release or formal release may start while this record is pending.
