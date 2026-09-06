# TFI-DESKTOP-INTERACTIVE-RELEASE-SELF-START-001

- Project: `FAB-P0001 / TFI`
- Status: `IN_PROGRESS`
- Discovery baseline: protected `main@89922b7907d80d0840da5f394444a4affcbe45f4`

## Problem

The exact-main Electron/Native/security/post-main chain can publish an immutable `desktop-*` Release for a main change that does not touch the path filters of the Windows/macOS interactive workflows. In that case no current-SHA desktop interactive run exists. Manual `workflow_dispatch` is not a reliable delivery dependency and can be unavailable in the automation control plane.

## Minimal repair

- Make Windows and macOS interactive workflows self-start on GitHub `release: published`.
- Keep `workflow_dispatch` for governed manual recovery.
- Remove path-filtered `push` from these two production interactive workflows so one main delivery does not create both a pre-release waiting run and a second release-triggered run.
- At job entry, accept only `desktop-*` release events; Native Android/iOS releases are ignored.
- Preserve exact-SHA release resolution, digest verification, install-before-login ordering, App-owned registration, complete semantic journey, full-session recording and always-upload evidence gates.
- Extend dependency-free workflow contracts to prevent regression to path-filtered push or unscoped release events.

## Acceptance

1. Required PR CI passes and normal protected merge completes.
2. Re-read the new canonical main; only that SHA or later protected main is final-acceptance eligible.
3. Exact-main Electron/Native/security pass and post-main publishes an immutable `desktop-*` Release targeting the same SHA.
4. That Release automatically starts both Windows and macOS interactive workflows from the default-branch workflow source; each run resolves the same target SHA and installs only that Release.
5. Each interactive run reaches App-owned registration and completes the declared semantic matrix including final logout; always-upload evidence contains whole-session video, step screenshots, device-call trace, packaged Playwright report/trace/video/results, App/system logs and Release metadata/digests.
6. Final Global Dharma packaged evidence remains required on Linux/Windows/macOS: Marketplace search/install, Bot, natural-language WebMCP, Open App Web UI, Bot/UI durable revision parity, Fabushi account projection, CNY1080 sandbox lifetime purchase/restore, restart/logout durability.

No local build/test is permitted; GitHub Actions remains the execution gate.
