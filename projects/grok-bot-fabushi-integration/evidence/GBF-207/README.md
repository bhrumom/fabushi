# GBF-207 Evidence — Electron E2E

Implementation changes update Electron smoke/surface E2E to use the dedicated versioned `window.mahayana` bridge. GitHub Actions / packaged Playwright evidence is pending on the M2 PR; this task remains IN_PROGRESS until those jobs and protected-main post-merge verification pass.

## 2026-08-22 failure artifact diagnosis and fix

Electron run #509 / job `Electron Host simulated user smoke` uploaded artifact `electron-runtime-smoke-failure-32565085801-1` (artifact 9473924227). Playwright evidence identified two product/E2E defects rather than an IPC/Host crash:

1. Messenger edit used native `window.prompt()`, which Electron automation explicitly reports as unsupported. Replaced with a controlled in-app edit dialog and updated the journey to fill/save it.
2. AI group creation could submit with zero selected Bot members. The Host correctly rejected this (`group chat must contain at least one agent`). The UI now disables group creation until at least one Bot is selected, exposes stable Bot selection identity, and the E2E asserts `Research Bot` is selected before creation.
3. Browser-login helper no longer requires the login gate when the same test profile is already authenticated/ready; it only performs login when the gate is actually visible.

PR #2009 reruns the authoritative Electron smoke with retained failure artifacts if anything remains.
