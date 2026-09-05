# iOS test release result — 2026-09-05

Status: `IOS-RELEASE-BLOCKED`

Project: `FAB-P0003 / FCM`.

## Released source and protected merge
- Release-control PR: `#2354`.
- Release-control head: `7c38279747b31852c73503a2fd83ae22e1258254`.
- Protected merge-queue/canonical release source: `21b3f600cfe994f155d78756c3116d57e3b2830b`.
- Pre-release rollback point: `16b56277e2116b73f98f0406a323919de6d7728a`.
- Required protected-main source gate: `CI result`; exact release-control head and merge-group gate were green.

## Unique iOS test delivery
- Workflow: `.github/workflows/apple-store-delivery.yml` (`Apple Store delivery`).
- Unique run: `33961448084`.
- Event: `push` from protected `main`.
- Exact source/head SHA: `21b3f600cfe994f155d78756c3116d57e3b2830b`.
- Resolved target/tier: `ios` / `test`.
- App version: `1.2.23`.
- Release build number used by archive/export: `2026.9.5`.
- Bundle id: `com.ombhrum.fabushi`.
- Workflow conclusion: `success`.

## Hard-gate evidence
Job `101294016153` completed `success`: App Store/iOS secret completeness; physical-device Rust toolchain/static Mahayana library; iOS distribution identity + provisioning profile; XcodeGen; signed archive; IPA export; App Store Connect validate/upload; delivery-evidence artifact upload all succeeded.

The same run explicitly skipped job `101294016614` (`Build and upload Electron macOS MAS package`). Result job `101295419109` completed `success`, verified exactly one selected Apple package, generated SHA256SUMS, and created immutable GitHub Release `apple-v1.2.23-2026.9.5` targeting the exact release source.

Release asset:
- `Fabushi-1.2.23-2026.9.5-ios.ipa`
- size `12373382` bytes
- digest `sha256:5777d026660655175eb8ec56decc60b4e8ca2253e74d5a44bc1115a783f4e1a7`
- Actions artifact `apple-store-ios-2026.9.5`, id `9968215346`, ZIP digest `sha256:457444b31ee7853aa245e0e740d80736cc427d4805e9474c7819ecf32904b902`.

## App Store Connect / TestFlight boundary
The repository upload implementation uses `xcrun altool --validate-app` then `xcrun altool --upload-app`, and records `status=uploaded` / `reason=accepted_by_app_store_connect`. Run `33961448084` proved this acceptance path succeeded.

The completed workflow does not wait for Apple build processing, query the processed TestFlight build, confirm internal-testing group assignment, or prove an internal tester can install it. Therefore this record does not claim TestFlight/internal-testing availability. Because the requested hard gate must not be skipped, overall release status is fail-closed `IOS-RELEASE-BLOCKED` despite successful signing, archive, IPA export, and App Store Connect upload.

## Scope / non-triggered work
This iOS task did not trigger a second Apple delivery run and did not trigger new Mac, Windows, Linux, Android, Electron full-release, native-mobile quality-gate, packaged E2E, or other full-platform release workflows. The macOS job inside the unique Apple run was skipped. The already-running Mac release from the preceding independent task was outside this task and was not reused as iOS evidence. Unrelated or obsolete PRs were left unmerged; only `#2354` was merged for this iOS release chain.

## Rollback and unique next step
Rollback point: `main@16b56277e2116b73f98f0406a323919de6d7728a` for the release-control change. Do not weaken signing/source/upload gates.

Unique next step: verify Apple processing for version `1.2.23`, build `2026.9.5`, and confirm assignment/availability to the intended TestFlight internal-testing group. Do not trigger another iOS build/upload unless Apple reports this uploaded build unusable or rejected.
