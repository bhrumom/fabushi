# FCM-008 — Build latest macOS package

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-008
- **Status:** in-progress
- **Started:** 2026-08-23
- **Updated:** 2026-08-23

## Objective

Build the latest canonical Fabushi macOS Electron package from GitHub `main` and provide a downloadable package that passes macOS Gatekeeper distribution checks.

## Source requirements

1. User request: “构建最新的mac版本，把下载链接给我”。
2. Post-delivery defect report: “安装后无法打开显示已经损坏”。

## Canonical product source

- `main`: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`.
- Electron app version: `1.0.2`.
- Target architecture: macOS arm64.

## Reopened defect evidence

The first prerelease package was built successfully but was not a valid external macOS distribution package. Direct inspection of the downloaded DMG on the target Mac found:

- app signature: `Signature=adhoc`, `TeamIdentifier=not set`;
- mounted app Gatekeeper assessment: rejected (`code has no resources but signature indicates they must be present`);
- DMG Gatekeeper assessment: rejected (`source=no usable signature`).

Root cause: the one-shot package workflow set `CSC_IDENTITY_AUTO_DISCOVERY=false`, so electron-builder created an ad-hoc app and unsigned DMG. The original prerelease is now explicitly labeled `BROKEN - DO NOT USE`.

## Replacement execution

### Signed attempt 1

- GitHub Actions run: `32620573441`.
- Developer ID certificate import: passed.
- Packaging: failed because electron-builder rejected the full `Developer ID Application:` prefix supplied through `CSC_NAME`.
- No release published.

### Signed attempt 2

- GitHub Actions run: `32620676480` — **success**.
- Exact source SHA asserted before build.
- Developer ID Application identity imported into an ephemeral runner keychain.
- Electron hardened-runtime signing: success.
- `codesign --verify --deep --strict`: success.
- Apple notarization: `Accepted`.
- DMG stapling: success.
- CI DMG Gatekeeper assessment: accepted.
- CI mounted-app Gatekeeper assessment: accepted.

## Replacement release

- Tag: `macos-main-67b70fff-20260823-signed`.
- Release: `Fabushi macOS signed notarized main 67b70fff`.
- Target commit: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`.
- Prerelease: yes.
- DMG: `Fabushi-1.0.2-arm64-signed-notarized.dmg` — 142,773,348 bytes.
- SHA256: `d3c76e3227ab6ad461bb70cc491c9e044bdb00a8f5ff2473006c7a71c949247c`.
- Download: `https://github.com/bhrumom/fabushi/releases/download/macos-main-67b70fff-20260823-signed/Fabushi-1.0.2-arm64-signed-notarized.dmg`.

## Target-Mac verification

The exact release asset was downloaded again on the user's Apple Silicon Mac.

- File size matched Release metadata exactly.
- Local SHA256 matched the published checksum exactly.
- `xcrun stapler validate`: passed.
- DMG `spctl`: `accepted`, `source=Notarized Developer ID`.
- Mounted app identifier: `com.ombhrum.fabushi`.
- Developer ID authority: `Guangxi Dixi Artificial Intelligence Application Software Co., Ltd (M4Q99K4UR4)`.
- `TeamIdentifier=M4Q99K4UR4`.
- Mounted app `codesign --verify --deep --strict`: passed.
- Mounted app `spctl`: `accepted`, `source=Notarized Developer ID`.
- Direct launch from the mounted DMG succeeded; the `fabushi` process was observed running.

The target Mac currently has approximately `764 MiB` free on its data volume. A temporary copy-install simulation hit `No space left on device`; the temporary test copy was removed. This is a separate storage-capacity constraint, not a signing/notarization defect.

## Permanent release-path remediation

Task-branch commit `da337309651dd61bad484e5e8cb5b2e94f6a8d98` updates `.github/workflows/native-electron-release.yml` so the macOS release matrix target must:

1. import the configured Developer ID Application certificate;
2. enable real electron-builder signing;
3. notarize the DMG with the configured App Store Connect API key;
4. staple the notarization ticket;
5. require Gatekeeper `spctl` acceptance before uploading the artifact.

The one-shot repair workflow was removed from the branch after producing the verified replacement; only the permanent release-path fix and durable FCM records remain for merge.

## Acceptance criteria

1. Build source equals canonical `main@67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`. **Passed.**
2. App is signed by a valid Developer ID Application identity with Team ID. **Passed.**
3. Apple notarization finishes with `Accepted` and the DMG has a valid stapled ticket. **Passed.**
4. Gatekeeper accepts both final DMG and mounted app. **Passed in CI and on the target Mac.**
5. Final DMG is published and downloadable. **Passed.**
6. Permanent release workflow prevents recurrence. **Implemented on task branch; protected-main merge and post-merge verification pending.**

## Branch / PR

- Branch: `chore/fcm-008-build-latest-macos-20260823`.
- Permanent workflow patch commit: `da337309651dd61bad484e5e8cb5b2e94f6a8d98`.
- PR: pending creation.

## Current blocker / next action

No installer trust blocker remains. The remaining governance gate is to merge the permanent workflow fix and FCM evidence through protected `main`, re-read canonical main, then mark FCM-008 `passed` in a closure record.

## Evidence

See `../../evidence/FCM-008/README.md`.
