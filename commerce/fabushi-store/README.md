# Fabushi Store — standalone commerce site

Fabushi Store is a normal public DTC website first. A customer can discover it from Google, advertising, a direct URL, or any browser and finish shopping without installing Fabushi. Listing the same site in the Fabushi Mini App marketplace adds an optional Bot/WebMCP/MCP control plane over the same Medusa catalog, cart, checkout, and order state.

## Open-source foundation

This site is materialized from Medusa's official `medusajs/dtc-starter`, pinned in `upstream.lock.json`. The pinned upstream is MIT licensed and includes a Medusa v2 backend and a Next.js storefront with catalog, variants, cart, checkout, accounts, and order management. We intentionally use an overlay instead of copying and drifting a private fork: the exact upstream commit is cloned, then files under `overlay/` are applied on top.

The archived `medusajs/nextjs-starter-medusa` was rejected because the official project has moved to DTC Starter.

## Runtime model

```text
Browser / search / ads
        |
        v
https://shop.ombhrum.com  -----------+
        |                              |
        | normal storefront            | Fabushi MiniApp web surface
        v                              |
Medusa Store API <---------------------+
        ^
        |
Fabushi Bot / WebMCP / MCP
        |
        +-- search_products
        +-- get_product
        +-- create_cart
        +-- get_cart
        +-- add_to_cart
        +-- remove_from_cart
        +-- prepare_checkout
        +-- place_order (host confirmation required)
```

The AI adapter never owns a second product, cart, price, or order database. It calls Medusa's Store API. `prepare_checkout` returns a signed-by-possession cart handoff URL that places the Medusa cart id into the normal storefront cookie and redirects the user to the ordinary checkout UI. Address, shipping, provider payment, and final order completion therefore stay compatible with the browser flow.

## Materialize

```bash
bash commerce/fabushi-store/scripts/materialize.sh /tmp/fabushi-store
cd /tmp/fabushi-store
pnpm install --frozen-lockfile
```

The script verifies that the checked-out upstream commit exactly matches `upstream.lock.json` before applying the overlay.

## Required production configuration

Backend: PostgreSQL 15+, Redis, `DATABASE_URL`, `REDIS_URL`, strong `JWT_SECRET` and `COOKIE_SECRET`, plus CORS for `https://shop.ombhrum.com`.

Storefront: `NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://shop-api.ombhrum.com`, a Medusa publishable API key, `NEXT_PUBLIC_BASE_URL=https://shop.ombhrum.com`, and the payment provider's public key when a card provider is enabled.

No provider secret is committed here. Without a configured real payment provider, the site may be used for catalog/cart/checkout validation but must not be represented as charging real cards.

## Fabushi discovery

The public site publishes `/.well-known/fabushi.json`. Fabushi's built-in approved listing is `fabushi-store`, with its `web` surface pointing at the independent site and its `mcp-http` surface pointing at `/api/fabushi/mcp` on the same site.
