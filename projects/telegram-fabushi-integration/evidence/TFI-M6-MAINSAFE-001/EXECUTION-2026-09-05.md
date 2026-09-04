# TFI-M6-MAINSAFE-001 execution evidence — 2026-09-05

## Identity
- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-RUST-CANONICAL`
- Canonical base: `688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Architecture PR/head: `#2335@5c88dd6fb577752ccf15c64ed6287c219bfcd13d`
- Test-release blocker PR/head: `#2334@b8acbb61292f05ab5addccb59d78ab8dd1d56631`
- Historical stacked implementation: `#2323@1c314ef514f71e5a1320ddea0803078923a4858c`, base `9e88a2e9c030fe05147460dfa580366cf9aa433d`; read-only provenance only.

## Reconstruction evidence
- Fresh branch parent: exact canonical main `688465e...`.
- Parent Rust reconstruction commit: `1684cd2d561f1c5c9899cdafde18e35a9f01a00c`.
- Historical parent Rust-subset stable patch-id: `6baf52d50ff641f874a9f2ad34dd44bcaf21ca14`.
- Reconstruction commit stable patch-id: `6baf52d50ff641f874a9f2ad34dd44bcaf21ca14`.
- Continuity commit: `eb0891a9bb67daae334da322770084097e5e733c`.
- Historical records checkpoints and all Electron files were excluded from product reconstruction.
- Historical child P0 create/join commits and temporary atomic workflow were excluded.

## Static scope evidence
Before push, changed product/test files are restricted to the frozen seven-file allowlist. `git diff --check` is clean. No `.rej` artifact remains. Searches confirm the CLIPPY private selector is absent while `post_messages` policy fields/live Channel authorization remain. MOD and UNREAD focused assertions are present.

## PR-head Actions
Pending at initial evidence creation. Exact run/job IDs and conclusions will be written into the product PR handoff after GitHub Actions completes; old #2323 green runs are historical context only and are not reused as acceptance evidence.

## Current classification
`EXECUTION-IN-PROGRESS / PR-HEAD-CI-PENDING / REVIEW-NOT-STARTED / MERGE-NOT-STARTED`.

## PR-head Actions round 1 — formatter-only failure
PR `#2336` initial exact head `219c3e7b91729d64cb684b304f381831501e01f2` triggered fresh Actions. Mahayana fast checks run `33914142883`, job `101157283662` (`Rust protocol, Host, and bridge fast gate`) failed only at step `Verify formatting before native package setup` (`cargo fmt --all -- --check`) before compilation/tests. The emitted diff was a single `engine.rs` layout change around the join participant projection. This is within the frozen FMT/Rust allowlist and does not change behavior. The exact Actions-emitted layout is applied in the next commit; no local rustfmt/build/test is used.

## PR-head Actions round 2 — deterministic Rust compile correction
Exact head `d105944ede3fdc1645f600e7c80a52196ce7e576` ran Messaging Product Gate `33914266967`. Electron Messenger contract job `101157672909` passed. Rust self-hosted product job `101157672509` passed rustfmt, then failed `cargo test --all-targets` at `engine.rs` join participant projection with E0308 because the partially replayed formatter form parsed as `bool && Option<Event>`. This is not a behavioral test regression and does not require scope expansion. The historical reviewed FMT source `d2f97c0c22411a49ef926c0bb9c049be18348b10` and old final Rust source both contain the correct `if approved && condition { Some/Event } else { None }` form. That exact reviewed form is restored. This is the second deterministic repair round; any third deterministic Rust failure is a frozen stop condition for this execution session.
