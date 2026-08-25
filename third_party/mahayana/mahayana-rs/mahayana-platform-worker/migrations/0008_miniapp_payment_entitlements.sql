PRAGMA foreign_keys = ON;

-- Generic Mini App capability plans. Prices and entitlement terms are copied
-- into each Payment Intent so a later catalog edit cannot mutate an existing
-- order. A NULL duration is a lifetime entitlement; subscriptions use a fixed
-- 30-day period (Telegram Stars-compatible period semantics).
ALTER TABLE payment_product_config ADD COLUMN display_name TEXT NOT NULL DEFAULT '';
ALTER TABLE payment_product_config ADD COLUMN description TEXT NOT NULL DEFAULT '';
ALTER TABLE payment_product_config ADD COLUMN entitlement_duration_seconds INTEGER;
ALTER TABLE payment_product_config ADD COLUMN billing_period_seconds INTEGER;

ALTER TABLE payment_intents ADD COLUMN entitlement_duration_seconds INTEGER;
ALTER TABLE payment_intents ADD COLUMN billing_period_seconds INTEGER;

CREATE TABLE IF NOT EXISTS payment_subscriptions (
    subscription_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    mini_app_id TEXT NOT NULL,
    product_id TEXT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    capability TEXT NOT NULL,
    rail TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN (
        'active', 'cancel_at_period_end', 'billing_retry', 'expired', 'revoked'
    )),
    current_period_start INTEGER NOT NULL,
    current_period_end INTEGER NOT NULL,
    original_payment_id TEXT NOT NULL REFERENCES payment_intents(payment_id) ON DELETE RESTRICT,
    latest_payment_id TEXT NOT NULL REFERENCES payment_intents(payment_id) ON DELETE RESTRICT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    UNIQUE (user_id, mini_app_id, product_id)
);

CREATE INDEX IF NOT EXISTS payment_subscriptions_access_idx
    ON payment_subscriptions(user_id, mini_app_id, capability, status, current_period_end);

-- Official Global Dharma plans. CNY is represented in fen, never floating
-- point. Store product references must resolve to the matching configured
-- products in App Store Connect / Google Play Console before release.
INSERT INTO products
(product_id, plugin_id, sku, seller_user_id, entitlement_capability, consumption_mode, active, created_at, updated_at)
VALUES
('global-dharma-prayer-wheel-monthly', 'global-dharma', 'local-prayer-wheel.monthly', 'official.fabushi', 'local.prayer-wheel.start', 'durable', 1, unixepoch(), unixepoch()),
('global-dharma-prayer-wheel-lifetime', 'global-dharma', 'local-prayer-wheel.lifetime', 'official.fabushi', 'local.prayer-wheel.start', 'durable', 1, unixepoch(), unixepoch())
ON CONFLICT(product_id) DO UPDATE SET
  plugin_id = excluded.plugin_id,
  sku = excluded.sku,
  seller_user_id = excluded.seller_user_id,
  entitlement_capability = excluded.entitlement_capability,
  consumption_mode = excluded.consumption_mode,
  active = 1,
  updated_at = excluded.updated_at;

INSERT INTO prices
(price_id, product_id, currency, amount, active, starts_at, ends_at, created_at)
VALUES
('global-dharma-prayer-wheel-monthly-cny-v1', 'global-dharma-prayer-wheel-monthly', 'CNY', 3000, 1, unixepoch(), NULL, unixepoch()),
('global-dharma-prayer-wheel-lifetime-cny-v1', 'global-dharma-prayer-wheel-lifetime', 'CNY', 108000, 1, unixepoch(), NULL, unixepoch())
ON CONFLICT(price_id) DO UPDATE SET
  product_id = excluded.product_id,
  currency = excluded.currency,
  amount = excluded.amount,
  active = 1,
  starts_at = excluded.starts_at,
  ends_at = NULL;

INSERT INTO payment_product_config
(product_id, developer_id, product_kind, platform_fee_bps, allowed_rails_json,
 provider_product_refs_json, active, created_at, updated_at, display_name, description,
 entitlement_duration_seconds, billing_period_seconds)
VALUES
(
  'global-dharma-prayer-wheel-monthly', 'official.fabushi', 'subscription', 0,
  '["apple_in_app_purchase","google_play_billing","web_provider"]',
  '{"apple_in_app_purchase":"com.ombhrum.fabushi.globaldharma.prayerwheel.monthly","google_play_billing":"global_dharma_prayer_wheel_monthly","web_provider":"global-dharma-prayer-wheel-monthly-cny"}',
  1, unixepoch(), unixepoch(), '本地转经轮月付', '每 30 天自动续费，可随时取消；当前已付周期仍可使用。',
  2592000, 2592000
),
(
  'global-dharma-prayer-wheel-lifetime', 'official.fabushi', 'digital_durable', 0,
  '["apple_in_app_purchase","google_play_billing","web_provider"]',
  '{"apple_in_app_purchase":"com.ombhrum.fabushi.globaldharma.prayerwheel.lifetime","google_play_billing":"global_dharma_prayer_wheel_lifetime","web_provider":"global-dharma-prayer-wheel-lifetime-cny"}',
  1, unixepoch(), unixepoch(), '本地转经轮永久买断', '一次购买，当前 Fabushi 账号永久使用本地转经轮。',
  NULL, NULL
)
ON CONFLICT(product_id) DO UPDATE SET
  developer_id = excluded.developer_id,
  product_kind = excluded.product_kind,
  platform_fee_bps = excluded.platform_fee_bps,
  allowed_rails_json = excluded.allowed_rails_json,
  provider_product_refs_json = excluded.provider_product_refs_json,
  active = 1,
  updated_at = excluded.updated_at,
  display_name = excluded.display_name,
  description = excluded.description,
  entitlement_duration_seconds = excluded.entitlement_duration_seconds,
  billing_period_seconds = excluded.billing_period_seconds;
