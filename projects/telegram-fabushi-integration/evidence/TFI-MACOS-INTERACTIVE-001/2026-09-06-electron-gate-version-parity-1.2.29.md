# TFI-MACOS-INTERACTIVE-001 — restored Electron gate exposed canonical version drift

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Status: `TESTING`
- Restored-gate main SHA: `31ac7659b85cce27d31dfa7dcc54537c26e8e15e`
- Electron main run: `33999314440`
- Failing Linux job: `101395223837`

## Live reconciliation

At the start of this continuation, live GitHub no longer matched the stale handoff: PR #2381 was already merged as `main@36868f9c5ba389c6b627f93f792ce9a7d52192e3`, and immutable prerelease `v1.2.28` already existed from that SHA. Its merge title carried `[automerge-force]`; this continuation does not repeat or rely on that bypass path.

The canonical `.github/workflows/electron-desktop.yml` on that main was still reduced to the 2026-09-05 manual paused stub. PR #2382 restored the workflow byte-for-byte to pre-pause blob `a0a5f8f7ec94f182f3ff9e83d8d2d48f7a1cef28` and entered the repository's protected merge queue without an `automerge-force` title. It merged as `main@31ac7659b85cce27d31dfa7dcc54537c26e8e15e`.

`v1.2.28` therefore remains a published artifact, but it is not a valid post-restoration acceptance candidate for this resumed loop: it was merged and published while the canonical Electron quality gate was paused. The next comparable macOS test package must be strictly newer.

## Restored-gate failure

The restored push-triggered Electron gate immediately exercised `main@31ac7659…`. Linux job `101395223837` failed before dependency installation in `bash .github/scripts/assert-native-electron-canonical.sh` with:

`version drift: canonical=1.2.28 values={'desktop/package-lock.json': '1.2.22', 'mobile/package.json': '1.2.22', 'mobile/package-lock.json': '1.2.22'}`

The canonical assertion also requires iOS `MARKETING_VERSION` to equal `app-version.json`; live `mobile/ios/project.yml` still declared `1.2.22`, so fixing only the first reported map would expose the next deterministic parity failure.

## Atomic repair

Branch `fix/tfi-macos-version-parity-1-2-29-20260906` stages strictly newer comparable macOS test version `1.2.29` and synchronizes only canonical semantic-version metadata/guards:

- `app-version.json` -> `1.2.29`;
- desktop package and lock root versions -> `1.2.29`;
- native-mobile package and lock root versions -> `1.2.29`;
- iOS `MARKETING_VERSION` -> `1.2.29`;
- macOS release-control exact-version guards -> `1.2.29`.

Android version code `29` and iOS build number `29` remain unchanged. No product behavior, branch protection, quality assertion, account/session model, gateway ownership, or test coverage is weakened.

The repair must pass the restored real Electron PR gate, protected main merge, and then produce only a new immutable `v1.2.29` macOS test release. Full App-owned interactive acceptance may start only from that newest release, with native recording already active before installation.
