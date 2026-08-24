# 2026-08-24 — Telegram-style searchable App Registry and publishing convergence

## User requirement

Fabushi 当前全局搜索的“应用”分类必须能够搜索到已经上架的 App；已有官方 App 不能只存在于旧的静态 Marketplace 清单中。上架流程继续学习并融合 Telegram 的方式：发布后的 App 身份进入统一 Registry，随后自动成为全局搜索的一等结果，而不是要求用户先进入独立插件市场。

## Current gap verified on canonical main

- Desktop global search already has an `apps` category and calls `feature.marketplace.browse`.
- Production `mahayana-app-host` forwards `feature.marketplace.browse` to the Mahayana Product API.
- The Platform Worker public marketplace search only returns D1 `marketplace_plugins` joined with approved immutable `plugin_releases`.
- Twelve Fabushi official apps are still listed in `frontend/apps/web/public/.well-known/mahayana/marketplace.json` and `.agents/plugins/marketplace.json`, but that static listing is not the cloud D1 registry.
- Therefore an app can be described as “上架” by the legacy public catalog while remaining undiscoverable by the production global search.

## Architecture decision for this round

Use one authoritative searchable control plane:

`official plugin source -> verified publish -> cloud Marketplace/App Registry -> global Apps search -> install/open`

The legacy public catalog remains a compatibility/publication input and human-readable catalog; it must not become a second runtime search database and clients must not restore a bundled `defaultMiniApps` list.

## Telegram upstream study

The implementation follows the architectural lesson from Telegram Desktop rather than copying code: Apps are first-class discovery/search entities, while installation/opening remains a controlled runtime action. Upstream evidence inspected includes `telegramdesktop/tdesktop` App/WebView handling, top-peers data, and MTProto schema definitions.

Fabushi-specific extension: a Registry entry can represent a Mini App, Agent/Bot-facing application, Connector/MCP surface, or a combination through one identity and capability model.

## Required delivery

1. Every official plugin listed for publication has a normalized searchable identity and category metadata.
2. CI rejects drift between source plugins, public catalog, and the official Registry publication matrix.
3. A protected main workflow publishes/backfills official apps into the production cloud Marketplace with immutable artifacts and provenance.
4. Existing approved entries are idempotently skipped; immutable versions are never overwritten.
5. Production global Apps search discovers approved official apps through the same `feature.marketplace.browse` path used for third-party apps.
6. Search acceptance covers at least one current official app before install, then install and open.
7. Publishing/search evidence is retained in Actions artifacts and project evidence.
