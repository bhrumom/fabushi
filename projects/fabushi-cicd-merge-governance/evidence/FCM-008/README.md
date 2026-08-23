# FCM-008 evidence — latest macOS build

## Canonical source

- `main`: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`
- Electron app version: `1.0.2`
- macOS target: arm64

## Round 1 — canonical quality gate

- Workflow: `Electron desktop quality gate`
- Run: `32619314508`
- Exact source SHA: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`
- Architecture/bridge/login/BotMark/UI/native-capability checks: success.
- Real Electron Messenger smoke: failure.
- Package jobs: correctly skipped.

Separate FAB-P0001 Messenger blockers found by that run:

1. unique in-conversation search marker projected into two message `<article>` nodes;
2. forged renderer messaging envelope actor ID was not rebound/rejected at the desktop Host boundary.

No package from this failed gate is represented as accepted.

## Round 2 — build-only prerelease (later rejected)

- One-shot exact-source build: `32619653455` — success as a build.
- Direct GitHub prerelease build: `32619943578` — success as a build.
- Original prerelease tag: `macos-main-67b70fff-20260823`.

The user then reported that macOS showed the installed app as damaged. Direct inspection of the exact downloaded DMG on the target Mac proved the original release was not a valid external macOS distribution package:

- app `codesign -dv --verbose=4`: `Signature=adhoc`, `TeamIdentifier=not set`;
- mounted app Gatekeeper assessment: rejected (`code has no resources but signature indicates they must be present`);
- DMG Gatekeeper assessment: rejected, `source=no usable signature`.

Root cause: the one-shot build set `CSC_IDENTITY_AUTO_DISCOVERY=false`, so electron-builder emitted an ad-hoc/unsigned package. The old prerelease title/notes were updated to `BROKEN - DO NOT USE` and point users to the signed replacement.

## Round 3 — signed/notarized replacement build

### Attempt 1

- Run: `32620573441` — failed before packaging completion.
- Developer ID certificate import succeeded.
- Failure: electron-builder rejected a full `Developer ID Application:` identity string passed through `CSC_NAME` and requested that the prefix be removed/auto-selected.
- No release was published from this attempt.

### Attempt 2

- Run: `32620676480` — **success**.
- Product checkout: exact `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`.
- Developer ID Application certificate: imported into an ephemeral GitHub Actions keychain.
- Electron app signing: success with hardened runtime.
- Deep/strict code-signature validation: success.
- Apple notarization: `Accepted`.
- Stapler: success.
- DMG Gatekeeper assessment in CI: accepted.
- Mounted app Gatekeeper assessment in CI: accepted.

Replacement release:

- Tag: `macos-main-67b70fff-20260823-signed`.
- Title: `Fabushi macOS signed notarized main 67b70fff`.
- Target commit: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`.
- DMG: `Fabushi-1.0.2-arm64-signed-notarized.dmg` — 142,773,348 bytes.
- SHA256: `d3c76e3227ab6ad461bb70cc491c9e044bdb00a8f5ff2473006c7a71c949247c`.

Download entry point:

- `https://github.com/bhrumom/fabushi/releases/download/macos-main-67b70fff-20260823-signed/Fabushi-1.0.2-arm64-signed-notarized.dmg`

## Target-Mac revalidation

The replacement DMG was downloaded again from the GitHub Release onto the user's Apple Silicon Mac and validated independently from the CI runner.

- Downloaded file size: 142,773,348 bytes.
- Release checksum and local checksum matched exactly:
  `d3c76e3227ab6ad461bb70cc491c9e044bdb00a8f5ff2473006c7a71c949247c`.
- `xcrun stapler validate`: `The validate action worked!`.
- DMG `spctl`: **accepted**, `source=Notarized Developer ID`.
- Mounted app identifier: `com.ombhrum.fabushi`.
- Mounted app authority: `Developer ID Application: Guangxi Dixi Artificial Intelligence Application Software Co., Ltd (M4Q99K4UR4)`.
- `TeamIdentifier=M4Q99K4UR4`.
- Mounted app `codesign --verify --deep --strict`: success.
- Mounted app `spctl`: **accepted**, `source=Notarized Developer ID`.
- Direct launch from the mounted DMG succeeded; process observed at PID `25077` with executable `/Volumes/.../fabushi.app/Contents/MacOS/fabushi`.

The target Mac currently has only about `764 MiB` free on the data volume. A temporary copy-install simulation failed with `No space left on device`; that temporary copy was deleted. This is a separate storage-capacity issue, not a signature/notarization failure. The signed app itself launches successfully from the DMG.

## Permanent release-path repair

Branch commit `da337309651dd61bad484e5e8cb5b2e94f6a8d98` updates `.github/workflows/native-electron-release.yml` so future macOS release packaging must:

1. import the repository Developer ID Application certificate;
2. enable real electron-builder code signing for the macOS matrix target;
3. submit the DMG to Apple notarization;
4. staple the ticket;
5. require Gatekeeper acceptance before artifact upload.

FCM-008 remains `in-progress` until this permanent workflow fix and durable evidence are merged through protected `main` and re-read from canonical state.
