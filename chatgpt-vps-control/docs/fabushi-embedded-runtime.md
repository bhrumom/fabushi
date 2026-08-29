# Fabushi embedded Computer Use runtime

Fabushi desktop packages the clean-room Computer Use implementation as a private, local runtime. The Electron process does not expose a second HTTP service. It starts `bin/fabushi-computer-mcp.js` over stdio through the Mahayana Agent, and that entry registers the same complete tool set used by the standalone connector: application discovery, application-scoped semantic snapshots, screenshots, snapshot diffs, semantic element actions, coordinate fallback, keyboard input, text entry, scrolling, drag, and secondary actions.

## Background operation

The runtime does not depend on the Fabushi window being frontmost. The desktop Host starts independently of renderer visibility. On macOS, the stable signed helper application owns Accessibility and Screen Recording authorization and keeps ScreenCaptureKit window discovery/capture warm; the selected target application may remain behind other windows. Windows uses its persistent native broker and UI Automation/GDI input-capture boundary. Linux uses the available AT-SPI and X11/managed-desktop providers. Operating-system lock-screen, secure-desktop, and permission checks still fail closed.

Each runtime invocation uses a private data directory below the installed Fabushi application's user-data directory. The packaged source and production dependencies live below `resources/computer-control/runtime/<content-id>`; `active-runtime.json` pins the exact `v1-<20 hex>` content identifier selected by Electron; the runtime manifest must carry the matching full SHA-256 source hash and layout version. macOS and Windows native helpers are staged beside that runtime. No OAuth gateway token or public listener is needed for the embedded stdio entry.

Before every tool call, the MCP rereads the Rust Feature Host policy at `feature-host/runtime/settings.json`. The Host persists an explicit default policy during first-run startup. A missing, malformed, incomplete, disabled, or `never` policy fails closed; the stdio process never substitutes an implicit permission.

## Packaging invariant

Every full Electron packager follows the same order:

1. `npm ci --ignore-scripts` in `chatgpt-vps-control`.
2. Build the Rust Host and renderer.
3. Run `bin/prepare-fabushi-bundle.js` with `CHATGPT_COMPUTER_HOME=desktop/resources/computer-control`.
4. Run `electron-builder`, which copies that directory through `build.extraResources`.

The Developer ID release jobs sign the macOS helper with the same stable team identity before Electron seals the application. The Mac App Store job imports its application-distribution identity before staging the helper. Windows stages the PowerShell helper; Linux packages the platform-neutral runtime and uses its system-native providers.

`computer-control-security.yml` validates the stdio entry, runtime integrity/permissions, native brokers, semantic computer behavior, the Mahayana adapter, and the three full packaging workflows. `ci.yml` includes the connector and `mahayana-agent-codex` in its Electron change classifier and sparse source-contract checkout. The macOS hot-overlay workflow treats any connector change as requiring a new full signed package instead of overlaying protected runtime files.

Paired mobile clients receive a separate high-entropy possession token. Only its hash is stored by the Platform Worker, and the token is required to create a control session; account login alone cannot reuse another client ID. The client-token migration revokes legacy pairings and closes their sessions, so users pair once again after deployment.
