# TFI-M6-P0-001-CLIPPY-001 execution — 2026-09-05

## Authority and frozen start
- Project: `FAB-P0001 / TFI`; parent `TFI-M6-P0-001`.
- Architecture authority: PR #2332 exact head `abf740153ef6ee5962c6da24f67b68a8b7f26f63`, task `TFI-M6-P0-001-CLIPPY-001-repair-production-clippy-gate.md`, handoff comment #2323 `5545043051`.
- Execution PR: #2323; frozen start `373bc52ad1cc2052c32acd81be4606c0a18dd89b`; base `9e88a2e9c030fe05147460dfa580366cf9aa433d`.
- Production cleanup commit: `90d337e8d04ce8c463c7228cac1053158f8268ed`.

## Exact implementation
1. `native/mahayana-messaging/src/engine.rs:595-600,622-628` — removed only private `CommunityAdminAction::PostMessages` and its `require_community_admin` mapping arm. `AdminRights.post_messages` and the direct Channel send check `member.admin_rights.post_messages` remain live and unchanged.
2. `native/mahayana-messaging/src/service.rs:680-694` — rewrote only the Community-backed `RemoveConversationParticipant` nested conditional as a match-arm guard. The lookup remains `community.members.get(target_actor_id)`; protected statuses remain `MemberStatus::Owner | MemberStatus::Administrator`; the owner bypass remains `!caller_is_owner`; denial remains exactly `admins cannot remove owner/admin members`.

No tests, workflows, manifests, locks, toolchains, dependencies, lint settings, other production files, AGENTS/PORTFOLIO, project identity, or historical R1/R2/R3/FMT/MOD/UNREAD records were changed.

## Open-source-first / official lint basis
- Rust compiler `dead_code`: https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html#dead-code — remove genuinely unused private code rather than hiding it when no lifecycle/exposure reason exists.
- Clippy `collapsible_match`: https://rust-lang.github.io/rust-clippy/master/index.html#collapsible_match — collapse equivalent nested pattern control flow without adding behavior.
- Clippy CI: https://doc.rust-lang.org/clippy/continuous_integration/index.html — retain `-D warnings`; no suppression or workflow weakening.
- Architecture open-source-first evidence additionally reviewed TDLib, matrix-rust-sdk and Telegram Desktop conceptually; no upstream implementation code was copied or imported.

## Validation plan and stop rules
No local build/test/E2E/native/app validation is permitted or performed. GitHub Actions on one exact final #2323 head must prove Mahayana fast; Product Rust rustfmt; all-targets tests; unread 4/4; M6 5/5; messaging Clippy; downstream media test; media Clippy; production Feature Host bridge/contact projection; Product Electron; TFI Atomic; Developer Fiat Commerce; Explicit automerge; and every other required PR-head check.

STOP without scope expansion on any semantic regression, third deterministic repository failure, third production file requirement, or any test/workflow/config/dependency/toolchain/lint change requirement. Infrastructure-only failures may be retried under normal CI policy. Review/merge/E2E/release/P0-002+ are not authorized here.

State at record write: `IMPLEMENTED / EXACT-HEAD-CI-PENDING / CLOSURE-BLOCKED`.

## Exact-head CI iteration 1
- Head `dc3913b5edac818052dc1031822695634abded0c` triggered Mahayana fast run `33908703028`, job `101139744051`.
- The job failed only at `cargo fmt --all -- --check`; Actions supplied one in-scope formatting diff in `service.rs` splitting `}) && !caller_is_owner =>` across two lines. No semantic/code-scope expansion was indicated.
- Applied that exact rustfmt layout in follow-up commit `0899258257e2efb8c24bb7fa951f4ae6180bbb10`; no local rustfmt/build/test was run.
- State remains `IMPLEMENTED / EXACT-HEAD-CI-PENDING / CLOSURE-BLOCKED` until the new final head completes required Actions.
