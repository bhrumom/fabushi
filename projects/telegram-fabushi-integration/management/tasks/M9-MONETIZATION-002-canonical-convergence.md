# M9-MONETIZATION-002 — Canonical Monetization Platform convergence

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Stage**: `M9 支付 / Monetization`
- **Status**: `IMPLEMENTED_PENDING_CI`
- **Branch**: `feat/m9-monetization-convergence`
- **Started**: `2026-08-25`
- **Source**: `source/2026-08-25-monetization-full-convergence.md`
- **Predecessor**: PR `#2131`, merged `ca3bfd4e499f0d984a089ac19fd4ba03347ac13c`

## Objective

Converge advertising + payment + subscription + developer revenue sharing + settlement + payout onto one economic platform while preserving exactly one production money-movement authority: the canonical Rust `mahayana-pay-worker` and its `PLATFORM_DB` ledger.

## Canonical architecture decision

`wallet_accounts`, `journal_entries`, `journal_lines` and `wallet_balances` in the Mahayana platform database are the financial source of truth. The first #2131 legacy-DB ledger prototype is removed by this continuation. Monetization-specific tables may reference or project canonical ledger state but may not introduce another writable balance or journal authority.

## Implemented scope

- canonical control-plane migration `0008_monetization_platform.sql`;
- effective-dated/versioned two-party split policy;
- normalized Revenue Event projection for payment/subscription/refund/advertising;
- subscription lifecycle separated from payment state and linked back to canonical entitlements;
- CPM/CPC/CPA/rewarded campaign and placement model;
- trusted verified ad event -> canonical journal -> Revenue Event -> developer pending balance;
- developer profile and KYC/KYB compliance state;
- payout request workflow gated by verified compliance, active canonical payout account and ledger-derived available balance;
- admin payout submission / settlement release delegated to canonical Rust Pay admin endpoints;
- user checkout and payment lookup delegated to canonical Rust Pay user endpoints;
- self-service developer summary for balances/revenue/subscriptions/payouts;
- reconciliation for missing payment Revenue Events, refund reversal projections, expired subscriptions/entitlements and payout-state convergence;
- anomaly checks for successful payment without journal, orphan Revenue Events, ad Revenue Event without journal, and unbalanced posted journal currencies;
- removal of #2131's duplicate legacy ledger schema/store/domain implementation.

## Acceptance criteria

1. No production-capable second ledger or mutable developer balance table exists outside the canonical Rust ledger.
2. Credits, Apple, Google, web-provider and merchant-provider checkout remain owned by `mahayana-pay-worker`.
3. A successful canonical payment can be projected idempotently into one Revenue Event without changing money balances.
4. Refund/chargeback effects remain canonical reversal journal movements and receive a separate reversal Revenue Event projection.
5. Split policy is immutable by version and resolved by scope/source/effective time.
6. Subscription lifecycle can update expiry/revocation independently of the original payment.
7. Billable advertising price is server-authoritative from campaign configuration; clients cannot submit a price.
8. Verified advertising revenue posts a balanced canonical journal entry and credits developer pending revenue.
9. Developer payout request requires verified compliance, an active canonical payout account and sufficient canonical available balance.
10. Actual payout reservation/processing remains delegated to canonical Rust Pay.
11. Reconciliation returns zero financial anomalies on accepted production state.
12. Worker JS syntax/tests/Wrangler dry-run and canonical Rust Pay cargo test/clippy/wasm/fmt gates pass.
13. PR merges through protected main; canonical main is re-read.
14. Exact accepted main SHA completes the Worker production deployment and Fabushi Pay migration/deploy smoke gates.

## Security / compliance boundaries

- Raw KYC/KYB identity documents are not stored in Fabushi tables; only external provider references and compliance state are stored.
- Internal provider/ad event ingestion requires secret authentication; missing secrets disable the endpoint rather than fail open.
- Ad event session/actor values are stored only as SHA-256 hashes.
- Payment and payout admin secrets are never returned by APIs or committed to the repository.
- Public payout requests do not move money directly; canonical Rust Pay performs the financial reservation.

## Current evidence

- #2131 canonical merge: `ca3bfd4e499f0d984a089ac19fd4ba03347ac13c`.
- Source requirement commit: `04064ce1f98594938fd7c6577fb8cf7eba24a2da`.
- Canonical schema commit: `22116d1c83f295247d2ec687d4cda986f6cc32c5`.
- Orchestration service commit: `d7ed059798f91624020536a3304bbaf01ffc5833`.
- API handlers commit: `dba767b6469ce98eb661a153cec61d84617bed2c`.
- Router commits: `807058a7b8b6aaca62c194cff7811d69870e5467`, `19ba04e41ad5f6a60937845e06d970e86a01adb0`, `3b4dd18fc77a0f23a3702d41b2bdc6b60e4a644c`.
- Reconciliation commit: `1e641f8c3131dcc4188a15183d85a9aaa474c45f`.
- Contract tests commit: `1f0faec50fbe5e012aebf54d937ee7e831fe408a`.
- Duplicate ledger retirement commits: `482e89c7fdbaf9792bd65795db63fa34530fe563`, `663c707e7a3bb38c3cd3fe88cc6604e03be9bd37`, `7c2568e4c06fe5fc702ab8b9244a1f1fde0c0401`, `f1337c5bc07fc195fa2c870924593e3e95cd76f2`.

## Blocking external conditions

- PSP/KYC provider credentials and legal merchant/KYB onboarding are external operational dependencies; code must fail closed when not configured.
- Production internal event secrets must exist in the deployed Worker environment before trusted ad/subscription event ingestion can be enabled.

## Next gate

Open PR, run canonical CI, fix all failures, merge through protected main, then inspect Worker + Fabushi Pay post-main deployment/migration/smoke evidence for the exact merge SHA. Do not mark complete earlier.
