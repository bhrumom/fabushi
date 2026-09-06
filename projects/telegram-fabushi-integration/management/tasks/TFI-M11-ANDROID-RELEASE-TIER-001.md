# TFI-M11-ANDROID-RELEASE-TIER-001 — Android GitHub test release must not require iOS gates

- Project: `FAB-P0001 / TFI`
- Status: `IN_PROGRESS`
- Updated: 2026-09-06
- Baseline: `main@8a337c3bd7395603d1161c9c348783b936ae5b2b`
- Parent: `TFI-M11-ANDROID-INTERACTIVE-001`

## Reproduced failure

The Android App-owned transport merged in #2397 and version 1.2.36 merged in #2398. The exact-main Android job in Native mobile run `34015566753` completed successfully, but the workflow's iOS job remained necessary only because `Native Android GitHub release` omitted `RELEASE_TIER`. The shared `require-release-source-gates.sh` therefore defaulted to `formal`, for which Android requires `CI result + Native mobile result`.

The previous exact-main run `34015336931` demonstrates the concrete failure mode: Android passed while iOS UI test `testMiniAppOpensAndClosesDedicatedWebMcpSurface` failed waiting for `app-shell`. That iOS-only product failure blocks an Android GitHub test APK despite the repository already having a separate formal Google Play delivery workflow.

macOS test release is the canonical precedent: it explicitly sets `RELEASE_TIER=test`, for which the shared source gate requires exact-SHA `CI result` only.

## Requirement

`Native Android GitHub release` is the signed self-updating **test** APK channel and must explicitly set `RELEASE_TIER=test` while retaining `RELEASE_TARGET=android`, protected-main ancestry checks, immutable tag/release guards, signing, checksum verification and exact-source checkout. Google Play formal delivery is unchanged.

## Acceptance

1. `.github/workflows/native-android-release.yml` sets `RELEASE_TIER: test` in the canonical source-gate step.
2. Release summary and GitHub Release notes describe the exact-source CI test-tier requirement, not the formal `Native mobile result` aggregate.
3. Android fast contract tests assert the tier and source-gate invocation.
4. The existing Android App-owned PR gate watches `native-android-release.yml` and runs the contract plus Kotlin compile in GitHub Actions.
5. Protected merge queue remains mandatory; no bypass.
6. After merge, repository version increments again before publishing the next Android test candidate.
