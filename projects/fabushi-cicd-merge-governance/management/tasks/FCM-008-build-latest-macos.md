# FCM-008 — Build latest macOS package

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-008
- **Status:** passed
- **Started:** 2026-08-23
- **Updated:** 2026-08-23
- **Completed:** 2026-08-23

## Objective

Build the latest canonical Fabushi macOS Electron package from GitHub `main`, provide a downloadable package that passes macOS Gatekeeper distribution checks, and permanently prevent unsigned/unnotarized macOS Release artifacts from being published by the canonical release workflow.

## Source requirements

1. User request: “构建最新的mac版本，把下载链接给我”。
2. Post-delivery defect report: “安装后无法打开显示已经损坏”。

## Product source and replacement release

- Product source used for the requested app build: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`.
- Electron app version: `1.0.2`.
- Target architecture: macOS arm64.
- Replacement release tag: `macos-main-67b70fff-20260823-signed`.
- Replacement DMG: `Fabushi-1.0.2-arm64-signed-notarized.dmg` — 142,773,348 bytes.
- SHA256: `d3c76e3227ab6ad461bb70cc491c9e044bdb00a8f5ff2473006c7a71c949247c`.
- Download: `https://github.com/bhrumom/fabushi/releases/download/macos-main-67b70fff-20260823-signed/Fabushi-1.0.2-arm64-signed-notarized.dmg`.

## Reopened defect evidence

The first prerelease was a successful build but not a valid external macOS distribution package. Direct inspection of the downloaded DMG on the target Mac found:

- app signature: `Signature=adhoc`, `TeamIdentifier=not set`;
- mounted app Gatekeeper assessment: rejected;
- DMG Gatekeeper assessment: rejected with `source=no usable signature`.

Root cause: the temporary package workflow disabled signing with `CSC_IDENTITY_AUTO_DISCOVERY=false`. The original prerelease is explicitly labeled `BROKEN - DO NOT USE`.

## Replacement execution

### Signed attempt 1

- GitHub Actions run: `32620573441`.
- Developer ID certificate import: passed.
- Packaging stopped because electron-builder rejected the full `Developer ID Application:` prefix supplied through `CSC_NAME`.
- No release was published.

### Signed attempt 2

- GitHub Actions run: `32620676480` — **success**.
- Exact product source SHA asserted before build.
- Developer ID Application identity imported into an ephemeral runner keychain.
- Electron hardened-runtime signing: success.
- `codesign --verify --deep --strict`: success.
- Apple notarization: `Accepted`.
- DMG stapling: success.
- CI DMG Gatekeeper assessment: accepted.
- CI mounted-app Gatekeeper assessment: accepted.

## Target-Mac verification

The exact replacement release asset was downloaded again on the user's Apple Silicon Mac.

- File size matched Release metadata exactly.
- Local SHA256 matched the published checksum exactly.
- `xcrun stapler validate`: passed.
- DMG `spctl`: `accepted`, `source=Notarized Developer ID`.
- Mounted app identifier: `com.ombhrum.fabushi`.
- Developer ID authority: `Guangxi Dixi Artificial Intelligence Application Software Co., Ltd (M4Q99K4UR4)`.
- `TeamIdentifier=M4Q99K4UR4`.
- Mounted app `codesign --verify --deep --strict`: passed.
- Mounted app `spctl`: `accepted`, `source=Notarized Developer ID`.
- Direct launch from the mounted DMG succeeded and the `fabushi` process was observed running.

The target Mac had approximately `764 MiB` free during verification. A temporary copy-install simulation hit `No space left on device`; the temporary test copy was removed. This is a separate storage-capacity constraint and did not affect the signing/notarization acceptance or direct app launch.

## Permanent release-path remediation

PR #2044, `[automerge-force] fix(release): require signed notarized macOS artifacts`, passed its required checks and merged into canonical `main` as:

- merge commit: `278678efad2917259f4b988ae2e7b65a30eb70ea`;
- merged at: 2026-08-23;
- required checks included `CI result`, `Delivery governance contract`, `Project portfolio governance`, `CI latency observability`, and `Previous-good release is immutable and retrievable`.

Canonical `main@278678efad2917259f4b988ae2e7b65a30eb70ea` was re-read after merge. `.github/workflows/native-electron-release.yml` now requires the macOS release matrix target to:

1. import the configured Developer ID Application certificate;
2. enable real electron-builder signing for macOS;
3. notarize the produced DMG with the configured App Store Connect API key;
4. staple and validate the notarization ticket;
5. require Gatekeeper `spctl` acceptance before artifact upload.

The temporary repair workflows were removed before #2044 landed; only the permanent release-path fix and durable FCM evidence were merged.

## Acceptance criteria

1. Requested product source was built exactly from canonical source. **Passed.**
2. App is signed by a valid Developer ID Application identity with Team ID. **Passed.**
3. Apple notarization finishes with `Accepted` and DMG has a valid stapled ticket. **Passed.**
4. Gatekeeper accepts both final DMG and mounted app. **Passed in CI and on the target Mac.**
5. Final DMG is published, checksummed, and downloadable. **Passed.**
6. Permanent release workflow prevents recurrence. **Passed; merged via #2044 and re-read from canonical `main@278678efad2917259f4b988ae2e7b65a30eb70ea`.**

## Branch / PR evidence

- Implementation/repair branch: `chore/fcm-008-build-latest-macos-20260823`.
- Permanent workflow patch commit on branch: `da337309651dd61bad484e5e8cb5b2e94f6a8d98`.
- Protected repair PR: #2044.
- Canonical merge commit: `278678efad2917259f4b988ae2e7b65a30eb70ea`.
- Closure branch: `chore/fcm-008-final-closure-20260823`.

## Blockers / next action

- Installer trust blocker: none.
- FCM-008 required engineering acceptance: complete.
- Separate FAB-P0001 Messenger E2E regressions discovered during the initial quality-gate run remain product work and are not hidden or reclassified by this task.

## Evidence

See `../../evidence/FCM-008/README.md`.
