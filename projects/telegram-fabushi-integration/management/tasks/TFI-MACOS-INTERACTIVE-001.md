# TFI-MACOS-INTERACTIVE-001 — macOS App-owned interactive E2E loop

- **Project ID:** `FAB-P0001`
- **Project Key:** `TFI`
- **Task ID:** `TFI-MACOS-INTERACTIVE-001`
- **Scope:** cross-stage macOS desktop acceptance for current declared M3–M12 capabilities
- **Status:** `TESTING`
- **Current canonical macOS product repair:** `main@9dae2ea92ad055b4f5af2dfd4b99e872d200c840` from PR `#2378`.
- **Latest published macOS test package actually accepted for interactive testing:** `v1.2.25` -> `55fee5ce3d6f4de8bffd882dbd83498af75dfbaf` (Attempt 9 FAIL on stale global generation).
- **v1.2.26 disposition:** not acceptable for release testing. Its push-triggered release run `33974806955` started from `main@9dae2ea9…` before the newly exposed release-source governance defect was closed; regardless of packaging outcome, it must not enter the App-owned acceptance chain.
- **Current independent blocker:** macOS test-release workflow lacked the repository's canonical protected-main release-source gate; GBF rollback drill `33974694259` failed at the immutable/canonical gate contract after #2378.
- **Atomic governance repair:** PR `#2380`, branch `fix/tfi-macos-release-gate-1-2-27-20260905`, staging the next acceptable comparable macOS test version `1.2.27` while leaving Android/iOS build counters unchanged.

## Product truth

The macOS GitHub Actions machine is only the host environment. The installed Fabushi Test macOS application must be launched and logged into the protected CI test account; only then may the application-owned remote-device supervisor obtain `feature.auth.deviceAgentSession` and register that application with the account-scoped device gateway. `@fabushi test` discovers and controls that newly registered application. KRIS, a pre-online Runner, `interactive-runner`, and a runner-started standalone device agent are forbidden as the device source.

This task is intentionally not assigned to M11: canonical M11 is the iOS/Android mobile shared-Core milestone, while this macOS journey validates the desktop product surface across multiple existing milestones.

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

The platform-enablement change is one PR. Thereafter each real product or release-governance defect found by the live loop receives one issue/record and one independent defect PR. Keep PR checks narrow. Heavy package creation and complete journeys run only in GitHub Actions. Merge through protected main only, publish a version-comparable newer macOS test release, then test that newest published package again with `@fabushi test`. Do not close the task until the full journey and evidence gate are green on the newest published macOS test version.

For Attempt 9, exact generation rejection remains authoritative in the base DOM surface. A stale action may be rebound in the desktop private bridge only when it is backed by a prior snapshot lease, addresses one unique stable `agentId`, remains on the same route/screen, has an identical action-relevant target fingerprint, and completes within a bounded retry count. Positional refs and any semantic target change remain fail-closed.

For the current release-governance defect, the macOS test workflow must bind the exact current protected-main SHA and invoke `.github/scripts/require-release-source-gates.sh` with `RELEASE_TARGET=macos` and `RELEASE_TIER=test` before dependencies/build/signing. Existing-release publication remains fail-closed. The GBF rollback drill verifies that per-tier central contract plus immutable release semantics; it must not require unrelated formal mobile gate names to be duplicated inside a macOS-only test workflow.

## Evidence ledger

- Historical Attempts 1–6: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/README.md`.
- Live Attempts 7–9 and the v1.2.25 blocker boundary: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempts-7-9.md`.
- Release-governance defect / v1.2.26 exclusion / 1.2.27 gate: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-release-gate-1.2.27.md`.
