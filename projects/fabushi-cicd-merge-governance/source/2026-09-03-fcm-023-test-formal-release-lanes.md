# FCM-023 — Split fast test releases from formal releases

## Latest explicit user requirement

1. Long-running E2E and tests that operate the real packaged application must not run automatically on every PR, every main push, or every release attempt.
2. Disable the existing umbrella/RC fan-out that automatically dispatches many platform workflows and long E2E jobs.
3. Split publishing into one manually selectable GitHub Actions workflow per product platform: macOS, Windows, Linux, Android, and iOS.
4. Every platform release workflow must distinguish `test` and `formal` release kinds.
5. `test` releases optimize for time-to-artifact: build/package only the requested platform, reuse caches, skip long UI/App E2E, and publish/download a clearly marked test artifact or prerelease.
6. `formal` releases remain the strict path: platform-appropriate E2E is required, together with signing/notarization/store/release gates as applicable.
7. Current execution scope is macOS test release only. Do not build or publish Windows/Linux/Android/iOS in this round.
8. Existing inaccurate application-driving E2E must remain disabled from automatic gates until it is recalibrated against an actual test build.

## Supersession

This requirement supersedes the earlier FCM-009 interpretation that packaged App E2E must run automatically for every canonical-main SHA and before every release attempt. Required E2E moves to explicit `formal` release workflows. Fast PR/main quality checks remain, but they must not launch long simulated-user application journeys by default.

## Open-source-first notes

- GitHub Actions `workflow_dispatch` is the canonical manual release trigger and supports typed inputs/choices, which maps directly to `release_kind=test|formal` and per-platform workflows.
- Electron Builder already supports platform-specific packaging (`--mac`, `--win`, `--linux`) and `--publish never`; reuse these existing package boundaries rather than a five-platform matrix.
- Existing Fabushi source-hash Host caches, Rust caches, npm caches, ASR staging, and Computer Use staging are retained so test releases remain deterministic but fast.

## Acceptance

- Automatic PR/main workflows contain no long Playwright/packaged App journey, iOS UI test, or umbrella release-candidate fan-out.
- Five platform-specific manual release workflow entry points exist.
- Test release skips long E2E; formal release enables it explicitly.
- macOS test workflow can produce a Mac-only installable artifact from the selected ref without waiting for other platforms.
