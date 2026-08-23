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

Deterministic Messenger blockers:

1. unique in-conversation search marker projected into two message `<article>` nodes;
2. forged renderer messaging envelope actor ID was not rebound/rejected at the desktop Host boundary.

No package from this failed gate is represented as accepted.

## Round 2 — exact-source GitHub macOS build

- One-shot run: `32619653455`
- Runner: GitHub `macos-15`
- Workflow explicitly checked out `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c` and asserted `git rev-parse HEAD == SOURCE_SHA` before building.
- Native Mahayana Host: success.
- Pinned offline ASR engine: success.
- Electron renderer: success.
- `electron-builder --mac`: success.
- Packaged application/installers verification: success.
- Actions artifact: `fabushi-macos-main-67b70fff`, artifact ID `9488034188`, approximately 284 MB.

Produced assets observed in the build log:

- `全球法布施-1.0.2-arm64.dmg`
- `全球法布施-1.0.2-arm64-mac.zip`
- blockmaps / `latest-mac.yml`

## Round 3 — direct immutable GitHub prerelease

The intermediary VPS could not download the ~284 MB Actions artifact because its temporary filesystem reported `no space left on device`. No user/VPS files were deleted to work around that unrelated capacity issue.

A second GitHub-native macOS run reused the newly-created native Host cache and published the same exact canonical source directly from the runner:

- Run: `32619943578` — success.
- Tag: `macos-main-67b70fff-20260823`.
- Release title: `Fabushi macOS latest main 67b70fff`.
- Target commit: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`.
- Prerelease: true.
- DMG release asset: `-1.0.2-arm64.dmg` — 142,142,859 bytes.
- ZIP release asset: `-1.0.2-arm64-mac.zip` — 142,332,921 bytes.
- Checksum asset: `SHA256SUMS.txt`.

## Download entry points

- Release page: `https://github.com/bhrumom/fabushi/releases/tag/macos-main-67b70fff-20260823`
- DMG: `https://github.com/bhrumom/fabushi/releases/download/macos-main-67b70fff-20260823/-1.0.2-arm64.dmg`
- ZIP: `https://github.com/bhrumom/fabushi/releases/download/macos-main-67b70fff-20260823/-1.0.2-arm64-mac.zip`
- SHA256: `https://github.com/bhrumom/fabushi/releases/download/macos-main-67b70fff-20260823/SHA256SUMS.txt`

## Validation boundary

FCM-008 is accepted as the requested **latest macOS build and download delivery**. It does not claim the existing Messenger product E2E regressions are resolved. Those failures remain separately owned by FAB-P0001/TFI and are explicitly called out in the prerelease notes.
