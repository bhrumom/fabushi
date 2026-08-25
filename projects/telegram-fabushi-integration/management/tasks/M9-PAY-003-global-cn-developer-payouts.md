# M9-PAY-003 Global + China Developer Payout Orchestration

- Project: FAB-P0001 / TFI
- Stage: M9 支付
- Status: COMPLETE
- Owner surface: Fabushi Pay / Developer Ledger / Developer Commerce / Bot Father
- Depends on: M9-PAY-002 Dynamic Fiat Developer Commerce

## Goal

Turn the existing developer settlement/payout primitives into a provider-neutral marketplace payout system for mainland China and global distribution while preserving one Fabushi payment core and one authoritative double-entry ledger.

## Atomic acceptance

| ID | Acceptance | Objective test | Status |
|---|---|---|---|
| M9-PAY-003-A | Payout account models legal region, entity/KYC/KYB state, provider capability, supported currencies and external account reference; renderer cannot set provider secrets or verification state | migration + schema/security contract | COMPLETE |
| M9-PAY-003-B | Server routing covers CN WeChat/Alipay original-order split, CN external-store proceeds via LianLian/Huifu, and global Stripe/Adyen/PayPal priorities; unavailable routes fail closed | Rust unit tests | COMPLETE |
| M9-PAY-003-C | Settlement waterfall uses integer minor units and calculates platform fee from reconciled net receipts after tax/provider/store fees/refunds/chargebacks, then reserve/developer payable | Rust unit tests + ledger contract | COMPLETE |
| M9-PAY-003-D | Payout reservation and provider execution are separate states with idempotent attempts, provider reference/error metadata, webhook reconciliation and failed-payout reversal | migration + Rust/contract tests | COMPLETE |
| M9-PAY-003-E | Developer APIs are owner-scoped and expose balance breakdown, payout accounts, onboarding/capability state, settlement history and payout request without client authority over developer id, fee policy or ineligible provider routing | HTTP/auth contract + wasm compile | COMPLETE |
| M9-PAY-003-F | Bot Father “收益与结算” surface shows pending/available/reserved/paid balances, onboarding/account status, settlement breakdown and payout history/request; native bridge keeps bearer/provider secrets outside renderer | web build + native bridge contract | COMPLETE |
| M9-PAY-003-G | Existing M9-PAY-002 pay-in CI regression is green, including platform-worker wasm compile fix | GitHub Actions | COMPLETE |
| M9-PAY-003-H | Final branch CI green, PR merged into canonical `main`, exact-main verification and required post-main delivery evidence completed | PR + Actions + evidence | COMPLETE |

## Provider policy

### Mainland China
- `wechat_platform`: WeChat-origin marketplace order split only after Platform Collection & Payment eligibility/configuration.
- `alipay_platform`: Alipay-origin marketplace order split only after approved platform product configuration.
- `lianlian_account_plus`: preferred payout for reconciled external-store proceeds when provider/business approval is active.
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

## 完成证据

- 主实现 PR：`#2133` — `[automerge-force] feat(pay): dynamic fiat commerce with global and mainland China payouts`。
- 最终 feature head：`4d0687fed9b54793cb1237c39718b51b8d32b669`。
- feature-head 门禁：Developer Fiat Commerce run `32868752808` 5/5 success；Developer Fiat Commerce UI run `32868752819` 2/2 success；Platform Control Plane run `32868752821` success；CI run `32868752829` success；Electron desktop quality gate run `32868752823` success；Messaging Product Gate run `32868752779` success。
- Protected Merge Queue：PR #2133 经 `automerge` + explicit `[automerge-force]` 授权进入队列第 1 位；merge-group CI run `32869281732` success。
- canonical `main` 合并 SHA：`573c140f7007ad98230c90f3c24bc99e1f36a88f`，PR #2133 merged at 2026-08-25T16:01:48Z。
- exact-main 门禁：Developer Fiat Commerce run `32869457305` 5/5 success；Developer Fiat Commerce UI run `32869457162` 2/2 success；Platform Control Plane run `32869457301` success；Merge Queue CI 已在同一 SHA 上 success。
- exact-main Commerce 具体覆盖：control-plane unit/fmt、commerce-control wasm32、platform-worker wasm32/fmt、pay-worker wasm32/fmt、schema/security/accounting contract 全部 success。

## External activation gates

工程实现、自动化验证、Protected Merge Queue 合并和 exact-main 验收已经完成。生产实际资金分发仍受第三方机构外部条件约束：微信/支付宝平台商户及业务类目/分账资格、连连/汇付合同与生产凭据、Stripe/Adyen/PayPal marketplace 账户与 KYC/KYB、Apple/Google 商店资格与结算账户、Webhook/生产密钥等。任何未验证的 provider route 必须继续保持 fail closed；本任务不把外部机构尚未批准的通道声明为已生产启用。
