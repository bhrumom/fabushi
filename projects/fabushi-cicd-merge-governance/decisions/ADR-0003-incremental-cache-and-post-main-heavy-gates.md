# ADR-0003 — Incremental cache + post-main heavy gates

- **Status:** Accepted
- **Date:** 2026-08-23
- **Owners:** Fabushi maintainers

## Context

GitHub-hosted runners are ephemeral, so they cannot literally retain a mutable build workspace between runs. Fabushi nevertheless needs near-hot-update behavior for repeated full-platform package builds, while PR feedback must remain fast.

## Decision

1. PR/merge validation is a fast safety lane: static/type/format/contract/necessary unit checks only. E2E, installer builds and Debug package builds are excluded from PR CI.
2. Heavy product validation moves to protected `main` push and runs only for impacted platforms/domains.
3. Cross-run incremental behavior is implemented with layered, content-addressed caches plus same-run artifacts:
   - dependency caches: npm/pnpm/Cargo registries/Gradle/SwiftPM where applicable;
   - compiler/build caches: Cargo target/sccache-compatible state, Gradle build cache, Xcode DerivedData where safe;
   - native outputs: Electron Host binaries, Android JNI libraries, iOS static libraries keyed by source/toolchain/platform;
   - emulator/device preparation cache where safe.
4. Cache keys include platform + architecture + explicit schema version + toolchain version + lockfile/config/source fingerprints. Restore fallbacks may be broader only for caches whose build tools independently validate inputs.
5. Cache miss always falls back to a reproducible clean build.
6. GitHub Release artifacts remain immutable delivery evidence; caches are accelerators, never release provenance.

## Consequences

- Warm builds should be substantially faster without self-hosted runners.
- A small change will not necessarily become instant: platform packaging/signing/E2E still have irreducible costs.
- Main merges trigger more expensive validation than PRs, so impact classification is mandatory to control cost.
- Cache poisoning/staleness becomes a Tier-3 delivery risk and requires governance tests plus explicit version bumps when cache schemas change.

## Alternatives rejected

- Self-hosted persistent runners: rejected by current project constraint.
- Persisting the entire previous workspace: too unsafe/stale and not portable across GitHub-hosted runners.
- Running full E2E/package builds on every PR: rejected for feedback latency.
- Skipping post-main E2E/package validation: rejected for main quality and release confidence.
