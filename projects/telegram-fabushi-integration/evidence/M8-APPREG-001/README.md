# Evidence — M8-APPREG-001

## Baseline

- Canonical project: `FAB-P0001` / `projects/telegram-fabushi-integration`.
- Branch: `feat/tfi-m8-app-registry-search-publishing`.
- Baseline main SHA at branch creation: `92deb4dd63efae607b54d14e9e83750248b74a4f`.
- Existing global Apps search path: renderer -> `feature.marketplace.browse` -> Rust AppHost -> Product API.
- Existing cloud search authority: Platform Worker D1 `marketplace_plugins` + approved immutable `plugin_releases`.
- Legacy official catalogs enumerate 12 apps but are not the D1 search index.

## Open-source-first evidence

Canonical upstream inspected: `telegramdesktop/tdesktop`.

Relevant architecture surfaces:
- `Telegram/SourceFiles/inline_bots/bot_attach_web_view.cpp`
- `Telegram/SourceFiles/data/components/top_peers.cpp`
- `Telegram/SourceFiles/mtproto/scheme/api.tl`

Decision: reuse the architecture principle that Apps are first-class search/discovery entities; do not copy Telegram code or depend on Telegram APIs.

## Acceptance evidence to append

- contract validator result
- official Registry sync dry-run result
- PR number and current-head SHA
- required CI run IDs
- protected merge SHA
- production Registry query results for official apps
- canonical-main Electron E2E screenshots/video/trace
- packaged build/Release tag and assets

Task remains `IN_PROGRESS` until all required evidence above is present.
