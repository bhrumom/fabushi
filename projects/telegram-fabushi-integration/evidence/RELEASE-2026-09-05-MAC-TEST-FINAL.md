# 2026-09-05 Mac test release final evidence

Status: RELEASE-BLOCKED

The Mac artifact itself completed successfully, but the user-directed release closure required all long non-Mac delivery to remain stopped. After Mac success, an out-of-scope concurrent PR #2354 merged and started an iOS Apple Store delivery run, so the overall release-control objective is not truthfully PASS.

## Target work-chain merges
- #2349 -> cf084da2f49d27a7cf9bf575c33f1c43b8c1123d on the original architecture base.
- #2350 -> d1ea4603ecda430e8694ac5590fe1bc82edb02d9 on the original architecture base.
- #2351 -> b1849f0a6a9c6172c48541226af2a8adf47c8f87 on the original architecture base.
- #2352 -> canonical main d2135a22c75a37b0b8e7da5883f5cadd464bd9fb; clean main integration, version/workflow release control.
- #2353 -> canonical main 16b56277e2116b73f98f0406a323919de6d7728a; binds the single Mac test workflow to the protected-main release change.

Unrelated architecture content (GBF/MSR/MiniApp/Mahayana follow-up planning) was not imported through #2352. Historical open PRs were not bulk-merged.

## Mac release evidence
- Workflow: `.github/workflows/native-electron-release.yml` / `Native Electron macOS test release`.
- Run: 33960794615.
- Job: 101292219598 (`macOS test release`).
- Exact release source: main@16b56277e2116b73f98f0406a323919de6d7728a.
- Version: 1.2.23.
- Result: success.
- Developer ID identity install: success.
- Staged native executable signing verification: success.
- Mac DMG/ZIP packaging: success.
- Notarization, staple, Gatekeeper/package verification: success.
- `latest-mac.yml` and DMG/ZIP blockmaps: present and verified by the workflow.
- Immutable GitHub prerelease: https://github.com/bhrumom/fabushi/releases/tag/v1.2.23
- Release target commit: 16b56277e2116b73f98f0406a323919de6d7728a.
- Evidence artifact: id 9968035902, name `mac-test-release-1.2.23`, 275841871 bytes, digest `sha256:3b4eafa4a1cfe71746602d475dff2361574d9811b412795fd03faa93135b8046`, expires 2026-12-04.
- Complete canonical logs remain attached to Actions run 33960794615.

## Published assets / SHA256
- ca20c23e0c4cab68e08076ad0b2e3fe4abcdc4a434cc86de30ff3a1dff7bb31c  fabushi-1.2.23-macos-arm64.dmg
- afe2adc9d6d7aef430402babe625ad8b36ca5d8300883d36de128228155040b5  fabushi-1.2.23-macos-arm64.zip
- 74f48e977deb4110f5d2cf7b957f21a7d1944c07fd5ef105082479f914120a97  latest-mac.yml
- ec76a634902cd4b8114348201b107fb17f93c567368f75a15a1549a9dea02e07  fabushi-1.2.23-macos-arm64.dmg.blockmap
- 32055b73286c9229dfb6b2376ee2b634da1e2e4aa0b9369b122af826e2ea8c2c  fabushi-1.2.23-macos-arm64.zip.blockmap

## Release-control exception after Mac success
A separate concurrent PR #2354 (`release: controlled iOS-only 1.2.23 test delivery`) merged after the Mac run source SHA, advancing main to 21b3f600cfe994f155d78756c3116d57e3b2830b. It changed only `.github/workflows/apple-store-delivery.yml` plus its FCM evidence marker, but it started out-of-scope iOS run 33961448084. The run reached `Build and upload native iOS IPA` and began `Build Mahayana static library for iOS devices`. This violates the user's Mac-only/no-iOS release constraint. Connector cancellation is unavailable; a device-side credential-based API cancellation attempt was blocked by platform safety policy, so no cancellation success is claimed.

This records-only/control PR restores `.github/workflows/apple-store-delivery.yml` exactly to its pre-#2354 blob `0f3c535283c5d3dadfab27b24886f999b94ae85c`, removing the new push trigger so it cannot automatically start again from that marker. It does not alter product semantics.

## Paused / excluded heavy workflows
The Mac integration made Electron desktop quality gate, Messaging Product Gate, Developer Fiat Commerce, Native mobile quality gate, Computer control security gate, Electron macOS hot package, Post-main E2E Release delivery, and Sync app version policy manual-only for this release round. Windows/Linux/Android packaging, duplicate packaged E2E, and the intended iOS path were excluded. The protected-main required short `CI result` remained because ruleset 15857448 requires it.

## Rollback
Primary pre-release rollback point: main@586a0952f17ab4b36dab9a69402b837968f5aa3f.
Mac release source: main@16b56277e2116b73f98f0406a323919de6d7728a.

## Next step
Stop/confirm terminal cancellation of iOS run 33961448084 using an authorized Actions-cancel interface; only after that may the overall Mac-only release-control closure be promoted from RELEASE-BLOCKED to RELEASE-PASS. No rebuild or new platform release is required for the already-successful Mac v1.2.23 artifact.
