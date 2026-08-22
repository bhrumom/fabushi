# GBF-207 Evidence — Electron E2E

Implementation changes update Electron smoke/surface E2E to use the dedicated versioned `window.mahayana` bridge. GitHub Actions / packaged Playwright evidence remains the authority; this task stays IN_PROGRESS until the final jobs and protected-main post-merge verification pass.

## 2026-08-22 failure-artifact diagnosis and product fixes

Electron run #509 / job `Electron Host simulated user smoke` uploaded artifact `electron-runtime-smoke-failure-32565085801-1` (artifact 9473924227). Playwright evidence identified product/E2E defects rather than an IPC/Host crash:

1. Messenger edit used native `window.prompt()`, unsupported by the Electron automation/runtime journey. Replaced with a controlled in-app edit dialog and updated the journey to fill/save it.
2. AI group creation could submit with zero selected Bot members. The Host correctly rejected this (`group chat must contain at least one agent`). The UI now disables group creation until at least one Bot is selected, exposes stable Bot selection identity, and the E2E asserts `Research Bot` is selected before creation.
3. Browser-login helper no longer requires the login gate when the same test profile is already authenticated/ready; it only performs login when the gate is actually visible.
4. Run #510 reached 5/6 journeys and exposed only a Playwright strict-selector collision between the message context-menu `置顶` action and another page-level `置顶` control. The E2E was scoped to the intended context-menu action.
5. Run #511 passed the pin action and advanced to invoice creation, exposing the same native-dialog product defect: invoice title/amount still used `window.prompt()`. That flow is now a real in-app `InvoiceDialog` with stable title/amount inputs, positive-amount validation and a `创建账单` action; E2E uses the same product UI.
6. The temporary one-shot patch workflow removed itself in the same commit after applying the invoice product fix, so no migration-only CI remains in the final diff.

PR #2009 now requires a fresh authoritative CI/Electron/Messaging run on the normal GitHub-authored head. No M2 release claim is valid until that run is green and main is re-read after merge.
