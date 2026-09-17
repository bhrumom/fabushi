# TFI-MACOS-INTERACTIVE-001 — single post-release interactive trigger

- Baseline: protected `main@d3fe6a9b7d9eff6ccdd307ef23123ab5eda67639`.
- The interactive workflow currently has both a direct `release: prereleased` trigger and a `workflow_dispatch` entrypoint.
- `macos-interactive-release-chain.yml` separately listens for the completed `Native Electron macOS test release` workflow and dispatches the same interactive workflow only when that release workflow succeeds.
- Keeping both paths can start duplicate 55-minute App-owned macOS lanes for one prerelease and allows the direct release event to race the release workflow's final evidence step.

## Atomic correction

Remove only the direct `release: prereleased` trigger from `macos-interactive-app-e2e.yml`. Preserve the push bootstrap paths and `workflow_dispatch`. The authoritative release path becomes: protected main -> successful Native Electron macOS test release -> release-chain workflow -> exactly one interactive dispatch. No device, evidence, truth-gate, login, recording, or App-owned registration rule is weakened.
