# TFI-MACOS-INTERACTIVE-001 — macOS App-owned interactive E2E loop

- **Project ID:** `FAB-P0001`
- **Project Key:** `TFI`
- **Task ID:** `TFI-MACOS-INTERACTIVE-001`
- **Scope:** cross-stage macOS desktop acceptance for current declared M3–M12 capabilities
- **Status:** `TESTING`
- **Latest governed macOS test release actually tested:** `v1.2.27` -> `ecebd0373c158c6eb8ee225ac184cc3ca2e9e6dc`.
- **Attempt 10:** run `33975902199`, App-owned device `gha-33975902199-1-macos-app`; stable App-target rebase passed, then native Computer Use failed because the direct App-owned MCP lost the package-derived `Fabushi Computer Control.app` helper environment.
- **Historical reconciliation:** #2381 was already merged as `main@36868f9c5ba389c6b627f93f792ce9a7d52192e3`; `v1.2.28` exists but was published while Electron quality was paused and is excluded from resumed acceptance.
- **Electron gate restoration:** #2382 protected-queue merged as `main@31ac7659b85cce27d31dfa7dcc54537c26e8e15e` without `automerge-force`.
- **Version parity:** #2383 protected-queue merged as `main@8cf204380559d4a997c96ddf6b44ae876dd3eb0d`; merge-group CI `33999592781` passed.
- **Computer-control security restoration:** #2385 restored pre-pause blob `acfc957e0cfd5e0829e23677cf06455abb6b7782` and protected-queue merged as `main@ad9ddc38a99656d0ca09fd196d7ccb162e2a74dd`; merge-group CI `33999910843` passed.
- **Native mobile restoration:** #2386 restored pre-pause blob `371125ec6caeab447d6d8891210b8e24714b1686`; direct/reusable gates and merge-group CI `34000172033` passed; protected main is `46050cdb3cf91c7cdc59548d8153e255c72782ed`.
- **Release/source-contract repair:** #2384 head `37e84bb6409fcf01a25da38bab933ad26119825d`, staging `1.2.32`. Real Electron run `34000293854` passed canonical architecture/version and the complete dependency-free source-contract step, then failed later in packaged App Agent Surface Playwright on a separate stale E2E expectation.
- **Current independent repair:** #2387 is stacked on #2384 only for validation because the active main merge queue is `ALLGREEN`. It changes the stale stable-target E2E expectation, advances to `1.2.33`, and must prove the combined real Electron/security/native-mobile/CI gates before its delta is integrated into #2384 and the combined head enters protected main.

## Product truth

The macOS GitHub Actions machine is only the host environment. The installed Fabushi Test macOS application must be launched and logged into the protected CI test account; only then may the application-owned remote-device supervisor obtain `feature.auth.deviceAgentSession` and register that application with the account-scoped device gateway. `@fabushi test` discovers and controls that newly registered application. KRIS, a pre-online Runner, `interactive-runner`, and a runner-started standalone device agent are forbidden as the device source.

`v1.2.27` is valid Attempt 10 evidence. `v1.2.28` is excluded because it merged/published while Electron was paused. Later governance versions are not interactive candidates until the exact protected-main source has Electron desktop, Computer-control security, Native mobile/catch-all, and canonical CI green and an immutable newer macOS test release exists. Only the newest such release may enter the next interactive attempt.

## Required journey

Start native recording before package installation, install the newest published governed macOS test package, log the protected test account into the App through the bounded CI session mechanism, wait for App-owned device registration, then control that exact App through `@fabushi test` and cover without weakened assertions:

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

The native-helper defect is already in #2381 and must not be duplicated. #2382/#2383/#2385/#2386 restored the real Electron gate, canonical version parity, Computer-control security, and Native mobile through normal protected-main queue.

#2384 owns only the packaged release/source-contract drift. Its real run `34000293854` proves that dependency-free defect now passes and exposes the next independent failure later in real packaged App Agent Surface Playwright.

#2387 owns only that next failure: a test still expected a stale-generation action from a remembered stable `agentId` lease to reject, contradicting #2378's bounded target rebase. The E2E now requires the stable leased target to complete when route/screen/fingerprint are unchanged, then separately requires the same stale generation with a volatile positional ref to reject `stale_app_surface_generation`. No App Agent Surface implementation or safety boundary changes.

Because main's merge queue uses `ALLGREEN`, #2387 is validated as a stacked delta over #2384 rather than weakening or bypassing the queue. It stages `1.2.33`; Android `androidVersionCode=29` and iOS `iosBuildNumber=29` remain unchanged. If the stacked checks are green, #2387's delta is merged into #2384's branch, #2384 is revalidated as the combined head, and only that combined head may enter protected main.

Only after protected main is green may an immutable newest macOS test release be accepted. Native recording must begin before installation; the App must log in and self-register its gateway before `@fabushi test` discovery/control.

## Defect / merge / release loop

Each independent failure gets one atomic PR and one strictly newer comparable staged version. Protected main remains fail-closed: when an earlier unmerged prerequisite is required for a later repair to validate, use stacked PR validation and integrate the atomic delta into the prerequisite branch, then let the combined all-green head enter the protected queue. Never change the ruleset, force merge, or use `automerge-force` to clear a red gate.

## Evidence ledger

- Attempts 1–6: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/README.md`.
- Attempts 7–9: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempts-7-9.md`.
- v1.2.26 exclusion / v1.2.27 release gate: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-release-gate-1.2.27.md`.
- Attempt 10 / v1.2.27 native helper blocker: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempt-10-native-helper.md`.
- Restored Electron / version parity / v1.2.29: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-electron-gate-version-parity-1.2.29.md`.
- Restored Computer-control security / v1.2.30: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-computer-control-security-gate-1.2.30.md`.
- Restored Native mobile / v1.2.31: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-native-mobile-gate-1.2.31.md`.
- Release/source-contract repair / staged v1.2.32: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-electron-gate-release-contract-1.2.32.md`.
- Stable App-target rebase E2E parity / staged v1.2.33: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-stable-rebase-e2e-1.2.33.md`.
