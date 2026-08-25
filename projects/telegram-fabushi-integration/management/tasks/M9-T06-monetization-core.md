# M9.T06 — Unified Monetization Core

- **Project**: FAB-P0001 / TFI / Fabushi Telegram 全量融合
- **Task ID**: M9.T06
- **Status**: IMPLEMENTED_PENDING_CI
- **Branch**: `feat/fabushi-monetization-core`
- **Source requirement**: 2026-08-25 user request to implement a unified Monetization Platform spanning advertising, payments, subscriptions, developer revenue sharing, settlement and payout.

## Objective

Build the shared financial core so payment providers, subscriptions, advertising and future MiniApp/Bot/Agent revenue sources emit one normalized Revenue Event into one auditable ledger instead of maintaining independent balances.

## Acceptance criteria

1. All money is represented as integer minor units; floating point is rejected for ledger arithmetic.
2. Every split rule totals exactly 10,000 basis points and every minor unit is allocated deterministically.
3. Every posted revenue journal has equal total debit and total credit.
4. Revenue events are idempotent by external/provider key and duplicate delivery does not create duplicate revenue.
5. Developer earnings expose Pending, Available, Reserved and Paid lifecycle buckets and cannot overdraw.
6. Payout lifecycle cannot jump directly from requested to paid.
7. Subscription and entitlement records are separate from raw payment state.
8. Advertising has a verified-event staging model before a billable Revenue Event is produced.

## Implementation

- `fabushi/web/migrations/20260825_monetization_platform_v1.sql`
  - accounts, revenue events, versioned split rules, journals/entries, balances, subscriptions, entitlements, payouts, advertising events.
- `fabushi/web/src/services/monetization.js`
  - integer-money validation, split rule validation, deterministic split allocation, balanced journal construction, balance transitions, payout state machine, Revenue Event normalization.
- `fabushi/web/src/services/monetization-store.js`
  - D1-compatible idempotent Revenue Event persistence and atomic journal/entry posting.
- `fabushi/web/tests/monetization.test.js`
  - invariant tests for split conservation, journal balance, balance overdraft prevention, payout transitions and event idempotency requirements.

## Open-source-first research

Before implementation, proven designs were reviewed for concepts rather than copied code:

- Formance Ledger: immutable/double-entry financial ledger concepts and transaction-oriented money movement.
- Lago: separation of billing/metering concerns from payment collection.
- Kill Bill: subscription/billing domain separation and provider-oriented architecture.
- Medusa commerce architecture: provider abstraction and modular commerce boundaries.

Decision: adapt the proven separation-of-concerns and double-entry concepts into Fabushi's existing Cloudflare D1/JavaScript backend. No upstream source code is copied into this task; the implementation remains within Fabushi domain boundaries. External PSP custody/payout remains a later provider-adapter task rather than making Fabushi a funds custodian.

## Evidence

- Schema commit: `108e190fef30a869c68309af15f3610a93cd4f84`
- Domain core commit: `628809cb1e5afbbafb505f4a93dd925678615a7a`
- Invariant tests commit: `0d716c8ee89daf8d9949612362d65058e7d7b638`
- Persistence commit: `a6d9c8d19dab68899966b8814d82fd3d21de75d3`
- WBS update commit: `20ec91258948948a0c31a463faee6feee7c9ee3d`

## Verification

Planned required check: `node --test fabushi/web/tests/monetization.test.js` plus repository CI. PR, CI, protected-main merge, canonical-main readback and applicable post-main delivery evidence are still pending; therefore this task is not complete.

## Next actions

1. Run repository CI through a PR and fix failures.
2. Add active split-rule resolver and persistence integration coverage.
3. Migrate existing Alipay/StoreKit/Play/Stripe events through a feature-gated Revenue Event adapter.
4. Implement reversal journals for refunds/chargebacks.
5. Implement verified advertising event -> Revenue Event adapter and PSP-backed developer payout adapter.
