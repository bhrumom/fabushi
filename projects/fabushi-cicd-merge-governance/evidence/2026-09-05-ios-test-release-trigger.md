# iOS test release trigger — 2026-09-05

Status: TRIGGER-PREPARED

Project: `FAB-P0003 / FCM`.

Purpose: one controlled protected-main trigger for the latest Fabushi native iOS test delivery only. The release source is the canonical main commit created when this PR is accepted by the protected merge queue. The Apple workflow resolves this push as target `ios` and tier `test`; macOS remains unselected.

Release identity before merge:
- pre-release canonical main: `16b56277e2116b73f98f0406a323919de6d7728a`
- app version: `1.2.23`
- canonical iOS build mirror: `29`
- controlled workflow: `.github/workflows/apple-store-delivery.yml`
- required test-tier source gate: `CI result`
- bundle id: `com.ombhrum.fabushi`

Hard gates remain real and fail closed: iOS distribution certificate, provisioning profile, App Store Connect API key, physical-device Rust static library, Xcode archive, App Store Connect export IPA, validation/upload, evidence artifact, and immutable GitHub delivery Release. This trigger does not submit App Review.

No local product build/test/E2E is permitted or used. No Mac/Windows/Linux/Android release workflow is triggered by this marker. The existing Mac run from the preceding independent Mac release task is outside this iOS task and is not reused as evidence.

Rollback point: pre-release canonical main `16b56277e2116b73f98f0406a323919de6d7728a`. If the iOS release fails, do not weaken signing, source, upload, or protected-main gates; record the exact failed run/job/step and stop `IOS-RELEASE-BLOCKED`.
