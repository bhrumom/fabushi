# TFI-M11-ANDROID-INTERACTIVE-001 — Android released-APK interactive release-test loop

- Project: `FAB-P0001 / TFI`
- Status: `IN_PROGRESS`
- Platform: Android Emulator + signed Native Android GitHub Release APK
- Updated: 2026-09-06
- Canonical baseline: `main@3f633e07cae0b022cce1ff3e6aeb8bfa92aa463d`

## Problem boundary

Android already owns `FabushiAppAgentSurface` and the six semantic tools, but canonical main has no installed-App remote-device transport or Android interactive Actions gate. The latest Android published package is also behind canonical version state. Existing Runner gateways and stale devices are not valid substitutes.

## Requirement

After a signed Android GitHub Release APK is published from protected canonical main, GitHub Actions must start evidence recording, install that exact APK, authenticate the protected CI test account, stage only a bounded refresh-token-free session, and let the installed Android App itself register an account-scoped device with `platform=android` and `metadata.kind=github-actions-android-app`.

The interactive device must expose only:

- `fabushi.app.status`
- `fabushi.app.snapshot`
- `fabushi.app.find`
- `fabushi.app.action`
- `fabushi.app.wait`
- `fabushi.app.assert`

No Runner-owned gateway, arbitrary shell execution, JavaScript execution, reflection, fake note evidence, or assertion deletion is allowed.

## Acceptance

1. PR fast gate runs shell/contract validation plus Android Kotlin compilation only; no local/native build or emulator work.
2. The manual Android interactive workflow accepts an exact release tag and release SHA, verifies the tag points at that SHA, downloads the published APK and `SHA256SUMS.txt`, and installs the verified APK without rebuilding it.
3. Recording/logcat starts before installation. Authentication occurs only after installation.
4. The App imports only the validated protected short-lived session in the GitHub-release variant, sets up the shared host before any authenticated host request, and registers its own official WebSocket gateway.
5. `@fabushi test` discovers only the fresh Android device whose metadata binds it to the exact Actions run.
6. All six semantic tools must complete successfully. The larger feature matrix is driven through those tools and ends with a real logout that disconnects the App-owned gateway.
7. The workflow uploads complete video, per-call screenshots, gateway trace, logcat, release/checksum identity, report and diagnostic logs on both success and failure.
8. Any product defect discovered by semantic control receives its own fix PR and project record, followed by a new version/release and rerun.

## Current implementation PR scope

- Android App-owned WebSocket gateway transport.
- GitHub-release-only bounded CI session bootstrap.
- Exact released-APK Android interactive Actions workflow and evidence runner.
- Minimal PR compilation/contract gate.
- No UI semantic-surface behavior change in this task; logged-in surface completeness is intentionally left to evidence-driven follow-up after first live Android device registration.

## 2026-09-06 release-to-interactive self-start follow-up

Live recovery re-read found the Android interactive workflow active but with zero historical runs. The current Android release workflow publishes the signed immutable test APK but does not dispatch the required interactive acceptance lane. The atomic follow-up on `fix/tfi-android-interactive-self-start-20260906` preserves the existing App-owned gateway and six-tool truth contract, adds only the `actions: write` permission needed by the release job, and dispatches the existing Android interactive workflow after successful release publication with the exact release tag and canonical source SHA. Task status remains `IN_PROGRESS` until protected merge, a strictly newer Android release, fresh App-owned Android device discovery, complete six-tool feature-matrix execution, real logout, and complete evidence upload all pass.

## 2026-09-06 Android 1.2.39 retest candidate

After protected merge of PR #2406, canonical main is `b6dc0d009d71c66f1581cba94199e2679bd1eb6d`. The next strictly newer governed Android candidate is `1.2.39` on `release/tfi-android-1-2-39-20260906`. This candidate exists only to publish the post-repair signed Android test APK and exercise the newly connected release-to-interactive App-owned acceptance path. Status remains `IN_PROGRESS` until the version PR is protected-merged, the exact-main Android release succeeds, its self-started interactive run registers a fresh run-bound Android App-owned device, the complete six-tool feature matrix and real logout pass, and the required video/screenshots/trace/logcat/report evidence is verified.
