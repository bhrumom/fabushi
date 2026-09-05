# TFI-M11-MACOS-INTERACTIVE-001 — macOS App-owned interactive E2E loop

- **Project ID:** `FAB-P0001`
- **Project Key:** `TFI`
- **Task ID:** `TFI-M11-MACOS-INTERACTIVE-001`
- **Stage:** `M11 shared native / desktop delivery`
- **Status:** `TESTING`
- **Canonical baseline:** `main@143c5cf10aed9e6d60810ec6c886acd2c20fa609`
- **Latest macOS test release at task start:** `v1.2.23` -> `16b56277e2116b73f98f0406a323919de6d7728a`

## Product truth

The macOS GitHub Actions machine is only the host environment. The installed Fabushi Test macOS application must be launched and logged into the protected CI test account; only then may the application-owned remote-device supervisor obtain `feature.auth.deviceAgentSession` and register that application with the account-scoped device gateway. `@fabushi test` discovers and controls that newly registered application. KRIS, a pre-online Runner, `interactive-runner`, and a runner-started standalone device agent are forbidden as the device source.

## Required first journey

Start recording before package installation, install the newest published macOS test package, log the protected test account into the app through the existing bounded CI session mechanism, wait for App-owned device registration, then control that exact App through `@fabushi test` and cover the current declared macOS capabilities without deleting real assertions merely to obtain green CI:

- startup / login / main workspace;
- conversation list and search;
- 1:1 send/receive, reply, edit, delete, forward;
- draft, pin, mute, unread state;
- contacts and groups;
- Bot / Agent;
- Mini App / WebMCP;
- media / file paths;
- notifications / sync;
- settings;
- updater and logout;
- any additional capability present in the current macOS product surface.

## Evidence contract

Every attempt, PASS or FAIL, preserves with `if: always()`:

- whole-session macOS video beginning before install;
- per-remote-call screenshots and final screenshot;
- redacted device-call trace;
- Playwright HTML report, trace, video and test results for the packaged App Agent Surface as secondary evidence;
- App stdout/stderr and macOS unified logs;
- release metadata (tag, title, target SHA, release/asset URL, asset digest, installed bundle version/build, package hash);
- machine-readable report and human README;
- exact workflow run/job, source SHA, UTC timestamp and device id.

No account session, refresh token, access token, password or secure-input envelope may be uploaded.

## Defect / merge / release loop

The platform-enablement change is one PR. Thereafter each real product defect found by the live macOS journey receives one issue/record and one independent defect PR. Keep PR checks narrow. Heavy package creation and complete journeys run only in GitHub Actions. Merge through protected main only, publish a version-comparable newer macOS test release, then test that newest published package again with `@fabushi test`. Do not close the task until the full journey and evidence gate are green on the newest published macOS test version.

## Evidence ledger

See `projects/telegram-fabushi-integration/evidence/TFI-M11-MACOS-INTERACTIVE-001/README.md`.