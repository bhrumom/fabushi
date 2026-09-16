# TFI-M6-P0-001-MOD-001 architecture diagnosis — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Parent task: `TFI-M6-P0-001`
- Proposed atomic repair: `TFI-M6-P0-001-MOD-001`
- Execution PR under diagnosis: #2323
- Exact diagnosed head: `ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d`
- Formatter source commit: `d2f97c0c22411a49ef926c0bb9c049be18348b10`
- Audited base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Frozen formatter architecture PR: #2328 at `7b1964294f15ff9aba352116a166ceef5ae499ae` — referenced only, not rewritten
- Independent formatter review PR: #2329 at `02fd655b478798ee9818f9f56e8b2010cf44c94a`
- Review verdict on #2323: `REVIEW-PASS(FMT-001 scope) / CI-BLOCKED / CLOSURE-BLOCKED`

This is an append-only architecture diagnosis of an **open/unmerged** execution head. It does not claim that `ecf79c8...` is canonical `main`, and it does not replace any R1/R2/R3/FMT execution/reviewer history.

## 1. Required CI truth read from GitHub Actions

Exact `ecf79c8...` pull-request validation was read from the real job logs, not inferred from summaries:

- Messaging Product Gate run `33898670053`, Rust job `101107313643`:
  - checkout resolved the PR merge ref for exact head `ecf79c8...` over base `9e88a2e...`;
  - stable Rust resolved to `1.98.1`;
  - `Rustfmt self-hosted messaging` **PASS**;
  - `cargo test --manifest-path native/mahayana-messaging/Cargo.toml --all-targets` ran and failed only in `m6_channels_topics_contract::slow_mode_and_moderation_are_enforced_by_the_rust_state_machine` at `tests/m6_channels_topics_contract.rs:632:5`;
  - the failed assertion expected `EngineError::CommunitySendRestricted(ConversationId::new("group:m6"))` after `human:member` had been moderated to `MemberStatus::Banned`;
  - the other four M6 contract tests in that binary passed, including all three P0-001-focused regressions;
  - downstream Product Rust clippy/media/bridge steps were **SKIPPED** because the full test step returned Cargo exit 101.
- Product Electron job `101107313196` = **SUCCESS**. This is additive only and does not waive Product Rust.
- Mahayana fast run `33898670533`, job `101107312228` = **SUCCESS** end-to-end.
- TFI M6 P0-001 Atomic run `33898670050`, job `101107311938` = **SUCCESS** for the task-specific compile + three focused regressions. This is additive only and does not waive Product Rust.

The Product Rust log reports the failed expected assertion but does not print the value of `banned_send_error`; the actual error classification below is therefore derived from the deterministic state transition and branch order in the exact source, not fabricated as a log quotation.

## 2. Base-vs-head attribution

The failing contract is not introduced by P0-001:

1. `native/mahayana-messaging/tests/m6_channels_topics_contract.rs` contains `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine` on exact base `9e88a2e...` with the same post-ban `CommunitySendRestricted` expectation.
2. The #2323 patch for that file adds/repairs P0-001-focused regressions elsewhere; it does not change the body of this pre-existing slow-mode/moderation test.
3. The #2323 patch for `native/mahayana-messaging/src/engine.rs` changes P0-001 Community create/update/join/audit ownership semantics; it does not change the relevant `Command::QueueMessage`, `Command::ModerateCommunityMember`, or `participant_for_community_member` branches.
4. Historical Product-Rust diagnostic evidence already exposed the same later-M6 moderation failure before the final FMT-001 closeout head; FMT-001 itself is format-only.

Therefore the failure is **not a P0-001 semantic regression** and **not a formatter regression**.

## 3. Deterministic state-machine path

On exact `ecf79c8...` the behavior is internally deterministic:

1. `participant_for_community_member` returns `None` for `MemberStatus::Left | MemberStatus::Banned`.
2. `Command::ModerateCommunityMember` updates the Community member, then projects the member into the Group/Channel Conversation. Because the banned member maps to `None`, it emits `Event::ConversationParticipantRemoved { conversation_id, actor_id }` after `Event::CommunityChanged`.
3. `MessagingEngine::execute` calls `decide`, then synchronously applies every returned event before returning to the caller. Thus the following `QueueMessage` sees the banned actor already absent from `conversation.participants`.
4. `Command::QueueMessage` first checks active Conversation participation. For a non-owner actor absent from `conversation.participants`, it returns `EngineError::SenderNotParticipant { conversation_id, actor_id }`.
5. Only **after** that participation guard does `QueueMessage` inspect Community member status and potentially return `EngineError::CommunitySendRestricted(...)` for `Left | Banned` or send restrictions.

For the test's `human:member`, the canonical ban projection therefore makes the later Community-specific error branch unreachable. The current test expectation conflicts with the current active-participant projection and error precedence.

## 4. Root-cause classification

