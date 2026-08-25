# 2026-08-25 — Telegram-style Mini Apps Marketplace requirement

## User requirement

Implement and release a Telegram-inspired Mini Apps marketplace inside Fabushi.

Required product behavior:

- Mini Apps can be created/generated through a BotFather-style bot and submitted for marketplace review/publication.
- Approved Mini Apps are searchable/discoverable in the Fabushi marketplace and can be added/installed by users.
- Every Mini App has a default associated bot/conversation identity.
- Users can drive the Mini App through natural language in the bot conversation.
- If the app exposes MCP/CLI commands, `/` command discovery and deterministic slash routing must be available.
- The bot can open the Mini App GUI for manual interaction.
- A Mini App can expose web GUI, remote/local MCP, CLI, WASM or native surfaces; Fabushi is not limited to Telegram-style web-only Mini Apps.
- Official apps such as 全球法布施 must support cross-platform surfaces where available.
- The marketplace service must not host/proxy package bytes. It stores metadata, immutable source references, hashes/sizes and review state; clients download package artifacts directly from GitHub or another approved source.
- Package-backed releases must use immutable source references and integrity verification.
- Mahayana should provide multi-step generation/publishing workflow semantics rather than a one-shot opaque upload.
- The implementation must be merged to canonical `main`, pass repository/product gates, then publish a strictly newer desktop Release with updater metadata and installable artifacts.

## Telegram design learned/adapted

Fabushi adopts the proven Telegram distribution model where the bot is the Mini App identity/launch center and the marketplace/discovery layer helps users find apps, while extending it with local MCP/CLI/native surfaces and source-backed external packages.

Primary upstream references:

- Telegram Mini Apps: https://core.telegram.org/bots/webapps
- Telegram bot/BotFather features: https://core.telegram.org/bots/features

## Fabushi-specific distribution decision

The marketplace API is metadata-only for package distribution. Official seed packages may live on immutable GitHub source/release URLs, but the marketplace backend does not serve package bytes. Runtime installation consumes `mahayana.external-release.v1` metadata and verifies SHA-256/size before local installation.
