# M8-MARKET-001 — Telegram-style Mini Apps marketplace

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-MARKET-001`
- **Stage**: `M8 Mini Apps`
- **WBS**: `M8.T06`–`M8.T07`
- **Status**: `IMPLEMENTED`
- **Started**: `2026-08-25`
- **Branch**: `feat/tfi-m8-telegram-miniapp-market`
- **Source requirement**: `../../source/2026-08-25-telegram-miniapp-marketplace.md`

## Scope

Deliver a Telegram-inspired but Fabushi-extended marketplace in which Mini Apps are discoverable through a searchable registry, generated/published through a BotFather-style flow, associated with a default bot, controllable through natural language or slash commands, and able to expose GUI/MCP/CLI/WASM/native surfaces.

Package distribution remains source-backed: marketplace metadata references immutable GitHub/HTTPS artifacts and never proxies package bytes.

## Reused foundation / open-source-first decision

- Telegram BotFather + Mini Apps distribution is used as the product/discovery reference: bot identity is the app launch center and the marketplace is the discovery layer.
- Existing Mahayana `mahayana.external-release.v1` and `PluginInstaller` are reused for source-backed immutable artifact metadata, SHA-256/size verification and local installation instead of inventing a parallel package protocol.
- Existing Fabushi unified Messenger/Mini App routing and marketplace install/open surfaces remain the product edge; this task does not create a second chat/runtime stack.

## Implemented surface

- `ai-backend/src/miniapp_marketplace.js`: v2 manifest/domain/store, review state, add/remove, search ranking, commands and Mahayana generation workflow.
- `ai-backend/src/miniapp_marketplace_catalog.js`: discovery guard, official app catalog, immutable GitHub package sources and `mahayana.external-release.v1` release metadata.
- `ai-backend/src/miniapp_marketplace_http.js`: marketplace browse/release/add/remove/route/publisher/BotFather HTTP routes.
- `ai-backend/src/miniapp_marketplace_mcp.js`: bot/MCP control surface.
- `ai-backend/src/miniapp_marketplace_bootstrap.js`: runtime route registration before backend listen.
- Official seed package metadata uses immutable GitHub raw source URLs, exact SHA-256 and byte size; API reports `marketplaceHostsPackage: false`.
- `ai-backend/test/miniapp_marketplace.test.js` and `ai-backend/test/miniapp_marketplace_http.test.js` cover manifest/store/search/review/add/release/bot routing and developer flow behavior.

## Acceptance criteria

1. Approved apps are discoverable by real textual matches; unrelated popularity does not make a result match.
2. Marketplace release metadata uses `mahayana.external-release.v1` and points to external immutable package sources where package installation is required.
3. Marketplace backend does not host/proxy package bytes.
4. Adding an app exposes its default bot identity and command routing.
5. `/app:command` routes deterministically to the declared surface; natural-language input yields a Mahayana-planning route when appropriate.
6. BotFather generation returns the versioned multi-step Mahayana generation workflow.
7. Draft → pending review → approved controls global discovery.
8. Current-head GitHub CI for the PR must pass before merge.
9. The implementation must merge to canonical `main`, be re-read there, then pass the exact-main packaged/E2E delivery gates.
10. A strictly newer GitHub Desktop Release with updater metadata must target the accepted canonical `main` SHA.

## Objective verification

- `npm run check` in `ai-backend` through GitHub Actions.
- `npm test` / repository CI including `miniapp_marketplace*.test.js` through GitHub Actions.
- Required repository/product gates on the PR head.
- Canonical-main post-merge desktop/mobile packaged E2E workflow evidence.
- GitHub Release tag/assets/target SHA verification after publication.

## Current evidence

- Feature branch implementation head before governance updates: `7a35a8876e9dd7747a32f070439c66635335319c`.
- Search-match/runtime-import fix: `7a35a8876e9dd7747a32f070439c66635335319c`.
- Source requirement persistence commit: `d715b5f12433d51472a86df4e94d958f1273e95e`.

## Completion rule

Keep this task below `RELEASED` until the task PR is merged to canonical `main`, exact-main required packaged/E2E evidence is green, a newer Release is published for that main SHA, and the final evidence is written back to this project folder on canonical `main`.