| Candidate | Verdict | Evidence |
|---|---|---|
| P0-001 introduced regression | **REJECTED** | failing test and relevant send/moderation/projection branches pre-exist on `9e88a2e...` and are not changed by the relevant #2323 diff |
| Parent-branch latent defect | **CONFIRMED — origin** | base already contains the contradictory test expectation and implementation ordering |
| Test/fixture vs state-machine contract mismatch | **CONFIRMED — mechanism** | ban removes active Conversation participation, while the test expects the later Community restriction error instead of the earlier participation error |
| CI/environment issue | **REJECTED** | deterministic in-memory branch ordering; exact source/merge ref checked; adjacent full-suite tests pass; same semantic failure was previously exposed after formatter was cleared |

Precise classification: **parent-branch pre-existing latent semantic-contract contradiction, expressed as a test expectation that is inconsistent with the current single-authority member projection and error precedence**.

## 5. Open-source-first investigation

No upstream implementation code is copied, translated, ported, or adapted. Only public architectural/test boundary principles are considered.

| Candidate | Exact revision / material read | Architecture & boundary observation | Tests/security relevance | License / compatibility | Decision |
|---|---|---|---|---|---|
| TDLib | `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f`; `td/telegram/DialogParticipant.cpp`; `DialogParticipantManager.cpp`; `LICENSE_1_0.txt` | banned/left are explicit participant-status states rather than merely a send-permission bit; participant lookup also has explicit `USER_NOT_PARTICIPANT` handling | supports separating membership eligibility from message-level restrictions and slow-mode concerns | Boost Software License 1.0; C++ client/library model differs from Fabushi's Rust local state machine | **BORROW principle only**; do not copy code |
| Continuwuity | `continuwuity/continuwuity@37d4cc5a3806e0f2c95b22b73d8749c06ce92167`; `src/api/client/membership/kick.rs`; state/auth sources; `LICENSE` | a kick verifies current membership and emits `MembershipState::Leave`; membership transitions are explicit room-state events | fail-closed authorization around membership; event-driven membership truth resembles Fabushi's projection boundary | Apache-2.0; Rust/server implementation is closer technically, but Matrix semantics are not Fabushi semantics | **BORROW invariant/test shape only**; no direct reuse |
| Element Synapse | `element-hq/synapse@a0b5a45c918a765e90a87873ac25e83b857509a1`; `synapse/event_auth.py`; membership handlers/tests; `LICENSE-AGPL-3.0`, `LICENSE-COMMERCIAL` | `LEAVE` and `BAN` are explicit membership states with membership-aware authorization | mature negative authorization and membership transition testing | AGPL-3.0 or commercial; Python/Rust hybrid and server architecture mismatch | **REJECT code reuse**; architecture/test reference only |

Open-source conclusion: mature chat systems reinforce the distinction between **active membership** and **in-room capability restrictions**. That supports preserving Fabushi's `Banned/Left -> no active Conversation participant` invariant instead of keeping a banned actor active solely to obtain a more specific send error.

## 6. Architecture decision

The smallest correct repair is **test-contract alignment, not production state-machine modification**:

- keep `MemberStatus::Banned` removed from active `Conversation.participants`;
- keep `QueueMessage` participation validation ahead of Community send-policy/restriction validation;
- repair the pre-existing post-ban assertion to the active-participation contract;
- add direct state assertions so the regression proves both Community truth (`Banned`) and Conversation projection truth (actor absent) before asserting the send failure;
- preserve the existing slow-mode, topic, admin-log, P0-001 and other moderation coverage.

Changing production error ordering or retaining a banned actor as an active participant merely to satisfy the old assertion is rejected: it would expand semantic scope, weaken the single-authority projection invariant, and risk turning an error-label mismatch into a real membership-security change.

## 7. Validation and escalation

No further diagnostic experiment is required before planning because the source path is deterministic. The minimum validating experiment is the execution of `TFI-M6-P0-001-MOD-001`: a one-test-file contract repair followed by the existing GitHub Actions.

Acceptance requires the Product Rust job to progress past `cargo test --all-targets` and then actually execute and pass the previously skipped clippy/media/bridge gates. Mahayana, Product Electron and Atomic must also pass on the same new exact execution head. No workflow edits, skipped checks, manual local build/test, or PASS substitution are permitted.

If GitHub Actions contradicts the predicted `SenderNotParticipant` contract, or if satisfying the test would require production/API changes, execution must stop as `ARCHITECTURE-BLOCKED` and hand the exact run/job/log back to architecture. It must not improvise an `engine.rs` repair.

## 8. Architecture-session scope

This planning round modifies records only under `projects/telegram-fabushi-integration/**`. It does not modify application source, test source, workflow, root `AGENTS.md`, `projects/PORTFOLIO.json`, Project ID, #2328, merge state, packaged E2E, test release, or formal release; and it runs no local build/test.
