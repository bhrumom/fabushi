import { assertIdentifier } from './monetization-platform.js';

const ACTIVE_SUBSCRIPTION_STATES = new Set(['trialing', 'active', 'past_due']);

function safeJsonArray(value) {
  try {
    const parsed = JSON.parse(String(value || '[]'));
    return Array.isArray(parsed) ? parsed.map((item) => String(item)) : [];
  } catch {
    return [];
  }
}

function positiveIntegerOrNull(value) {
  if (value == null) return null;
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : null;
}

export function evaluateEntitlementGrant(row, now = Math.floor(Date.now() / 1000)) {
  if (!row || row.entitlement_status !== 'active') return { allowed: false, reason: 'inactive_entitlement' };
  if (row.subscription_status && !ACTIVE_SUBSCRIPTION_STATES.has(String(row.subscription_status))) {
    return { allowed: false, reason: `subscription_${row.subscription_status}` };
  }
  if (Number(row.lifetime || 0) === 1) {
    return { allowed: true, reason: 'lifetime', effectiveExpiresAt: null };
  }
  const explicitExpiry = positiveIntegerOrNull(row.entitlement_expires_at);
  const providerPeriodEnd = positiveIntegerOrNull(row.current_period_end);
  const durationSeconds = positiveIntegerOrNull(row.entitlement_duration_seconds);
  const grantedAt = positiveIntegerOrNull(row.granted_at);
  const effectiveExpiresAt = providerPeriodEnd
    ?? explicitExpiry
    ?? (durationSeconds && grantedAt ? grantedAt + durationSeconds : null);
  if (effectiveExpiresAt != null && effectiveExpiresAt <= now) {
    return { allowed: false, reason: 'expired', effectiveExpiresAt };
  }
  return { allowed: true, reason: effectiveExpiresAt == null ? 'active' : 'active_until_expiry', effectiveExpiresAt };
}

export async function resolveCapabilityAccess(database, {
  userId,
  miniAppId,
  capability,
  now = Math.floor(Date.now() / 1000),
}) {
  const stableUserId = assertIdentifier(userId, 'userId');
  const pluginId = assertIdentifier(miniAppId, 'miniAppId');
  const capabilityName = assertIdentifier(capability, 'capability');
  const grants = (await database.prepare(`
    SELECT
      e.entitlement_id,
      e.product_id,
      e.status AS entitlement_status,
      e.granted_at,
      e.expires_at AS entitlement_expires_at,
      t.entitlement_duration_seconds,
      t.lifetime,
      s.status AS subscription_status,
      s.current_period_end
    FROM entitlements e
    JOIN products p ON p.product_id = e.product_id
    LEFT JOIN monetization_product_terms t ON t.product_id = e.product_id
    LEFT JOIN monetization_subscriptions s
      ON s.user_id = e.user_id
     AND s.product_id = e.product_id
     AND s.subscription_id = (
       SELECT s2.subscription_id
       FROM monetization_subscriptions s2
       WHERE s2.user_id = e.user_id AND s2.product_id = e.product_id
       ORDER BY s2.updated_at DESC
       LIMIT 1
     )
    WHERE e.user_id = ? AND p.plugin_id = ? AND e.capability = ?
    ORDER BY e.granted_at DESC
    LIMIT 100
  `).bind(stableUserId, pluginId, capabilityName).all()).results || [];

  for (const grant of grants) {
    const verdict = evaluateEntitlementGrant(grant, now);
    if (verdict.allowed) {
      return {
        allowed: true,
        reason: verdict.reason,
        entitlementId: grant.entitlement_id,
        productId: grant.product_id,
        effectiveExpiresAt: verdict.effectiveExpiresAt ?? null,
        purchaseOptions: [],
      };
    }
  }

  const products = (await database.prepare(`
    SELECT p.product_id, p.sku, pc.product_kind, pr.currency, pr.amount,
           pc.allowed_rails_json
      FROM products p
      JOIN payment_product_config pc ON pc.product_id = p.product_id
      JOIN prices pr ON pr.product_id = p.product_id
     WHERE p.plugin_id = ? AND p.entitlement_capability = ?
       AND p.active = 1 AND pc.active = 1 AND pr.active = 1
       AND pr.starts_at <= ? AND (pr.ends_at IS NULL OR pr.ends_at > ?)
     ORDER BY CASE pc.product_kind WHEN 'subscription' THEN 0 ELSE 1 END, pr.amount ASC
  `).bind(pluginId, capabilityName, now, now).all()).results || [];

  return {
    allowed: false,
    reason: grants.length ? 'no_current_grant' : 'not_entitled',
    entitlementId: null,
    productId: null,
    effectiveExpiresAt: null,
    purchaseOptions: products.map((row) => ({
      productId: row.product_id,
      sku: row.sku,
      productKind: row.product_kind,
      currency: row.currency,
      amount: Number(row.amount),
      allowedRails: safeJsonArray(row.allowed_rails_json),
    })),
  };
}
