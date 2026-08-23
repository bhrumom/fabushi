# FCM-008 — Build latest macOS package

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-008
- **Status:** passed
- **Started:** 2026-08-23
- **Updated:** 2026-08-23
- **Completed:** 2026-08-23

## Objective

Build the latest canonical Fabushi macOS Electron package from GitHub `main` and provide a downloadable artifact/release link.

## Source requirement

User request: “构建最新的mac版本，把下载链接给我”。

## Final source

- Canonical product source SHA: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`.
- Product version emitted by electron-builder: `1.0.2`.
- Architecture: macOS arm64.

## Execution

1. Manual canonical `Electron desktop quality gate` run `32619314508` used the exact source SHA and exposed two deterministic Messenger E2E regressions before package jobs. No package was claimed from that failed gate.
2. A one-shot GitHub Actions build on `macos-15` then reused the production package recipe while explicitly checking out and asserting the exact canonical source SHA. Run `32619653455` completed successfully and produced the DMG/ZIP artifact.
3. Because the intermediary VPS had insufficient free space for a 284 MB artifact copy, the package was not routed through the VPS. A second GitHub-native run `32619943578`, with the macOS Host cache hit, rebuilt the exact same source and published immutable prerelease assets directly from the GitHub runner.
4. The one-shot workflow is not part of canonical product source and is removed from the record branch before governance closure.

## Verified release

- Tag: `macos-main-67b70fff-20260823`
- Release: `Fabushi macOS latest main 67b70fff`
- Target commit: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`
- Prerelease: yes
- DMG asset: `-1.0.2-arm64.dmg` — 142,142,859 bytes
- ZIP asset: `-1.0.2-arm64-mac.zip` — 142,332,921 bytes
- Checksums: `SHA256SUMS.txt`

## Acceptance criteria

1. Build source equals the latest canonical `main` SHA at task execution time. **Passed.**
2. GitHub Actions produces a macOS Fabushi package successfully. **Passed** in runs `32619653455` and `32619943578`.
3. The package is retrievable and a stable GitHub Release download entry point exists. **Passed.**
4. FCM task/WBS/evidence are synchronized. **Passed by the closure record.**

## Important validation note

This task accepts the requested **build artifact**, not the full Messenger E2E product gate. The first canonical quality-gate run exposed two existing FAB-P0001 Messaging regressions (duplicate in-conversation message projection and missing renderer-to-Host actor binding). They are explicitly recorded as product blockers and are not hidden by this build task. The prerelease notes make the same distinction.

## Evidence

See `../../evidence/FCM-008/README.md`.
