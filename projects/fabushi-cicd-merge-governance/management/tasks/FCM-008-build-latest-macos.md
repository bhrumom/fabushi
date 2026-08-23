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
- `spctl -a -vvv -t exec` on the mounted app: rejected (`code has no resources but signature indicates they must be present`);
- `spctl -a -vvv -t open --context context:primary-signature` on the DMG: rejected (`source=no usable signature`).

Root cause: the one-shot package workflow intentionally set `CSC_IDENTITY_AUTO_DISCOVERY=false`, so electron-builder created an unsigned/ad-hoc app and unsigned DMG. This violates the acceptance requirement for an installable end-user macOS package.

## Remediation

- Import the repository's configured Developer ID Application certificate into an ephemeral GitHub Actions keychain.
- Build with Electron hardened runtime and real Developer ID signing enabled.
- Verify the `.app` with `codesign --verify --deep --strict`.
- Sign the DMG, submit it to Apple notarization using the configured App Store Connect API key, wait for `Accepted`, and staple the ticket.
- Require `xcrun stapler validate` and Gatekeeper `spctl` acceptance before publishing.
- Publish a new immutable prerelease tag rather than mutating the rejected package.
- Mark the previous prerelease as broken/deprecated so it is not accidentally reused.

## Acceptance criteria

1. Build source equals canonical `main@67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`.
2. App is signed by a valid Developer ID Application identity (not ad-hoc; Team ID present).
3. Apple notarization finishes with `Accepted` and the DMG has a valid stapled ticket.
4. `spctl` accepts the final DMG as a primary-signature distribution image.
5. Final DMG is published on GitHub Release and downloadable.
6. The final DMG is re-downloaded/checked on the target Mac before FCM-008 returns to `passed`.

## Validation boundary

The earlier Messenger E2E regressions remain separate FAB-P0001/TFI product issues. FCM-008 is specifically reopened because the delivered installer itself failed macOS distribution trust checks.

## Evidence

See `../../evidence/FCM-008/README.md`.
