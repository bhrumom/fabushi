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
