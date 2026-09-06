# TFI-DESKTOP-EXACT-RELEASE-BINDING-001 — exact-main desktop interactive Release binding

- Project: FAB-P0001 / TFI
- Status: in-progress
- Current baseline: `main@113379cb2313e03a7a90d397da2da2f1918b5de3`
- Branch: `fix/tfi-windows-interactive-exact-release-binding-20260907`
- Source: `projects/telegram-fabushi-integration/source/2026-09-07-desktop-interactive-exact-main-release-binding.md`

## Objective

Make both Windows and macOS App-owned interactive workflows install only a published platform Release whose resolved target commit equals the workflow's exact `GITHUB_SHA`. The jobs may wait a bounded period for post-main publication, but must never fall back to an older globally newest installer/archive.

## Acceptance

- [ ] Windows dependency-free contract rejects global-newest fallback and requires exact `GITHUB_SHA` release binding plus bounded waiting.
- [ ] macOS dependency-free contract rejects global-newest fallback and requires exact `GITHUB_SHA` release binding plus bounded waiting.
- [ ] Required PR checks pass.
- [ ] PR merges through protected main / merge queue.
- [ ] New canonical main automatically runs Windows and macOS interactive because their workflow files changed.
- [ ] Both new runs record `workflowSourceSha == releaseTargetSha` before installation.
- [ ] Installed Apps log in with bounded CI sessions and self-register only their new App-owned devices.
- [ ] Six `fabushi.app.*` semantic tools, complete journeys, and final logout succeed on both desktop interactive runs.
- [ ] Whole-session video, step screenshots, device trace, report, App/system logs, Playwright report/test-results and Release metadata are uploaded on the exact accepted SHA.
- [ ] Electron exact-main packaged Global Dharma journey passes and its video/screenshots/trace/report are uploaded.
- [ ] Current-SHA Native mobile checks pass.
- [ ] Current-SHA post-main source binding and Release publication succeed; older SHA evidence does not close this task.

## Evidence so far

- Historical diagnostic only: Windows run `34059848147` on `ee8cd4b3…` installed `desktop-1.2.21-4bc3e832fffe` -> `4bc3e832…` and failed App-owned registration. Artifact `9997183366` proves the mismatch but is not final acceptance evidence.
- Current main `113379cb…` exact-main Electron run: `34060359321` (running at task start).
- Current main `113379cb…` exact-main Native run: `34060359323` (running at task start).

## Implementation boundary

- Workflow/control-plane only; no product runtime semantics are changed.
- Preserve recording-before-install, digest/signature checks, protected-account login, refresh-token-free App projection, App-owned device registration, semantic-tool gates, logout ordering, and always-upload evidence.
- Exact Release wait is bounded to 20 minutes with 15-second polling; absence of a same-SHA Release fails closed.

## Next action

Run required PR CI, protect-merge, then validate the resulting canonical main end-to-end with exact-main Electron/Native/interactive/post-main/Release evidence.