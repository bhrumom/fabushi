# TFI-M6-P0-001 execution evidence

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-P0-001`
- Audited base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Branch: `fix/tfi-m6-p0-001-community-create-boundary`
- PR: #2323, open/unmerged, 19 changed files
- Application/compile repair: `726b4210ddd4d9a967778193a8d374b5f8bad206`
- R1 repair head verified by Actions: `4b6218e3aaa385ad0e3ef3ad0f908339c7b684dc`

## Scope evidence
1. `native/mahayana-messaging/src/engine.rs` — scoped optional participant-event compile repair.
2. `native/mahayana-messaging/src/service.rs` — Community-backed generic create/update authority boundary.
3. `native/mahayana-messaging/tests/m6_channels_topics_contract.rs` — focused P0-001 regressions, now including direct approved/rejected audit/member/pending ownership assertions.
4. `.github/workflows/tfi-m6-p0-001-atomic-gate.yml` — additive compile/test evidence only; it does not replace required repository gates.

No local Cargo/npm/Gradle/Xcode/build/test/E2E/native/app execution was performed in this R1 repair.

## R1 review provenance
- Review-record PR #2325 head `7f594f10570822dcf23a4c3c02ddb0583ea94f14`.
- PR #2323 review id `5114738170` = **REVIEW-REJECTED**. It remains preserved until a fresh rereview.
- Existing execution anchor comment `5542235859` remains historical evidence.

## B1 — semantic ownership regression
The existing join-decision regression directly inspects `Event::CommunityChanged { community }` and asserts:
- approved `JoinApproved` audit actor `human:owner`, target `human:approved`;
- approved requester is a `Member`, `invited_by = human:owner`, and removed from pending;
- rejected `JoinRejected` audit actor `human:owner`, target `human:rejected`;
- rejected requester is absent from members and removed from pending.
No new API/runtime semantics were introduced.

**Actions proof:** `TFI M6 P0-001 atomic gate` run `33889474580`, job `101077337394` = **SUCCESS** on exact repair head `4b6218e3...`. Full contract binary compile succeeded and the three named P0-001 regressions passed.

## B2 — exact open-source-first provenance
Official material actually read:
- `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`;
- `td/telegram/Requests.h`;
- handler declarations for `td_api::createNewSupergroupChat` and `td_api::processChatJoinRequest`;
- `LICENSE_1_0.txt`, Boost Software License 1.0.
Only the create/join-request boundary principle was adopted. No TDLib, reconstructed Grok, Grok Bot, Codex, or other upstream implementation source was copied, translated, ported or adapted.

## B3 — formatter attribution evidence
The prior claim that required rustfmt failures were wholly inherited is withdrawn because this task has no independent formatter run for exact base `9e88a2e9...`. Proven facts only:
- Mahayana fast run `33889474470`, job `101077337527` = **FAIL** at `Verify formatting before native package setup`; later native steps skipped.
- Messaging Product Gate run `33889474495`, Rust job `101077337752` = **FAIL** at `Rustfmt self-hosted messaging`; later Rust tests/clippy skipped.
- Product Electron job `101077337355` = **SUCCESS**.
- Atomic compile/test success does not provide base-vs-head formatter attribution.
No required gate was removed, skipped, weakened or relabeled green.

## Six-category state
| Category | Evidence | State |
|---|---|---|
| Unit | `33889474580` / `101077337394` | PASS task-specific |
| Contract | direct create/update + join-decision ownership regressions | PASS task-specific |
| Integration | full M6 contract binary compiled and named P0-001 tests ran | PASS task-specific; required Rust workflows still FAIL before tests |
| E2E | exact accepted-main installable Messenger Group/Channel journey | PENDING |
| Security | forged authority negatives + owner→requester audit assertions | PASS task-specific; rereview pending |
| Performance | no new network/poll/timer/retry/wait/unbounded traversal; packaged regression required after merge | static only / packaged PENDING |

## Current verdict
`IMPLEMENTED / R1-B1-B2-B3-REPAIRED / CI-BLOCKED / REREVIEW-READY / CLOSURE-BLOCKED`.
No protected merge, exact-main packaged E2E, Release, or fresh independent `REVIEW-PASS` is claimed.
