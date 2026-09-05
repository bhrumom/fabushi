# TFI-MACOS-INTERACTIVE-001 — macOS App-owned interactive E2E loop

- **Project ID:** `FAB-P0001`
- **Project Key:** `TFI`
- **Task ID:** `TFI-MACOS-INTERACTIVE-001`
- **Scope:** cross-stage macOS desktop acceptance for current declared M3–M12 capabilities
- **Status:** `TESTING`
- **Current verified canonical source before this defect branch:** `main@50818ecdc6c222f2e0d0de6000b580d714888413`
- **Latest published macOS test package actually tested:** `v1.2.25` -> `55fee5ce3d6f4de8bffd882dbd83498af75dfbaf`
- **Current independent blocker:** stable App MCP action rejected by page-global generation churn (`219 -> expected 251`) in App-owned run `33973614630`.
- **Atomic repair branch:** `fix/tfi-macos-stable-agent-rebase-20260905`, staging comparable macOS test version `1.2.26`.

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

The platform-enablement change is one PR. Thereafter each real product defect found by the live macOS journey receives one issue/record and one independent defect PR. Keep PR checks narrow. Heavy package creation and complete journeys run only in GitHub Actions. Merge through protected main only, publish a version-comparable newer macOS test release, then test that newest published package again with `@fabushi test`. Do not close the task until the full journey and evidence gate are green on the newest published macOS test version.

For the current Attempt 9 defect, exact generation rejection remains authoritative in the base DOM surface. A stale action may be rebound in the desktop private bridge only when it is backed by a prior snapshot lease, addresses one unique stable `agentId`, remains on the same route/screen, has an identical action-relevant target fingerprint, and completes within a bounded retry count. Positional refs and any semantic target change remain fail-closed.

## Evidence ledger

- Historical Attempts 1–6: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/README.md`.
- Live Attempts 7–9 and the v1.2.25 blocker boundary: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempts-7-9.md`.
