PRAGMA foreign_keys = ON;

-- Official Global Dharma paid capability catalog. Product and price data live in
-- the canonical Mahayana PLATFORM_DB so every client sees server-authoritative
-- amounts. Mobile store rails are intentionally not enabled here until the
-- corresponding App Store / Play Console product identifiers exist.

CREATE TABLE IF NOT EXISTS monetization_product_terms (
    product_id TEXT PRIMARY KEY REFERENCES products(product_id) ON DELETE RESTRICT,
    entitlement_duration_seconds INTEGER,
    lifetime INTEGER NOT NULL DEFAULT 0 CHECK (lifetime IN (0, 1)),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    CHECK (
        (lifetime = 1 AND entitlement_duration_seconds IS NULL)
        OR
        (lifetime = 0 AND entitlement_duration_seconds IS NOT NULL AND entitlement_duration_seconds > 0)
    )
);

INSERT OR IGNORE INTO products
    (product_id, plugin_id, sku, seller_user_id, entitlement_capability,
     consumption_mode, active, created_at, updated_at)
VALUES
    ('official.global-dharma:local-prayer-wheel-monthly',
     'official.global-dharma',
     'local-prayer-wheel-monthly',
     NULL,
     'local.prayer-wheel.start',
     'durable', 1, unixepoch(), unixepoch()),
    ('official.global-dharma:local-prayer-wheel-lifetime',
     'official.global-dharma',
     'local-prayer-wheel-lifetime',
     NULL,
     'local.prayer-wheel.start',
     'durable', 1, unixepoch(), unixepoch());

INSERT OR IGNORE INTO prices
    (price_id, product_id, currency, amount, active, starts_at, ends_at, created_at)
VALUES
    ('official.global-dharma:local-prayer-wheel-monthly:cny',
     'official.global-dharma:local-prayer-wheel-monthly',
     'CNY', 3000, 1, unixepoch(), NULL, unixepoch()),
    ('official.global-dharma:local-prayer-wheel-lifetime:cny',
     'official.global-dharma:local-prayer-wheel-lifetime',
     'CNY', 108000, 1, unixepoch(), NULL, unixepoch());

INSERT OR IGNORE INTO payment_product_config
    (product_id, developer_id, product_kind, platform_fee_bps,
     allowed_rails_json, provider_product_refs_json, active, created_at, updated_at)
VALUES
    ('official.global-dharma:local-prayer-wheel-monthly',
     'fabushi-official',
     'subscription',
     10000,
     '["web_provider","merchant_provider"]',
     '{"web_provider":"global-dharma-prayer-wheel-monthly","merchant_provider":"global-dharma-prayer-wheel-monthly"}',
     1, unixepoch(), unixepoch()),
    ('official.global-dharma:local-prayer-wheel-lifetime',
     'fabushi-official',
     'digital_durable',
     10000,
     '["web_provider","merchant_provider"]',
     '{"web_provider":"global-dharma-prayer-wheel-lifetime","merchant_provider":"global-dharma-prayer-wheel-lifetime"}',
     1, unixepoch(), unixepoch());

INSERT OR IGNORE INTO monetization_product_terms
    (product_id, entitlement_duration_seconds, lifetime, created_at, updated_at)
VALUES
    ('official.global-dharma:local-prayer-wheel-monthly', 2592000, 0, unixepoch(), unixepoch()),
    ('official.global-dharma:local-prayer-wheel-lifetime', NULL, 1, unixepoch(), unixepoch());
