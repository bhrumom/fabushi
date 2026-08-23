# FCM-008 evidence — latest macOS build

## Build source

- Canonical main SHA: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`
- Workflow: `Electron desktop quality gate`
- Workflow run: `32619314508`

## Round 1 result

The manual workflow dispatch used the exact canonical main SHA. Preflight architecture, Feature Host bridge, desktop architecture, browser login, BotMark, product UI, native capability, Electron edge/host lifecycle/offline-ASR checks all passed. Linux Host binary reuse also succeeded.

The real Electron user smoke failed before packaging, so GitHub correctly skipped all package jobs. No macOS artifact was produced and no download link is claimed from this run.

Deterministic blockers from the Playwright failure evidence:

1. `desktop Messenger persists per-peer drafts and performs real in-conversation search` — the unique sent marker rendered in two message `<article>` nodes while the contract expects one; retry reproduced the duplicate.
2. `desktop Messenger rejects self-hosted actor impersonation at the real Host boundary` — a renderer-supplied forged envelope actor ID was accepted, so the expected Host authorization error was not returned.

These are Messaging product blockers and are handed to the existing FAB-P0001 / TFI project for repair. FCM-008 remains `in-progress`; packaging will be re-run only after the protected product fix reaches canonical main.
