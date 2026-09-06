# Android 1.2.53 packaged WebMCP route blocker — 2026-09-07

## Immutable Android acceptance binding

- Required Android source: `8adfa009f2fdf349e9f0c659fcfa4176ff7d7c2c`.
- Native Android release run/job: `34054334142` / `101543327724`, SUCCESS.
- Release artifact: `9995600366` (`native-android-github-1.2.53-262491916`).
- Immutable tag: `android-v1.2.53-262491916`; tag target is exactly `8adfa009f2fdf349e9f0c659fcfa4176ff7d7c2c`.
- Interactive run/job: `34054727622` / `101544432775`.
- Fresh App-owned device: `gha-34054727622-1-interactive`.

## Real packaged UI evidence before the blocker

1. The freshly registered device immediately projected `grok-bot-global-dharma-bot` from the account-authoritative installed projection.
2. The six external semantic tools `fabushi.app.status/snapshot/find/action/wait/assert` were all called successfully in this run.
3. Marketplace was opened through semantic IDs, query `全球法布施` was entered/submitted, and `plugin-global-dharma` was found.
4. `install-global-dharma` was invoked; `host-status` reached `global-dharma 已安装 · local-web`, and a deterministic `assert` passed.
5. The app returned to Grok/Messenger through semantic `app-shell` + `pressKey BACK`; `grok-bot-global-dharma-bot` remained present.
6. Global Dharma Bot opened as `bot-chat`, with enabled `mobile-bot-open-miniapp`.
7. Natural-language input `please show status now` was sent. The returned assistant log ID ended in `:error`; therefore this WebMCP step is **FAILED**, not accepted.

## Exact live blocker

Independent unauthenticated probes against both canonical endpoints returned `404 Not Found` for:

- `POST https://mahayana-platform.bhrumom.workers.dev/v1/marketplace/plugins/global-dharma/route`
- `POST https://api.ombhrum.com/v1/marketplace/plugins/global-dharma/route`

Live Rust Worker routing on service baseline `cd009f5d42e2493a57b0d21a87d6aa7d5a51411d` registered `/added` and `/add` but not `/route`. This is a canonical control-plane route gap, not an Android package-source mismatch.

## Repair boundary

Branch: `fix/tfi-platform-marketplace-route-20260907` from live service main `cd009f5d42e2493a57b0d21a87d6aa7d5a51411d`.

The minimal repair keeps one WebMCP truth:

- forward D1 migration `0019_marketplace_route_projection.sql` extends the canonical Global Dharma projection with the official `remote-mcp` surface and declared command contract;
- pure Rust route projection/parser handles slash and natural-language resolution;
- authenticated account-installed `POST /v1/marketplace/plugins/:plugin_id/route` dispatches to the existing official MCP endpoint/tool contract;
- production smoke requires direct/public unauthenticated `/route` to fail closed with HTTP 401;
- no Android code, no duplicate Bot, no duplicate MCP server, and no client-local command database are introduced.

Commit / PR / exact-head CI / protected merge / production deployment / rerun artifact are `PENDING` until generated.
