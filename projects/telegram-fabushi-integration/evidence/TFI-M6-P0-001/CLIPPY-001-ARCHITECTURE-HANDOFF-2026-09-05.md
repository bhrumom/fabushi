# CLIPPY-001 architecture handoff — 2026-09-05

## Frozen authority
- Task: `TFI-M6-P0-001-CLIPPY-001`.
- Task path: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-001-CLIPPY-001-repair-production-clippy-gate.md`.
- Frozen execution start: #2323 exact head `373bc52ad1cc2052c32acd81be4606c0a18dd89b`, base `9e88a2e9c030fe05147460dfa580366cf9aa433d`.
- Root cause: two parent/base-latent historical production-source lint blockers; not UNREAD/MOD/FMT semantics and not CI flake.

## Allowed
1. `native/mahayana-messaging/src/engine.rs`: remove only private `CommunityAdminAction::PostMessages` and its `require_community_admin` mapping arm. Preserve `AdminRights.post_messages` and the direct send permission check.
2. `native/mahayana-messaging/src/service.rs`: rewrite only the Community-backed `RemoveConversationParticipant` nested condition into an equivalent Clippy-clean guard/form. Preserve target statuses, caller-owner condition and exact denial.
3. append-only TFI execution/evidence records.

## Forbidden
Every other production/test file, workflows, lint/toolchain/dependency config, manifests/lockfiles, AGENTS/PORTFOLIO/Project identity, historical R1/R2/R3/FMT/MOD/UNREAD/#2330/#2331 records, and any review/merge/E2E/release/P0-002+ work.

Never silence the lint with `allow/expect`, dummy construction, public visibility, or workflow weakening.

## Required Actions proof
On one exact final execution head:
- Mahayana fast PASS;
- Product Rust rustfmt PASS;
- `cargo test --all-targets` PASS;
- unread projection 4/4 PASS;
- M6 contract 5/5 PASS;
- messaging Clippy PASS;
- media test PASS;
- media Clippy PASS;
- production Feature Host bridge/contact projection PASS and actually executed;
- Product Electron PASS;
- TFI Atomic PASS;
- all other required PR-head checks PASS.

## Stop rule
Same target lint may be corrected only inside its exact frozen source range. Any test failure, authorization behavior change, new deterministic repository failure, third-file requirement, workflow/config/test requirement or other scope expansion requires STOP and architecture return. Infrastructure-only failure is recorded separately.

Only after every required check is green may a fresh independent exact-head review be requested. No merge/E2E/release is authorized by this handoff.