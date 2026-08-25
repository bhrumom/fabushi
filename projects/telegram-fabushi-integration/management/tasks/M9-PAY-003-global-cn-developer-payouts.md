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
| M9-PAY-003-A | Payout account models legal region, entity/KYC/KYB state, provider capability, supported currencies and external account reference; renderer cannot set provider secrets or verification state | migration + schema/security contract | IN_PROGRESS |
| M9-PAY-003-B | Server routing covers CN WeChat/Alipay original-order split, CN external-store proceeds via LianLian/Huifu, and global Stripe/Adyen/PayPal priorities; unavailable routes fail closed | Rust unit tests | IN_PROGRESS |
| M9-PAY-003-C | Settlement waterfall uses integer minor units and calculates platform fee from reconciled net receipts after tax/provider/store fees/refunds/chargebacks, then reserve/developer payable | Rust unit tests + ledger contract | IN_PROGRESS |
| M9-PAY-003-D | Payout reservation and provider execution are separate states with idempotent attempts, provider reference/error metadata, webhook reconciliation and failed-payout reversal | migration + Rust/contract tests | IN_PROGRESS |
| M9-PAY-003-E | Developer APIs are owner-scoped and expose balance breakdown, payout accounts, onboarding/capability state, settlement history and payout request without client authority over developer id, fee policy or ineligible provider routing | HTTP/auth contract + wasm compile | IN_PROGRESS |
| M9-PAY-003-F | Bot Father “收益与结算” surface shows pending/available/reserved/paid balances, onboarding/account status, settlement breakdown and payout history/request; native bridge keeps bearer/provider secrets outside renderer | web build + native bridge contract | IN_PROGRESS |
| M9-PAY-003-G | Existing M9-PAY-002 pay-in CI regression is green, including platform-worker wasm compile fix | GitHub Actions | IN_PROGRESS |
| M9-PAY-003-H | Final branch CI green, PR merged into canonical `main`, exact-main verification and required post-main delivery evidence completed | PR + Actions + Release/evidence | PENDING |

## Provider policy

### Mainland China
- `wechat_platform`: WeChat-origin marketplace order split only after Platform Collection & Payment eligibility/configuration.
- `alipay_platform`: Alipay-origin marketplace order split only after approved platform product configuration.
- `lianlian_account_plus`: preferred payout for reconciled external store proceeds when provider/business approval is active.
- `huifu_dougong`: fallback mainland-China payout provider when approved/configured.

### Global
- `stripe_connect`: primary marketplace onboarding/payout where country/entity/currency supported.
- `adyen_platform`: enterprise balance-platform/split/payout provider.
- `paypal_multiparty`: approved fallback; ordinary PayPal checkout is not treated as marketplace onboarding.

## Current findings

- Existing Fabushi Pay already has `developer_payout_accounts`, settlement release, payout reservation, pending/available accounts and payout webhook events. This task extends those primitives; it must not create a second ledger.
- Current payout accounts are admin-created and mark `active` without KYC/capability evidence; that is insufficient for production marketplace payouts.
- Current settlement release calculates from gross developer net after Fabushi fee, not a reconciled provider/store-fee waterfall.
- Current `platform-worker-wasm` CI fails because `developer_commerce_proxy.rs` uses `js_sys::Uint8Array` without the platform worker declaring the `js-sys` wasm dependency. This is an implementation defect to fix in this task round.

## External activation gates

Source code cannot grant provider approval. Production-live payout remains blocked per provider until the corresponding merchant/platform agreement, business-category approval, KYC/KYB flow, production credentials/webhook configuration and supported settlement account are present. Provider state must remain fail-closed until those facts are verified.
