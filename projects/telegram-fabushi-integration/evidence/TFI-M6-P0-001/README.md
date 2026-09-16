# TFI-M6-P0-001 execution evidence

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-P0-001`
- Audited base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Branch: `fix/tfi-m6-p0-001-community-create-boundary`
- PR: #2323, open/unmerged
- Application/compile repair: `726b4210ddd4d9a967778193a8d374b5f8bad206`
- R1 repair head verified by Actions: `4b6218e3aaa385ad0e3ef3ad0f908339c7b684dc`
- Exact R2-reviewed execution head: `1dc165489498889504a61b7e07d5164f25188cef`
- R2-B3 record-truth repair commit: `8610d0f6a6c143281a6ffede270ad4821dc780a9`
- Execution handoff comment: PR #2323 comment `5543243769`

## Scope evidence
1. Historical implementation scope on this PR: `native/mahayana-messaging/src/engine.rs`, `src/service.rs`, `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`, and additive `.github/workflows/tfi-m6-p0-001-atomic-gate.yml`.
2. **R2-B3 repair scope in this round:** only `projects/telegram-fabushi-integration/**` records plus PR #2323 description/comments. No application source, regression test, or workflow is modified by the record repair.
3. Commit diff `1dc165489498889504a61b7e07d5164f25188cef..8610d0f6a6c143281a6ffede270ad4821dc780a9` is exactly one commit and 15 files, all under `projects/telegram-fabushi-integration/**`.
4. No local Cargo/npm/Gradle/Xcode/build/test/E2E/native/app execution is used in this record repair.

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

R2 correctly rejected the execution state while generic records still contradicted this conservative statement. The records-only repair synchronizes those records and PR metadata; it does not claim R2 retroactively passed. Fresh R3 independent review is required.

## R2-B3 repair-head Actions evidence
Commit `8610d0f6a6c143281a6ffede270ad4821dc780a9` triggered a fresh PR-head validation round after the record-only correction:
- `TFI M6 P0-001 atomic gate` run `33893374373`, job `101090161050` — **SUCCESS**; compile + named P0-001 regressions passed.
- `Mahayana fast checks` run `33893374391`, job `101090161882` — **FAIL** at `Verify formatting before native package setup`; all subsequent Rust/native checks skipped.
- `Messaging Product Gate` run `33893374357`: Rust job `101090161844` — **FAIL** at `Rustfmt self-hosted messaging`; subsequent tests/clippy/bridge checks skipped. Electron job `101090161451` — **SUCCESS**.
- `Developer Fiat Commerce` `33893374338` and `Explicit automerge` `33893374339` — **SUCCESS**.

This fresh head reproduces the required formatter-stage blocker after a records-only commit. It still does **not** establish formatter provenance because no independent exact base-vs-head formatter comparison was performed. The correct statement remains: formatter failure is proven; cause attribution is undetermined.

## Six-category state
| Category | Evidence | State |
|---|---|---|
| Unit | `33893374373` / `101090161050` | PASS task-specific on repair head |
| Contract | direct create/update + join-decision ownership regressions | PASS task-specific / R2 B1 CLOSED |
| Integration | full M6 contract binary compiled and named P0-001 tests ran | PASS task-specific; required Rust workflows FAIL before later tests |
| E2E | exact accepted-main installable Messenger Group/Channel journey | PENDING |
| Security | forged authority negatives + owner→requester audit assertions | PASS task-specific; R3 pending |
| Performance | no new network/poll/timer/retry/wait/unbounded traversal; packaged regression required after merge | static only / packaged PENDING |

## Current verdict
`REVIEW-REJECTED(R2) / CI-BLOCKED / R2-B3-RECORD-REPAIR-PUSHED / R3-PENDING / CLOSURE-BLOCKED`.
No protected merge, exact-main packaged E2E/evidence bundle, Release, or fresh independent `REVIEW-PASS` is claimed.

## 2026-09-05 MOD-001 architecture diagnosis — append-only current-state index
This section supersedes only the current-state verdict above; every historical evidence statement remains preserved for its original head/time.

- Exact architecture input: #2323 head `ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d` over `9e88a2e9c030fe05147460dfa580366cf9aa433d`.
- FMT-001 source commit `d2f97c0c22411a49ef926c0bb9c049be18348b10`; reviewer PR #2329 head `02fd655b478798ee9818f9f56e8b2010cf44c94a` = `REVIEW-PASS(FMT-001 scope)`.
- Current required Product Rust `33898670053` / `101107313643`: rustfmt PASS; full `cargo test --all-targets` FAIL at pre-existing post-ban assertion in `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine`; later clippy/media/bridge skipped.
- Mahayana `33898670533` / `101107312228`, Product Electron `101107313196`, and Atomic `33898670050` / `101107311938` are SUCCESS but do not waive Product Rust.
- Architecture root classification: **parent-branch pre-existing latent semantic-contract contradiction; test expectation mismatches `Banned -> ConversationParticipantRemoved` plus participation-first `QueueMessage` error precedence**. Not P0-001, FMT-001, or CI-environment regression.
- New architecture evidence: `MOD-001-ARCHITECTURE-DIAGNOSIS-2026-09-05.md`.
- New authoritative task: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-001-MOD-001-align-post-ban-send-contract.md`.
- Task scope: exactly one product/test file, `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`, plus append-only TFI execution records; production engine/service/workflow changes are forbidden.
- Open-source-first: TDLib/Boost-1.0, Continuwuity/Apache-2.0, Synapse/AGPL-3.0+commercial were evaluated; only boundary/test principles are borrowed and no code is copied.
- Revised dependency: `FMT-001 -> MOD-001 -> fresh independent REVIEW-PASS + all required CI -> MERGE-001 -> E2E-001 -> packaged evidence review PASS -> RELEASE-001 -> FULL-CLOSE`.
- Current verdict: `ARCHITECTURE-MOD-PLAN-READY / CI-BLOCKED / CLOSURE-BLOCKED`; P0-002 remains blocked.
