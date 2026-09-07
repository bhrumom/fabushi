# UNREAD-001 architecture handoff — 2026-09-05

## Frozen authority
- Task: `TFI-M6-P0-001-UNREAD-001`.
- Task path: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-001-UNREAD-001-align-group-management-fixture-with-community-authority.md`.
- Start execution only from #2323 exact head `553c5efd5a6119298d0a0da8512a1ac931fcc61c` unless architecture explicitly revalidates a later records-only descendant.
- Root cause: `PARENT-BASE-LATENT / STALE-FIXTURE-STATE-MACHINE-CONTRACT-MISMATCH`.

## Allowed
Only `native/mahayana-messaging/tests/unread_projection_contract.rs::conversation_management_enforces_owner_admin_boundaries_and_removal` plus task-scoped TFI execution records. Establish Community through existing public `UpdateCommunity`; preserve Community as canonical Group membership authority and original owner/admin/removal semantics.

## Forbidden
Production source, other tests, workflows, manifests/dependencies, AGENTS/PORTFOLIO, prior R1/R2/R3/FMT/MOD/#2330 records, merge/E2E/release/P0-002+.

## Required Actions proof
One exact head must have required Mahayana fast and all PR checks green. Messaging Product Rust must pass rustfmt, full `cargo test --all-targets`, messaging clippy, media test/clippy, and production Feature Host bridge/contact projection; MOD M6 binary remains 5/5; Product Electron and TFI atomic pass.

## Stop rule
If the frozen test cannot be fixed solely by establishing a valid Community fixture through existing public commands, or if another deterministic semantic failure appears after Product Rust advances, stop and return architecture. Never patch production behavior or another test opportunistically.

No review, merge, packaged E2E, test/formal Release or P0-002+ is authorized by this handoff.
