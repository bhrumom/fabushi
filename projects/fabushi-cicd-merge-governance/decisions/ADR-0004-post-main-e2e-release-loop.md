# ADR-0004 — Post-main E2E-gated Release with incremental caches

- Status: accepted-for-implementation
- Date: 2026-08-24
- Project: FAB-P0003 / FCM
- Task: FCM-009

## Context

Fabushi already has platform quality workflows, package/E2E jobs, GitHub Release packaging and Electron `electron-updater`, but they are not yet one mandatory per-merged-PR delivery transaction. GitHub-hosted runners are ephemeral, so restarting a runner cannot literally hot-reload a previous process. Fast feedback must therefore come from content-addressed dependency/compiler/build caches plus same-run artifact handoff.

A second problem is update identity: publishing a new binary under the same Electron semantic version does not create an update that an installed client can reliably order above its current version.

## Decision

1. Every accepted `main` SHA gets a post-main delivery transaction.
2. Desktop/native platform build and E2E may execute in parallel and aggressively restore immutable/content-addressed caches.
3. Publication is serialized and only occurs after all required E2E for that exact SHA are successful.
4. Release artifacts are never reconstructed from unrelated runs; updater metadata and package binaries must come from the same accepted build lineage.
5. Electron versions for automatic main delivery are monotonic SemVer values. A main delivery run derives a version higher than the last accepted desktop Release and injects it at package time without rewriting Git history merely to bump a version file.
6. GitHub Release is the desktop updater source. `electron-updater` remains the client implementation.
7. Required macOS updater assets are DMG, ZIP, `latest-mac.yml`, and blockmap; signing/notarization remains mandatory.
8. Compiler/build acceleration uses existing source-hash binary caches, npm/Gradle/Xcode caches and adds compiler-result caching (`sccache`) where it reduces small-change recompilation without weakening reproducibility.
9. A cache miss always falls back to a normal correct build. Release provenance is the exact source SHA + workflow evidence, not cache identity.
10. Task startup includes an open-source survey; mature solutions are reused/adapted when licensing/security/maintenance fit the repository.

## Consequences

### Positive

- Every merged task is tested as a user would experience the built app, not only as source code.
- Failed main E2E cannot silently become an update.
- Existing users receive a strictly newer version through the existing in-app update UX.
- Warm builds avoid repeated Rust/JNI/staticlib/renderer work where inputs are unchanged.
- Open-source-first review reduces duplicated infrastructure.

### Costs / tradeoffs

- Every merge consumes post-main CI capacity.
- Signed/notarized release publication is slower than source CI, even with warm caches.
- Publication must protect against out-of-order completion when multiple main SHAs build concurrently.
- Cache telemetry and eviction policy become operational concerns.

## Rejected alternatives

- **Build everything from zero on every merge:** correct but violates feedback-time goal and wastes hosted-runner capacity.
- **Publish before E2E:** faster apparent delivery but can update users to a broken build.
- **Use commit SHA as Electron version:** not a SemVer ordering solution for `electron-updater`.
- **Invent a Fabushi-specific updater protocol:** unnecessary; mature electron-builder/electron-updater GitHub provider already solves metadata/download/signature integration.
- **Persistent self-hosted runner as the only speed strategy:** excluded by existing project constraints; cross-run caches must work on ephemeral GitHub-hosted runners.
