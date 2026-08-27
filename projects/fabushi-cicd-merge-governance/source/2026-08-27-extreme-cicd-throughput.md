# 2026-08-27 — Extreme CI/CD throughput requirement

## User requirement

Complete a second-stage CI/CD optimization focused on extreme speed and extreme efficiency without weakening protected-main safety, merge-queue validation, packaged E2E, release provenance, signing/notarization, or exact-SHA delivery guarantees.

## Current evidence

- Canonical CI already classifies affected domains and aggregates them into `CI result`.
- Merge-group validation is retained and change-aware.
- Frontend Next.js cache, Worker Rust cache, Mahayana Cargo cache, native binary caches, Gradle/DerivedData/AVD caches, and sccache are already partially deployed.
- Recent PR evidence shows a single commit can fan out into many independent workflows, creating runner/setup overhead and contention.
- Electron PR currently installs npm dependencies before architecture/text guardrails, so cheap failures can waste dependency-install time.
- Native mobile PR currently uses recursive submodules and full history even though its PR fast path only requires repository files, base diff validation, Rust formatting, and manifest checks.

## Required outcome

1. Make cheap deterministic guards fail before expensive setup/install/compile work.
2. Make PR checkout as shallow and narrow as correctness permits; do not fetch recursive submodules on PR fast paths unless required.
3. Preserve full/canonical main build, package, device/simulator E2E, signing, notarization, and release gates.
4. Preserve fail-safe behavior for unknown paths and required aggregate `CI result`.
5. Measure real Actions results before calling the task passed.
6. Keep merge queue enabled; queue throughput tuning is separate from weakening test coverage.

## Open-source-first research

Reviewed canonical/proven CI primitives before implementation:

- GitHub Actions reusable workflows / `workflow_call`: use as the preferred mechanism when later consolidating duplicated PR workflow entry points without coupling product logic into one monolith.
- `actions/checkout`: use shallow fetch by default and fetch exact extra refs only when a diff requires them; avoid recursive submodules on PR paths that do not consume them.
- `mozilla/sccache`: keep compiler-result caching for Rust/C/C++ hot paths where compatible.
- `Swatinem/rust-cache`: retain dependency/target cache reuse with deterministic cold fallback.

This round prioritizes low-risk structural wins first; larger workflow consolidation is accepted only after measured evidence proves it reduces queue/setup cost without obscuring independent product gates.
