# TFI-MACOS-INTERACTIVE-001 — macOS App-owned interactive E2E loop

- **Project ID:** `FAB-P0001`
- **Project Key:** `TFI`
- **Task ID:** `TFI-MACOS-INTERACTIVE-001`
- **Scope:** cross-stage macOS desktop acceptance for current declared M3–M12 capabilities
- **Status:** `TESTING`
- **Latest governed macOS test release actually tested:** `v1.2.27` -> `ecebd0373c158c6eb8ee225ac184cc3ca2e9e6dc`.
- **Attempt 10:** run `33975902199`, App-owned device `gha-33975902199-1-macos-app`; stable App-target rebase passed, then native Computer Use failed because the direct App-owned MCP lost the package-derived `Fabushi Computer Control.app` helper environment.
- **Current blocker:** `computer_elements` resolved `/Users/runner/Applications/Fabushi Computer Control.app` instead of the signed helper embedded under the installed Fabushi package.
- **Atomic repair branch:** `fix/tfi-macos-app-owned-native-helper-env-20260905`, staging comparable macOS test version `1.2.28`; Android/iOS build counters remain unchanged.

## Product truth

The macOS GitHub Actions machine is only the host environment. The installed Fabushi Test macOS application must be launched and logged into the protected CI test account; only then may the application-owned remote-device supervisor obtain `feature.auth.deviceAgentSession` and register that application with the account-scoped device gateway. `@fabushi test` discovers and controls that newly registered application. KRIS, a pre-online Runner, `interactive-runner`, and a runner-started standalone device agent are forbidden as the device source.

`v1.2.26` remains excluded from acceptance because its release run started before the canonical protected-main source gate was restored. `v1.2.27` is the first governed release after that repair and is valid evidence for Attempt 10.

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

The signed v1.2.27 package already passed packaged Computer Control verification, so the helper content is present. The remaining defect is the App-owned direct-MCP environment boundary. The supervisor may propagate only package-derived runtime values selected by `embeddedComputerControlEnvironment()`:

- `MAHAYANA_COMPUTER_MCP_HOME` -> `CHATGPT_COMPUTER_HOME`;
- `MAHAYANA_COMPUTER_MCP_NATIVE_HELPER` -> `CHATGPT_COMPUTER_NATIVE_HELPER`;
- `MAHAYANA_COMPUTER_MCP_MAC_APP_DIR` -> `CHATGPT_COMPUTER_MAC_APP_DIR`.

Those package-derived values must override inherited shell values. This does not change account/session parsing, gateway ownership, device identity, Computer Use policy, or stale-ref safety. A narrow GitHub test must construct a packaged runtime and prove the spawned App-owned device agent/direct MCP receives only the signed bundle helper path. Heavy build/package/journey validation remains post-main in GitHub Actions.

## Defect / merge / release loop

Each independent product or release-governance failure gets one defect PR, protected-main merge, strictly newer comparable governed macOS test version, then full retest of that newest package. Do not close this task until the full journey and evidence gate are green.

## Evidence ledger

- Attempts 1–6: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/README.md`.
- Attempts 7–9: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempts-7-9.md`.
- v1.2.26 exclusion / v1.2.27 release gate: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-release-gate-1.2.27.md`.
- Attempt 10 / v1.2.27 native helper blocker: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempt-10-native-helper.md`.
