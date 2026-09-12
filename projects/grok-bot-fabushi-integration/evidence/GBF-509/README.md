# GBF-509 Evidence Index

## Branch implementation evidence

- Branch: `fix/desktop-energy-ghost-white-release`
- Base observed protected main before PR: `77f72b13304b75a45530de03fb807f52c3624be1`
- Runtime/avatar commit: `6e91c33a0ff8bf170570706dcc4c217dd626406b`
- White palette commits: `ee66ef334ca8351be895afed4d90971aaa205b8d`, `d56d0a99d21d887e51cdac0988aa8aee61f5b804`
- Canonical brand source: `b350e7c716de795303082eba68635d8105caa94c`
- Dependency-free icon generator: `e225a9e7bb995c7fe925823405c3f623d589c006`
- Desktop release/build integration: `1da7fb3e0ed10a36edc3f55f30b38df39cb226f5`
- Android build integration: `16f3a1b58f29833be66f9e9b3861b2c457efe03b`
- iOS XcodeGen integration: `83bd15f0248683a684d2d9e0fc7f7761eeaa2762`
- White native titlebar + test: `9036c8c6fd7356655445c00d97c5936b2fd5a6a2`, `45c4bcdae49d2055b9a1cf218ece0638dc812c1b`
- Release version controls: `e065000ecb916c4b78faea6d50bc2fdc49f9d009`, `e004711de2eafe65a343301ce674977d237c4a91`, `3b2dcd5de8b0c70e1af63f7c52de3df96a495633`, `6e444c86d5e17fa2a6efca23196d5f3274bbc5eb`
- Motion/visual CI guard update: `3f41b7885c55d3e2addf3d67a89d317754af427a`

## Local deterministic icon-generator verification

Executed in the task container using only Node standard-library modules:

- `node /tmp/generate-cloth-ghost-icons.mjs --platform=all --repo-root=/tmp/icon-test-green`
- Verified with `file`:
  - desktop icon: PNG 1024x1024 RGBA;
  - iOS marketing icon: PNG 1024x1024 RGBA;
  - Android xxxhdpi adaptive foreground: PNG 432x432 RGBA.
- Visual inspection confirmed a white/light background, green cloth-ghost silhouette, three soft lower folds, and two white capsule eyes.

Container network access could not resolve `github.com`, so a local repository clone was not available for the full renderer/native suites. Those authoritative tests are delegated to the repository's GitHub Actions PR and post-main release gates, which have network/toolchain/signing access.

## Open-source-first evidence

- Electron official WebPreferences documentation: `backgroundThrottling` defaults to `true`, throttles background animations/timers, and affects Page Visibility.
- XcodeGen official project spec: `preBuildScripts` and `basedOnDependencyAnalysis` are supported target build-script controls.
- Gradle `Exec` is the existing task primitive used to invoke the deterministic generator before Android builds.

## Pending authoritative evidence

- PR number/head SHA and required checks.
- Protected-main merge SHA.
- Exact-main desktop packaged build/E2E/release run and `v1.2.57` assets.
- Exact-main mobile quality gate.
- Android immutable release run/assets.
- Apple delivery run and App Store Connect/TestFlight upload evidence.

This file must be updated with the real run IDs/statuses before GBF-509 is marked complete.
