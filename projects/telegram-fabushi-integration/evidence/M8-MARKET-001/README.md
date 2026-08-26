# M8-MARKET-001 evidence index

## Scope

Telegram-style Mini Apps marketplace registry/developer-flow delivery for `FAB-P0001 / TFI`.

## Pre-merge implementation evidence

- Feature branch: `feat/tfi-m8-telegram-miniapp-market`
- Implementation/search/runtime fix head before governance updates: `7a35a8876e9dd7747a32f070439c66635335319c`
- Source requirement persistence: `d715b5f12433d51472a86df4e94d958f1273e95e`
- Task record: `projects/telegram-fabushi-integration/management/tasks/M8-MARKET-001-telegram-miniapp-marketplace.md`
- Runtime code: `ai-backend/src/miniapp_marketplace*.js`, `ai-backend/src/secure-entry.js`
- Contract tests: `ai-backend/test/miniapp_marketplace.test.js`, `ai-backend/test/miniapp_marketplace_http.test.js`

## Distribution evidence

Official package-backed releases resolve to immutable GitHub raw URLs pinned to source commit `a76587178c6b63be7963f14deb550e00bb0a425e`, with exact SHA-256 and byte size in release metadata. Marketplace release metadata reports `marketplaceHostsPackage: false`; package bytes are downloaded directly from the source URL by the client/runtime rather than proxied by the marketplace API.

## Pending evidence

This index is intentionally not marked complete yet. Add the following after they exist:

- PR number and final PR head SHA;
- required current-head GitHub Actions runs/checks;
- protected merge SHA and canonical-main readback;
- exact-main packaged Electron/mobile E2E run IDs and visual evidence artifact references;
- new GitHub Release tag/version, target SHA, and updater/installable assets.
