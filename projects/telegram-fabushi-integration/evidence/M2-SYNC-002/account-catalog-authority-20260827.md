# M2-SYNC-002 account Mini App catalog authority — 2026-08-27

Fifth exact-main Electron run `33027760877` on `fdb24deedc2973e817efb645e60f67a61b6d52a4` still stopped at the single `/` command-menu assertion. Diagnostic artifact `9629100578` shows the synchronized Global Dharma Bot is open correctly, but the Messenger identity catalog still lacks its command declarations.

The previous fix made `miniAppBotProjection()` understand canonical top-level Marketplace metadata, but the renderer's identity catalog is still primarily sourced from Feature Host discovery. The account-authoritative endpoint `/v1/marketplace/added` already rejoins installed Mini App ids to full Marketplace manifests in production and is therefore the correct cross-device identity/command source for installed apps.

This repair makes Messenger merge `getAccountMiniApps()` into the identity catalog with account metadata taking precedence for installed apps, aligns the deterministic test platform snapshot so it includes commands, and adds fast contract/test coverage for the account-catalog path.
