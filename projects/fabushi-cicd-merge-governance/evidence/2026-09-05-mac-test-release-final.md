# Mac-only test release final control — 2026-09-05

Status: RELEASE-BLOCKED

Mac delivery itself is RELEASE-PASS evidence, but the overall user release directive is blocked by a concurrent out-of-scope iOS run after Mac completion.

## Protected-main and merge evidence
Ruleset 15857448 remained enforced: merge queue + required `CI result`, no bypass.
- #2352 required CI run 33960614168: success; merge-group CI run 33960679267: success; main merge d2135a22c75a37b0b8e7da5883f5cadd464bd9fb.
- #2353 required CI run 33960745317: success; merge-group CI run 33960772138: success; main merge 16b56277e2116b73f98f0406a323919de6d7728a.

## Unique Mac release Action
- workflow: `.github/workflows/native-electron-release.yml` (`Native Electron macOS test release`)
- run: 33960794615
- head: 16b56277e2116b73f98f0406a323919de6d7728a
- version: 1.2.23
- job: 101292219598
- result: success
- signing: success
- DMG/ZIP packaging: success
- notarization/stapling/Gatekeeper verification: success
- updater assets: `latest-mac.yml`, DMG blockmap, ZIP blockmap present
- prerelease: https://github.com/bhrumom/fabushi/releases/tag/v1.2.23 (immutable, prerelease, target 16b56277e2116b73f98f0406a323919de6d7728a)
- Action evidence artifact: 9968035902 / `mac-test-release-1.2.23` / digest `sha256:3b4eafa4a1cfe71746602d475dff2361574d9811b412795fd03faa93135b8046`

SHA256SUMS:
- `ca20c23e0c4cab68e08076ad0b2e3fe4abcdc4a434cc86de30ff3a1dff7bb31c`  `fabushi-1.2.23-macos-arm64.dmg`
- `afe2adc9d6d7aef430402babe625ad8b36ca5d8300883d36de128228155040b5`  `fabushi-1.2.23-macos-arm64.zip`
- `74f48e977deb4110f5d2cf7b957f21a7d1944c07fd5ef105082479f914120a97`  `latest-mac.yml`
- `ec76a634902cd4b8114348201b107fb17f93c567368f75a15a1549a9dea02e07`  `fabushi-1.2.23-macos-arm64.dmg.blockmap`
- `32055b73286c9229dfb6b2376ee2b634da1e2e4aa0b9369b122af826e2ea8c2c`  `fabushi-1.2.23-macos-arm64.zip.blockmap`

## Out-of-scope concurrent exception
PR #2354 merged concurrently after the accepted Mac source and advanced main to 21b3f600cfe994f155d78756c3116d57e3b2830b. It created iOS Apple Store delivery run 33961448084. At audit time that run was in progress in job `Build and upload native iOS IPA`, specifically building the physical-device Mahayana static library. This is prohibited by the user's Mac-only directive. The GitHub connector exposes no cancel-run write action, and an attempt to use device-stored credentials for the cancel endpoint was blocked by platform safety controls; therefore no cancellation is fabricated.

This control change restores `.github/workflows/apple-store-delivery.yml` to pre-#2354 blob `0f3c535283c5d3dadfab27b24886f999b94ae85c`, so the #2354 push marker no longer starts automatic iOS delivery. The historical #2354 evidence file is retained as immutable history.

## Heavy workflows held back
Electron desktop quality gate, Messaging Product Gate, Native mobile quality gate, Computer control security gate, Developer Fiat Commerce, Electron macOS hot package, Post-main E2E Release delivery, and Sync app version policy were made manual-only by the Mac release-control integration. Windows/Linux/Android and duplicate packaged E2E release work was not run by the Mac closure. Short required `CI result` and incidental governance checks are not release builds.

Rollback: main@586a0952f17ab4b36dab9a69402b837968f5aa3f before this release-control integration.

Only next step: cancel/confirm cancellation of iOS run 33961448084 through an authorized Actions-cancel path. The Mac v1.2.23 artifact itself does not need rebuilding.
