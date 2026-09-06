# TFI-MACOS-INTERACTIVE-001 — macOS App-owned interactive E2E loop

- **Project ID:** `FAB-P0001`
- **Project Key:** `TFI`
- **Task ID:** `TFI-MACOS-INTERACTIVE-001`
- **Scope:** cross-stage macOS desktop acceptance for current declared M3–M12 capabilities
- **Status:** `TESTING`
- **Latest governed macOS test release actually tested:** `v1.2.27` -> `ecebd0373c158c6eb8ee225ac184cc3ca2e9e6dc`.
- **Attempt 10:** run `33975902199`, App-owned device `gha-33975902199-1-macos-app`; stable App-target rebase passed, then native Computer Use failed because the direct App-owned MCP lost the package-derived `Fabushi Computer Control.app` helper environment.
- **Live reconciliation:** #2381 was already merged as `main@36868f9c5ba389c6b627f93f792ce9a7d52192e3`; `v1.2.28` exists but was published while the Electron gate was paused, so it is excluded from resumed acceptance.
- **Electron gate restoration:** #2382 protected-queue merged as `main@31ac7659b85cce27d31dfa7dcc54537c26e8e15e` without `automerge-force`.
- **Version-parity repair:** #2383 protected-queue merged as `main@8cf204380559d4a997c96ddf6b44ae876dd3eb0d`; merge-group CI `33999592781` passed.
- **Computer-control security gate restoration:** #2385 restored exact pre-pause blob `acfc957e0cfd5e0829e23677cf06455abb6b7782` and protected-queue merged as `main@ad9ddc38a99656d0ca09fd196d7ccb162e2a74dd`; merge-group CI `33999910843` passed.
- **Native mobile restoration:** #2386 restored exact pre-pause blob `371125ec6caeab447d6d8891210b8e24714b1686`; direct Native mobile and reusable catch-all PR gates passed, merge-group CI `34000172033` passed, and protected main is `46050cdb3cf91c7cdc59548d8153e255c72782ed`.
- **Release-contract PR:** #2384 remains open for its single packaged-release/source-contract drift. Its latest Electron run `34000293854` passed dependency-free source contracts and reached the real packaged App Agent Surface Playwright journey.
- **Current independent blocker:** Electron Linux job `101397827616` found a stale E2E expectation: the test still requires a remembered stable `agentId` action on a stale generation to reject, contradicting #2378's bounded stable-target rebase contract. Branch `fix/tfi-electron-stable-rebase-e2e-1-2-32-20260906` owns only that E2E parity defect and stages `1.2.32`; build counters remain `29`.

## Product truth

The macOS GitHub Actions machine is only the host environment. The installed Fabushi Test macOS application must be launched and logged into the protected CI test account; only then may the application-owned remote-device supervisor obtain `feature.auth.deviceAgentSession` and register that application with the account-scoped device gateway. `@fabushi test` discovers and controls that newly registered application. KRIS, a pre-online Runner, `interactive-runner`, and a runner-started standalone device agent are forbidden as the device source.

`v1.2.27` is valid Attempt 10 evidence. `v1.2.28` is excluded because it merged/published while Electron was paused. Later governance versions are intermediate until the exact protected-main source has Electron desktop, Computer-control security, and Native mobile gates green. Only the newest such immutable release may enter the next interactive attempt.

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

The native-helper defect is already in #2381 and must not be duplicated. #2382/#2383/#2385/#2386 restored Electron, canonical version parity, Computer-control security, and Native mobile through normal protected merge queue. PR #2384 still owns only its release-contract drift.

The current independent PR changes only the packaged App Agent Surface E2E expectation that contradicts the already-landed #2378 bounded stable-target rebase. A stale action from a remembered stable-target lease must succeed only when route/screen/fingerprint are unchanged and no volatile positional ref is supplied; the same stale generation with a volatile ref must still fail closed. No App Agent Surface implementation or safety boundary changes. This repair stages `1.2.32`. After protected merge, #2384 must absorb latest main, advance to the next strictly newer version, and rerun its own restored gates.

Native recording must begin before installation; the App must log in and self-register its device gateway before `@fabushi test` is used for discovery/control.

## Defect / merge / release loop

Each independent product or release-governance failure gets one defect PR, protected-main merge, strictly newer comparable governed macOS test version, then full retest of that newest package. Do not close this task until the full journey and evidence gate are green.

## Evidence ledger

- Attempts 1–6: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/README.md`.
- Attempts 7–9: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempts-7-9.md`.
- v1.2.26 exclusion / v1.2.27 release gate: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-release-gate-1.2.27.md`.
- Attempt 10 / v1.2.27 native helper blocker: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempt-10-native-helper.md`.
- Restored Electron gate / version-parity / v1.2.29: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-electron-gate-version-parity-1.2.29.md`.
- Restored Computer-control security gate / v1.2.30: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-computer-control-security-gate-1.2.30.md`.
- Restored Native mobile quality gate / v1.2.31: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-native-mobile-gate-1.2.31.md`.
- Packaged stable App-target rebase E2E parity / v1.2.32: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-stable-rebase-e2e-1.2.32.md`.
