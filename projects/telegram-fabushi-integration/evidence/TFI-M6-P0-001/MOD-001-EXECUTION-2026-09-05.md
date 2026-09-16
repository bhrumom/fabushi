# TFI-M6-P0-001-MOD-001 execution evidence — 2026-09-05

- Task: `TFI-M6-P0-001-MOD-001`
- Architecture authority: PR #2330 exact head `9f03b5b1e4b823a226e60bf3c791d6d6301c5521`
- Execution PR: #2323; base `9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Starting head: `ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d`
- Semantic source commit: `a058b3adba5e20fccd19af06398cca19b8987074`
- Formatter-only follow-up: `460d08b380b1b9dca5bdab4d37c75f5cb83f1fc1`
- Source verification head: `460d08b380b1b9dca5bdab4d37c75f5cb83f1fc1`
- Classification: `NEW-SEMANTIC-FAILURE / EXECUTION-MOD-BLOCKED / CI-BLOCKED / CLOSURE-BLOCKED`

## Frozen source delta
Outside project records, exactly one file changed: `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`, and only `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine` was modified. No production source, other test, workflow, Cargo/dependency/lock/toolchain, Electron/mobile code, root `AGENTS.md`, or `projects/PORTFOLIO.json` was changed.

The test now directly proves after `ModerateCommunityMember(... Banned ...)` that `human:member` has `MemberStatus::Banned`, is absent from `group:m6` active `Conversation.participants`, and the next send fails with `EngineError::SenderNotParticipant { conversation_id: group:m6, actor_id: human:member }`. Existing slow-mode, topic/draft/read, and admin-log assertions remain.

## CI evidence on source verification head 460d08b3
First attempt `a058b3a...`: Mahayana fast checks run `33902616051`, job `101119986549`, failed only at rustfmt on the newly added `assert_eq!`; no semantic change was required. Commit `460d08b...` applied only rustfmt's requested line folding inside the same authorized test.

On `460d08b...`:
- TFI M6 P0-001 Atomic: run `33902885775`, job `101120859973` — **SUCCESS**; compile and focused regressions passed.
- Messaging Product Gate: run `33902885769` — **FAILURE**.
  - Electron Messenger contract job `101120860132` — **SUCCESS**.
  - Rust self-hosted product job `101120860382` — **FAILURE**.
  - `Rustfmt self-hosted messaging` — **SUCCESS**.
  - `cargo test --manifest-path native/mahayana-messaging/Cargo.toml --all-targets` compiled and ran the full suite. All five `m6_channels_topics_contract` tests passed, including `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine`.
  - The first deterministic failure was instead `tests/unread_projection_contract.rs::conversation_management_enforces_owner_admin_boundaries_and_removal`, panicking at line 25 after `unwrap()` received `Engine(CommunityNotFound(ConversationId("group:management-contract")))`.
  - downstream `Clippy messaging library and server binaries`, media test, media clippy, and production Feature Host bridge/contact projection steps were **SKIPPED** because the all-targets test step failed.
- Developer Fiat Commerce run `33902885756` — **SUCCESS**.
- Explicit automerge run `33902885785` — **SUCCESS**.
- Mahayana fast checks run `33902885757`, job `101120860421`: formatter and all observed prior steps passed; terminal conclusion is recorded in the final #2323 handoff once the existing run finishes.

## Stop-rule application
The authoritative MOD-001 task classifies a different deterministic Product Rust repository failure after the target contract advances as `NEW-SEMANTIC-FAILURE` and requires return to architecture. Fixing `unread_projection_contract.rs` would touch an explicitly forbidden other test file. Execution therefore stops without changing it and without attempting production-source changes.

No fresh independent review is requested because required CI is not all green. No MERGE-001, canonical-main merge, packaged E2E, test release, formal release, or P0-002+ work is started.
