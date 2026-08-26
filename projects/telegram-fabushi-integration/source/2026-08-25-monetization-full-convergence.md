# 2026-08-25 — Unified Monetization Platform full convergence

User direction: continue implementation until the monetization platform covers advertising, payment, subscription, developer revenue sharing, settlement and payout as one platform.

This continuation is part of `FAB-P0001 / TFI / M9` and must converge on the canonical Rust `mahayana-pay-worker` rather than create a second payment authority.

Required convergence scope:

1. Canonical Rust payment ledger remains the sole production money-movement authority.
2. Payment sources (credits, Apple IAP, Google Play Billing, web provider, merchant provider, legacy Alipay bridge) normalize into durable revenue events.
3. Split rules are versioned/effective-dated and immutable for historical transactions.
4. Subscription lifecycle is stored separately from payment state and updates entitlements.
5. Advertising has placement/campaign/event ingestion, verification state, idempotency and conversion into billable revenue only after verification.
6. Developer balances expose pending/available semantics backed by ledger accounts; settlement releases move pending to available.
7. Developer payout accounts and payouts remain PSP-backed, KYC/KYB-gated and auditable.
8. Refunds/disputes are reversal money movements, not mutable history rewrites.
9. Public developer/self-service endpoints expose read-only balance, revenue, subscription, entitlement and payout state without exposing admin secrets.
10. Legacy Web payment endpoints are compatibility surfaces only and must not become a parallel ledger.

Acceptance requires Rust + Worker tests, protected merge, canonical-main readback and production Fabushi Pay migration/deploy smoke evidence for the exact accepted main SHA.
