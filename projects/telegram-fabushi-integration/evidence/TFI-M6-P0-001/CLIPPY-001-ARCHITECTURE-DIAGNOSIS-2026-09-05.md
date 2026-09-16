# CLIPPY-001 architecture diagnosis evidence — 2026-09-05

## Frozen facts
- Repository: `bhrumom/fabushi`.
- Project: `FAB-P0001 / TFI`.
- Execution PR #2323: open/unmerged, base `9e88a2e9c030fe05147460dfa580366cf9aa433d`, exact diagnosed head `373bc52ad1cc2052c32acd81be4606c0a18dd89b`.
- Architecture PR #2331: open/unmerged, exact head `a5850f12ebef51a9862e8a466eb79f00af224491`; preserved as historical UNREAD authority, not reused for this round because it is based on the earlier execution head.
- UNREAD semantic commit: `7d158e1742b2d9e56d101c90d3d81408dcd41947`.
- UNREAD execution evidence commit: `02a0a261d138901a172804a68a47a8fdbe3c747a`.
- UNREAD evidence index commit/current head: `373bc52ad1cc2052c32acd81be4606c0a18dd89b`.
- Execution handoff comment read: #2323 comment `5544870977`.

## Input evidence path verification
The path `management/tasks/TFI-M6-P0-001-UNREAD-001-execution-2026-09-05.md` returns 404 at `373bc52...`. Commit `02a0a261...` adds only `evidence/TFI-M6-P0-001/UNREAD-001-EXECUTION-2026-09-05.md`; commit `373bc52...` adds only `UNREAD-001-EXECUTION-INDEX-2026-09-05.md`. The actual architecture task is on #2331 as `management/tasks/TFI-M6-P0-001-UNREAD-001-align-group-management-fixture-with-community-authority.md`.

## Execution and review continuity read
- FMT-001 execution evidence confirms formatter-only commit `d2f97c0c...` changed `engine.rs`, `service.rs` and `m6_channels_topics_contract.rs` by rustfmt only and exposed a later semantic test failure.
- Independent FMT reviewer PR #2329 head `02fd655b...` records `REVIEW-PASS(FMT-001 scope) / CI-BLOCKED / CLOSURE-BLOCKED`; review found no semantic change in the formatter slice.
- MOD-001 execution evidence confirms only its one target test changed; full M6 binary became 5/5 PASS and execution stopped when unread fixture failed. No fresh MOD code review was requested because required CI stayed red.
- UNREAD-001 then changed only `unread_projection_contract.rs::conversation_management_enforces_owner_admin_boundaries_and_removal`; production `engine.rs`/`service.rs` were outside scope and unchanged by UNREAD.

## Current Actions — exact head `373bc52...`
Messaging Product Gate `33905958987`:
- Electron job `101131173822`: SUCCESS.
- Rust job `101131173899`: FAILURE.
- `Rustfmt self-hosted messaging`: SUCCESS.
- `cargo test --manifest-path native/mahayana-messaging/Cargo.toml --all-targets`: SUCCESS.
- `unread_projection_contract`: 4/4 PASS.
- `m6_channels_topics_contract`: 5/5 PASS.
- `Clippy messaging library and server binaries`: FAILURE.
  1. `native/mahayana-messaging/src/engine.rs:597`: `CommunityAdminAction::PostMessages` never constructed; `-D dead-code` from `-D warnings`.
  2. `native/mahayana-messaging/src/service.rs:684`: `clippy::collapsible_match`; `-D warnings`.
- downstream media test, media Clippy and production Feature Host bridge/contact projection: SKIPPED.

Other exact-head truth:
- Mahayana `33905958879` / `101130884645`: SUCCESS.
- TFI M6 P0-001 Atomic `33905958904` / `101130939914`: SUCCESS.
- Developer Fiat Commerce `33905958905`: SUCCESS.
- Explicit automerge `33905958893`: SUCCESS.

## Reproduction on semantic head
Messaging Product run `33905736673`, Rust job `101130104184`, head `7d158e...`, reproduces rustfmt PASS → all-targets PASS → the exact same two Clippy errors. This precedes the UNREAD evidence/index record commits. The diagnostic is therefore deterministic repository source state, not evidence-writeback or a transient runner failure.

## Workflow/toolchain proof
`.github/workflows/messaging-product-gate.yml` installs stable Rust with `rustfmt,clippy` and executes:
`cargo clippy --manifest-path native/mahayana-messaging/Cargo.toml --all-targets -- -D warnings`.
Both reproductions use stable Rust `1.98.1`. `native/mahayana-messaging/Cargo.toml` is edition 2021, Apache-2.0 and has no local lint override that changes these diagnostics.

## Root cause 1 — engine dead private selector
Base `9e88a2e...` and current head both define private `CommunityAdminAction::PostMessages`, but the complete helper call set constructs only the other currently used action variants. Historical commit `6160971cb3c477b809ae470d60f1e3c601606329` added `PostMessages` and its mapping. No current generic helper caller uses it.

The domain permission itself is **not dead**: the real send path directly checks `member.admin_rights.post_messages`. Therefore deleting the `AdminRights` field or weakening send authorization would be wrong; so would dummy construction or lint suppression. Minimal repair is only the unused private selector variant plus its helper mapping arm.

## Root cause 2 — service nested management check
Base `9e88a2e...` already contains the same Community-backed inner match branch where `RemoveConversationParticipant` enters a nested `if` checking target Owner/Administrator and `!caller_is_owner`. Historical commit `af6fb35c30f9d64d6f731c8a0d1ebef959f95a73` introduced that authorization form when Community membership became canonical. #2323's relevant later delta is formatting, not semantic introduction.

Clippy reports that the condition can be collapsed into the outer match arm. A match guard can express the exact same predicate with no added/removed branch. Minimal repair must preserve target lookup, statuses, caller-owner condition and denial text.

## Final classification
1. engine lint: `PARENT-BASE-LATENT / HISTORICAL-DEAD-PRIVATE-SELECTOR / PRODUCTION-FIX-REQUIRED`.
2. service lint: `PARENT-BASE-LATENT / HISTORICAL-PRODUCTION-CONTROL-FLOW-LINT / SEMANTICS-PRESERVING-PRODUCTION-FIX-REQUIRED`.
3. FMT/MOD/UNREAD: `NOT-CAUSAL`; they only advanced the required job past earlier blockers.
4. test/fixture: `UNRELATED` to these two source warnings; current full tests pass.
5. CI/environment: `NOT-ROOT-CAUSE`; reproduced twice on exact heads/jobs.

Parent state remains `CI-BLOCKED / CLOSURE-BLOCKED`; architecture only freezes the next task and does not claim code completion or review.