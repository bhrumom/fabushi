# M9-PAY-003 Global + China Developer Payout Orchestration

- Project: FAB-P0001 / TFI
- Stage: M9 支付
- Status: IN_PROGRESS
- Owner surface: Fabushi Pay / Developer Ledger / Developer Commerce / Bot Father
- Depends on: M9-PAY-002 Dynamic Fiat Developer Commerce

## Goal

Turn the existing developer settlement/payout primitives into a provider-neutral marketplace payout system for mainland China and global distribution while preserving one Fabushi payment core and one authoritative double-entry ledger.

## Atomic acceptance

| ID | Acceptance | Objective test | Status |
|---|---|---|---|
| M9-PAY-003-A | Payout account models legal region, entity/KYC/KYB state, provider capability, supported currencies and external account reference; renderer cannot set provider secrets or verification state | migration + schema/security contract | VERIFYING |
| M9-PAY-003-B | Server routing covers CN WeChat/Alipay original-order split, CN external-store proceeds via LianLian/Huifu, and global Stripe/Adyen/PayPal priorities; unavailable routes fail closed | Rust unit tests | VERIFYING |
| M9-PAY-003-C | Settlement waterfall uses integer minor units and calculates platform fee from reconciled net receipts after tax/provider/store fees/refunds/chargebacks, then reserve/developer payable | Rust unit tests + ledger contract | VERIFYING |
| M9-PAY-003-D | Payout reservation and provider execution are separate states with idempotent attempts, provider reference/error metadata, webhook reconciliation and failed-payout reversal | migration + Rust/contract tests | VERIFYING |
| M9-PAY-003-E | Developer APIs are owner-scoped and expose balance breakdown, payout accounts, onboarding/capability state, settlement history and payout request without client authority over developer id, fee policy or ineligible provider routing | HTTP/auth contract + wasm compile | VERIFYING |
| M9-PAY-003-F | Bot Father “收益与结算” surface shows pending/available/reserved/paid balances, onboarding/account status, settlement breakdown and payout history/request; native bridge keeps bearer/provider secrets outside renderer | web build + native bridge contract | VERIFYING |
| M9-PAY-003-G | Existing M9-PAY-002 pay-in CI regression is green, including platform-worker wasm compile fix | GitHub Actions | VERIFYING |
| M9-PAY-003-H | Final branch CI green, PR merged into canonical `main`, exact-main verification and required post-main delivery evidence completed | PR + Actions + evidence | PENDING |

## Provider policy

### Mainland China
- `wechat_platform`: WeChat-origin marketplace order split only after Platform Collection & Payment eligibility/configuration.
- `alipay_platform`: Alipay-origin marketplace order split only after approved platform product configuration.
- `lianlian_account_plus`: preferred payout for reconciled external store proceeds when provider/business approval is active.
- `huifu_dougong`: fallback mainland-China payout provider when approved/configured.

### Global
- `stripe_connect`: primary marketplace onboarding/payout where country/entity/currency supported.
- `adyen_platform`: enterprise balance-platform/split/payout provider.
- `paypal_multiparty`: approved marketplace fallback where enabled.
- `paypal_payouts`: payout-only route for eligible external proceeds; it is not treated as marketplace seller onboarding.

## Implemented accounting and safety invariants

- One authoritative double-entry ledger is retained; no second wallet/payment core is introduced.
- Fiat settlement is reconciled before release: gross receipts -> tax/store/provider fee/refund/chargeback -> net receipts -> Fabushi platform fee -> risk reserve -> developer payable.
- Payout reservation moves developer available balance into a payout-clearing account. Provider success posts a balancing payout-finalization entry before marking the payout `paid`; provider failure reverses the reservation.
- Refunds after release/payout use reserve first, then developer available balance; unrecoverable excess is posted to the explicit Fabushi refund-loss account rather than silently altering developer proceeds.
- Automatic payout scheduling is fail-closed and requires compliance eligibility, active/default account, verified onboarding/KYC, payouts enabled, currency/purpose support and an active provider route.
- China original-order split remains source-transaction-bound and separate from ordinary developer withdrawal.
- Apple Advanced Commerce verification binds the generic product ID to the persisted dynamic Mini App SKU, request reference, app-account token, currency, tax code and item price. Financial settlement remains reconciliation-authoritative.

## Final validation mode

As of the final feature-head validation round, both Developer Fiat Commerce workflows are read-only: they use the exact committed GitHub SHA and no longer auto-edit or push source during CI. This task document update intentionally triggers both backend and UI/native workflows on the same candidate head. A-G may become `COMPLETE` only after those exact-head checks pass; H may become `COMPLETE` only after PR merge and exact-main checks pass.

## External activation gates

Source code cannot grant provider approval. Production-live payout remains blocked per provider until the corresponding merchant/platform agreement, business-category approval, KYC/KYB flow, production credentials/webhook configuration and supported settlement account are present. Provider state must remain fail-closed until those facts are verified.
