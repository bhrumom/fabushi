# M8-DL-001 Change Record — Independent Package

- Date: `2026-08-26`
- Project: `FAB-P0001 / TFI`
- Task: `M8-DL-001`

## Requirement change

User changed the delivery boundary from an application-specific `ai-backend` feature to an independent installable and migratable Mini App.

## Architecture change

Previous prototype:

`Fabushi ai-backend -> Downloader-specific routes/runtime -> Web UI`

Accepted target:

`Marketplace metadata -> immutable Mini App package -> Mahayana installer -> GUI / CLI / stdio MCP -> shared official-miniapps Rust runtime`

## Repository changes

- Removed app-specific `ai-backend/src/douyin_downloader.js` and its test.
- Restored generic-only `miniapp_marketplace_http.js`.
- Added/preserved package at `marketplace/packages/douyin-batch-downloader/1.0.0/`.
- Added/preserved `.mahayana`, `.mcp.json`, `.codex-plugin` descriptors.
- Added/preserved Rust `official-miniapps` provider implementation.
- Added independent-boundary CI.
- Removed duplicate imported `FAB-P0009 / DBD`; canonical ownership remains `FAB-P0001 / TFI`.

## Compatibility / migration meaning

The Mini App is portable between compatible Fabushi/Mahayana hosts through the same immutable package/release contract. The current package uses the compatible Host's shared `official-miniapps` runtime and is therefore not represented as a standalone binary that works without Mahayana.

## Completion impact

This is product-affecting work. Current-head CI, protected-main merge, canonical-main package/E2E evidence, and GitHub Release remain mandatory before closure.
