# TFI-MACOS-INTERACTIVE-001 — macOS App-owned interactive E2E loop

- **Project ID:** `FAB-P0001`
- **Project Key:** `TFI`
- **Task ID:** `TFI-MACOS-INTERACTIVE-001`
- **Scope:** cross-stage macOS desktop acceptance for current declared M3–M12 capabilities
- **Status:** `TESTING`
- **Latest governed macOS test release actually tested:** `v1.2.27` -> `ecebd0373c158c6eb8ee225ac184cc3ca2e9e6dc`.
- **Attempt 10:** run `33975902199`, App-owned device `gha-33975902199-1-macos-app`; stable App-target rebase passed, then native Computer Use failed because the direct App-owned MCP lost the package-derived `Fabushi Computer Control.app` helper environment.
- **Live reconciliation:** PR `#2381` was already merged as `main@36868f9c5ba389c6b627f93f792ce9a7d52192e3` before this continuation and immutable prerelease `v1.2.28` already exists, but its merge/publish happened while the canonical Electron quality gate was paused. It is not a post-restoration acceptance candidate.
- **Gate restoration:** PR `#2382` restored the exact pre-pause Electron quality workflow blob and protected-queue merged as `main@31ac7659b85cce27d31dfa7dcc54537c26e8e15e` without `automerge-force`.
- **Current independent blocker:** restored Electron main run `33999314440`, Linux job `101395223837`, fails before dependency install on canonical version drift (`1.2.28` vs stale `1.2.22` package/lock metadata; iOS marketing metadata is stale as well).
- **Atomic repair branch:** `fix/tfi-macos-version-parity-1-2-29-20260906`, staging comparable macOS test version `1.2.29` while Android/iOS build counters remain unchanged.

## Product truth

The macOS GitHub Actions machine is only the host environment. The installed Fabushi Test macOS application must be launched and logged into the protected CI test account; only then may the application-owned remote-device supervisor obtain `feature.auth.deviceAgentSession` and register that application with the account-scoped device gateway. `@fabushi test` discovers and controls that newly registered application. KRIS, a pre-online Runner, `interactive-runner`, and a runner-started standalone device agent are forbidden as the device source.

`v1.2.26` remains excluded from acceptance because its release run started before the canonical protected-main source gate was restored. `v1.2.27` is the first governed release after that repair and is valid evidence for Attempt 10. `v1.2.28` remains published but is excluded from this resumed post-restoration acceptance sequence because its PR merge and package publication occurred while the Electron quality gate was paused. The next acceptable candidate must be a strictly newer protected-main release after the restored gate is green.

## Required journey

Start recording before package installation, install the newest published governed macOS test package, log the protected test account into the app through the bounded CI session mechanism, wait for App-owned device registration, then control that exact App through `@fabushi test` and cover without weakened assertions:

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

Stable agent IDs may use the bounded target-level rebase landed by #2378. Positional generation refs remain exact and fail closed. Non-stable UI navigation may use native accessibility only through the same App-owned registered device.

## Evidence contract

Every attempt, PASS or FAIL, preserves with `if: always()` whole-session video beginning before install, per-remote-call/final screenshots, redacted device-call trace, packaged Playwright report/trace/video/results, App and unified logs, exact release metadata/digests, machine report/README, workflow run/job/source SHA/device id. No account session, refresh/access token, password, or secure-input envelope may be uploaded.

## Current atomic repair contract

The App-owned native-helper propagation defect from Attempt 10 landed in #2381 and must not be duplicated. The restored canonical Electron gate now owns the next failure boundary. Its architecture assertion requires all canonical semantic-version sources to match `app-version.json`, including desktop package/lock, native-mobile package/lock, and iOS `MARKETING_VERSION`.

The current repair synchronizes those version sources and the existing exact macOS release-control guards to `1.2.29`. Android `androidVersionCode=29` and iOS `iosBuildNumber=29` remain unchanged. No branch-protection rule, test assertion, application behavior, account/session parser, App-owned gateway path, or Computer Use safety rule changes in this slice.

The PR must pass the restored real Electron PR gate. After protected merge, only an immutable protected-main `v1.2.29` macOS test release may enter Attempt 11. Native recording must begin before installation; the App must log in and self-register its device gateway before `@fabushi test` is used for discovery/control.

## Defect / merge / release loop

Each independent product or release-governance failure gets one defect PR, protected-main merge, strictly newer comparable governed macOS test version, then full retest of that newest package. Do not close this task until the full journey and evidence gate are green.

## Evidence ledger

- Attempts 1–6: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/README.md`.
- Attempts 7–9: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempts-7-9.md`.
- v1.2.26 exclusion / v1.2.27 release gate: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-release-gate-1.2.27.md`.
- Attempt 10 / v1.2.27 native helper blocker: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempt-10-native-helper.md`.
- Restored Electron gate / version-parity failure / v1.2.29 repair: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-electron-gate-version-parity-1.2.29.md`.
