# 2026-08-25 Global Dharma paid local prayer-wheel requirement

- Project: `FAB-P0001`
- Milestone: `M9`
- Source: direct product requirement / continuing implementation
- Status: implementation active

## Requirement

The official Global Dharma Mini App must gate the local prayer-wheel execution capability behind Fabushi Monetization Platform:

- monthly: CNY 30.00 / 30 days;
- lifetime: CNY 1080.00;
- both unlock the exact host capability `local.prayer-wheel.start`;
- payment amount, currency, entitlement capability and available payment rails are server-authoritative;
- refund, revocation, cancellation and expiry must remove access according to canonical entitlement/subscription state;
- the Mini App must never unlock solely because a client reports that a payment succeeded;
- Apple/Google rails remain unavailable until their provider bindings are actually active;
- Web/desktop/mobile must consume the same canonical entitlement boundary rather than each maintaining a local purchase flag.

## Canonical architecture

The financial source of truth remains the existing Rust Fabushi Pay boundary and shared `PLATFORM_DB`. Revenue/entitlement projection must not introduce a second writable ledger.

The existing canonical user entitlement route is extended rather than creating a parallel access API:

`GET /v1/plugins/:plugin_id/entitlements/:capability`

The exact protected capability is the actual MCP host request emitted by Global Dharma: `local.prayer-wheel.start`.

## Open-source research / provenance

### Telegram Desktop

Repository: `telegramdesktop/tdesktop`.

Used only as public product/host-payment-flow architecture reference. No Telegram client source is copied into this change. Fabushi keeps its independently implemented Rust payment, entitlement and host boundaries.

### RevenueCat purchases-android

Repository: `RevenueCat/purchases-android`, MIT licensed.

Used as an entitlement-lifecycle reference: active entitlement state is separate from product purchase metadata, and durable/lifetime access can have no expiration while subscription access must resolve an effective period. Fabushi adapts this concept to its server-authoritative subscription state and fail-closed policy; no third-party payment state is trusted directly by the Mini App.

## Acceptance invariants

1. `prod.global-dharma.local-prayer-wheel.monthly` remains CNY 3000 and 30 days.
2. `prod.global-dharma.local-prayer-wheel.lifetime` remains CNY 108000 and durable.
3. Both map to `local.prayer-wheel.start` after a forward-only migration.
4. Active subscription expiry precedence is provider period end -> entitlement expiry -> server catalog period.
5. A subscription with unknown expiry fails closed.
6. Cancelled/revoked/expired access fails closed.
7. Apple/Google do not appear as active purchase rails while provider binding is pending configuration.
8. The access response preserves the legacy `entitlement` field while adding explicit `access` and server-authoritative `purchaseOptions`.
9. No change creates a second ledger or client-authoritative price.
