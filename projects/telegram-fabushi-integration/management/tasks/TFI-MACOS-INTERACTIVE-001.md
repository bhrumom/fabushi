# TFI-MACOS-INTERACTIVE-001 — macOS App-owned interactive E2E loop

- **Project ID:** `FAB-P0001`
- **Project Key:** `TFI`
- **Task ID:** `TFI-MACOS-INTERACTIVE-001`
- **Scope:** cross-stage macOS desktop acceptance for current declared M3–M12 capabilities
- **Status:** `TESTING`
- **Latest governed macOS test release actually tested:** `v1.2.27` -> `ecebd0373c158c6eb8ee225ac184cc3ca2e9e6dc`.
- **Attempt 10:** run `33975902199`, App-owned device `gha-33975902199-1-macos-app`; stable App-target rebase passed, then native Computer Use failed because the direct App-owned MCP lost the package-derived `Fabushi Computer Control.app` helper environment.
- **Live reconciliation:** PR `#2381` was already merged as `main@36868f9c5ba389c6b627f93f792ce9a7d52192e3` before this continuation and immutable prerelease `v1.2.28` already existed, but its merge/publish happened while the canonical Electron quality gate was paused. It is not a post-restoration acceptance candidate.
- **Electron gate restoration:** PR `#2382` restored the exact pre-pause Electron workflow and protected-queue merged as `main@31ac7659b85cce27d31dfa7dcc54537c26e8e15e` without `automerge-force`.
- **Version-parity repair:** PR `#2383` protected-queue merged as `main@8cf204380559d4a997c96ddf6b44ae876dd3eb0d`; merge-group CI `33999592781` passed.
- **Computer-control security gate restoration:** PR `#2385` restored exact pre-pause blob `acfc957e0cfd5e0829e23677cf06455abb6b7782` and protected-queue merged as `main@ad9ddc38a99656d0ca09fd196d7ccb162e2a74dd`; merge-group CI `33999910843` passed.
- **Current independent blocker:** release-contract PR `#2384`; restored Electron run `33999715376`, Linux job `101396275595`, reached dependency-free contracts and exposed stale packaged-release/source-test assumptions. PR #2384 has absorbed latest protected main and now stages strictly newer `1.2.31`.

## Product truth

The macOS GitHub Actions machine is only the host environment. The installed Fabushi Test macOS application must be launched and logged into the protected CI test account; only then may the application-owned remote-device supervisor obtain `feature.auth.deviceAgentSession` and register that application with the account-scoped device gateway. `@fabushi test` discovers and controls that newly registered application. KRIS, a pre-online Runner, `interactive-runner`, and a runner-started standalone device agent are forbidden as the device source.

`v1.2.26` remains excluded from acceptance because its release run started before the canonical protected-main source gate was restored. `v1.2.27` is valid evidence for Attempt 10. `v1.2.28` is excluded because it merged/published while the Electron quality gate was paused. `v1.2.29` and `v1.2.30`, if published, are intermediate governance releases while later restored gates remained red. The next acceptable candidate must be the newest strictly newer protected-main release whose exact source has the restored Electron and Computer-control security gates green.

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

The App-owned native-helper propagation defect from Attempt 10 landed in #2381 and must not be duplicated. PRs #2382/#2383/#2385 restored the real Electron gate, canonical version parity, and full Computer-control security gate through protected merge queue.

PR #2384 owns only the remaining packaged-release source-contract drift. It keeps all actual packagers under explicit Computer Use install/stage/sign/verify assertions, makes the Native Electron release install step auditable with `working-directory: chatgpt-vps-control`, updates obsolete unified-release assertions to the live tiered canonical protected-main source gate and immutable prerelease policy, and explicitly verifies that the superseded macOS hot-package workflow is paused/manual rather than treating it as a full packager. The repaired full Computer-control security workflow and fail-closed platform assertions remain required.

Because `1.2.30` belongs to the independent security-gate repair, PR #2384 now stages `1.2.31`. Android `androidVersionCode=29` and iOS `iosBuildNumber=29` remain unchanged. No branch-protection rule, security assertion, application behavior, account/session parser, App-owned gateway path, remote-control opt-in rule, or Computer Use safety rule is weakened.

The PR must pass the restored real Electron PR gate and restored security gate, then protected merge normally. Only the newest immutable protected-main release whose exact source has those restored gates green may enter Attempt 11. Native recording must begin before installation; the App must log in and self-register its device gateway before `@fabushi test` is used for discovery/control.

## Defect / merge / release loop

Each independent product or release-governance failure gets one defect PR, protected-main merge, strictly newer comparable governed macOS test version, then full retest of that newest package. Do not close this task until the full journey and evidence gate are green.

## Evidence ledger

- Attempts 1–6: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/README.md`.
- Attempts 7–9: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempts-7-9.md`.
- v1.2.26 exclusion / v1.2.27 release gate: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-release-gate-1.2.27.md`.
- Attempt 10 / v1.2.27 native helper blocker: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-05-attempt-10-native-helper.md`.
- Restored Electron gate / version-parity failure / v1.2.29 repair: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-electron-gate-version-parity-1.2.29.md`.
- Restored Computer-control security gate / v1.2.30 repair: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-computer-control-security-gate-1.2.30.md`.
- Restored Electron gate / packaged-release source-contract repair / v1.2.31: `projects/telegram-fabushi-integration/evidence/TFI-MACOS-INTERACTIVE-001/2026-09-06-electron-gate-release-contract-1.2.31.md`.
