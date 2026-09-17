# 2026-09-16 — Zero-test automatic control-plane cleanup and all-platform prerelease

Project: `FAB-P0003 / FCM`
Task: `FCM-024`

This source refines FCM-023 without changing its release ordering.

## Automatic workflow whitelist

Automatic repository activity before a test/beta/prerelease may perform only work required to merge or construct/distribute artifacts:

- the lightweight no-product-test `CI result` merge-queue status;
- exact-source/version/provenance selection;
- dependency installation needed to build/package;
- compilation/build/sign/notarize/staple/package/checksum/upload/publish operations;
- deployment/publication operations that are not product behavioral tests.

Everything whose primary purpose is unit/integration/contract/smoke/E2E/regression/simulator/emulator/user-journey/security-test/performance-test/quality-gate execution must not run automatically before test publication. Historical workflows remain in Git history and may be restored as manual diagnostics only by a later explicit requirement.

## All-platform test publication

A monotonically newer `app-version.json` change on protected `main` is the release trigger. From the exact accepted source:

- macOS, Windows and Linux: build/sign/package and publish an immutable GitHub prerelease; no product tests;
- iOS: build/sign/upload a TestFlight test build; no product tests;
- Android: build/sign/upload to the internal test track; no product tests.

The test release is not stable/formal acceptance.

## Formal validation

After the test artifacts exist, manually start the relevant Action-hosted runner. The runner may build/install/launch the exact candidate when necessary, establish a bounded test-account session, and wait. The installed Fabushi App must own/register the controllable device. The Action workflow must not simulate the acceptance journey itself.

The ChatGPT-side agent connects through the **Fabushi official MCP**, discovers the newly registered run-scoped App-owned device, invokes the advertised Fabushi device/app tools, records evidence/notes, and explicitly finishes the remote session. A stable/formal release is forbidden until required exact-candidate platform journeys pass this external MCP-driven validation.

If the official MCP account connection is unavailable, no fresh App-owned device is visible, a required tool is unavailable, external control fails, or the exact candidate does not pass, stable publication remains blocked.
