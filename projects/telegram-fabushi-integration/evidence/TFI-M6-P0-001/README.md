# TFI-M6-P0-001 execution evidence

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-P0-001`
- Audited base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Branch: `fix/tfi-m6-p0-001-community-create-boundary`
- PR: #2323, open/unmerged
- Application/compile repair: `726b4210ddd4d9a967778193a8d374b5f8bad206`
- R1 repair head verified by Actions: `4b6218e3aaa385ad0e3ef3ad0f908339c7b684dc`
- Exact R2-reviewed execution head: `1dc165489498889504a61b7e07d5164f25188cef`

## Scope evidence
1. Historical implementation scope on this PR: `native/mahayana-messaging/src/engine.rs`, `src/service.rs`, `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`, and additive `.github/workflows/tfi-m6-p0-001-atomic-gate.yml`.
2. **R2-B3 repair scope in this round:** only `projects/telegram-fabushi-integration/**` records plus PR #2323 description/comments. No application source, regression test, or workflow is modified by the record repair.
3. No local Cargo/npm/Gradle/Xcode/build/test/E2E/native/app execution is used in this record repair.

## R1 review provenance — preserved
- Review-record PR #2325 head `7f594f10570822dcf23a4c3c02ddb0583ea94f14`.
- PR #2323 review id `5114738170` = **REVIEW-REJECTED** on historical head `73a46d3089c4f12dfb2f5659b232d51c674ed5a6`.
- R1 records remain historical evidence and are not overwritten.

## R2 review provenance — preserved
- Reviewer PR #2326 head `dfbae8a16531f325ab482e7dc4bdf6940b6f5f87`, based directly on canonical `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- PR #2323 reviewer handoff comment `5543006832` = **REVIEW-REJECTED** on exact execution head `1dc165489498889504a61b7e07d5164f25188cef`.
- R2 B1 = **CLOSED**; B2 = **CLOSED**; B3 = **OPEN / BLOCKING** at review time because generic durable TFI records and the PR description still asserted unsupported inherited formatter provenance.
- Durable reviewer records remain in reviewer PR #2326 and are referenced, not copied/rewritten, by this execution branch.

## B1 — semantic ownership regression
The existing join-decision regression directly inspects `Event::CommunityChanged { community }` and asserts:
- approved `JoinApproved` audit actor `human:owner`, target `human:approved`;
- approved requester is a `Member`, `invited_by = human:owner`, and removed from pending;
- rejected `JoinRejected` audit actor `human:owner`, target `human:rejected`;
- rejected requester is absent from members and removed from pending.
No new API/runtime semantics were introduced. R2 independently closed B1.

**Exact R2-head Actions proof:** `TFI M6 P0-001 atomic gate` run `33890057159`, job `101079256166` = **SUCCESS** on `1dc165489498889504a61b7e07d5164f25188cef`; full contract binary compile and all three named P0-001 regressions passed.

## B2 — exact open-source-first provenance
Official material actually read:
- `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`;
- `td/telegram/Requests.h`;
- handler declarations for `td_api::createNewSupergroupChat` and `td_api::processChatJoinRequest`;
- `LICENSE_1_0.txt`, Boost Software License 1.0.
Only the create/join-request boundary principle was adopted. No TDLib, reconstructed Grok, Grok Bot, Codex, or other upstream implementation source was copied, translated, ported or adapted. R2 independently closed B2.

## B3 — formatter attribution evidence correction
The historical claim that required rustfmt failures were wholly/inherently inherited is **withdrawn and superseded**. Current evidence proves only the following on exact R2-reviewed head `1dc165489498889504a61b7e07d5164f25188cef`:
- Mahayana fast run `33890057133`, job `101079256711` = **FAIL** at `Verify formatting before native package setup`; subsequent native/Rust checks skipped.
- Messaging Product Gate run `33890057218`, Rust job `101079257348` = **FAIL** at `Rustfmt self-hosted messaging`; subsequent Rust tests/clippy skipped.
- Product Electron job `101079257046` = **SUCCESS**.
- Atomic compile/test `33890057159` / `101079256166` = **SUCCESS**, but it does not provide base-vs-head formatter attribution and cannot waive required CI.
- This evidence set contains no independent formatter run/diff that compares exact base `9e88a2e9c030fe05147460dfa580366cf9aa433d` with the PR head. Therefore the formatter failure source is **undetermined: base, PR, or mixed**.

R2 correctly rejected the execution state while generic records still contradicted this conservative statement. This record-only round synchronizes those records and PR metadata; it does not claim R2 retroactively passed. Fresh R3 independent review is required.

## Six-category state
| Category | Evidence | State |
|---|---|---|
| Unit | `33890057159` / `101079256166` | PASS task-specific |
| Contract | direct create/update + join-decision ownership regressions | PASS task-specific / R2 B1 CLOSED |
| Integration | full M6 contract binary compiled and named P0-001 tests ran | PASS task-specific; required Rust workflows FAIL before later tests |
| E2E | exact accepted-main installable Messenger Group/Channel journey | PENDING |
| Security | forged authority negatives + owner→requester audit assertions | PASS task-specific; R3 pending |
| Performance | no new network/poll/timer/retry/wait/unbounded traversal; packaged regression required after merge | static only / packaged PENDING |

## Current verdict
`REVIEW-REJECTED(R2) / CI-BLOCKED / R2-B3-RECORD-REPAIR-PUSHED / R3-PENDING / CLOSURE-BLOCKED`.
No protected merge, exact-main packaged E2E/evidence bundle, Release, or fresh independent `REVIEW-PASS` is claimed.
