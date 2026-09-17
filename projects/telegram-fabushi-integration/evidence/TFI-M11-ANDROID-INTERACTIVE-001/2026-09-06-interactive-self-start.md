# TFI-M11-ANDROID-INTERACTIVE-001 — Android release self-starts interactive App E2E

- Protected baseline before this correction: `main@cc24e1d4bb6a0d30c821b9e6b64b620d8e8b5361`.
- Latest published Android test APK before this correction: `android-v1.2.37-262490622` -> `111b4a9ab18247da0ea90b45cbd3abaaa61784a0`.
- Live Actions state before this correction: `Android interactive app device E2E` is active but has zero historical runs.
- Existing interactive workflow already enforces exact release tag/SHA, recording and logcat before install, protected-account login after install, App-owned Android device registration, all six `fabushi.app.*` semantic tools, real logout, and always-uploaded evidence.

## Root cause

`Native Android GitHub release` publishes the immutable signed APK and checksum assets, but the release job ends immediately after `gh release create`. Nothing dispatches `android-interactive-app-e2e.yml`, so a successful Android test release can exist without ever entering the required App-owned interactive acceptance lane.

## Atomic correction

- Preserve the existing release and interactive workflows and all App-owned truth gates.
- Grant the Android release workflow only the additional `actions: write` permission required for workflow dispatch.
- After the immutable release is successfully published, dispatch the existing `android-interactive-app-e2e.yml` on `main` with the exact `${{ steps.release.outputs.release_tag }}` and `${{ steps.source.outputs.sha }}` produced by that release run.
- Add a narrow contract test that locks this release-to-interactive handoff. No local build, emulator, runner-owned gateway, semantic assertion, login flow, or product surface is changed.

## Post-merge acceptance

The next strictly newer Android test release from protected canonical `main` must create exactly the immutable release it reports, then start an Android interactive Actions run. External acceptance must select only the fresh `github-actions-android-app` device registered by that run and must exercise the complete feature matrix through real `fabushi.app.status`, `snapshot`, `find`, `action`, `wait`, and `assert` calls before a real logout. Video, screenshots, gateway trace, logcat, report, release/checksum identity, and failure evidence remain mandatory.
