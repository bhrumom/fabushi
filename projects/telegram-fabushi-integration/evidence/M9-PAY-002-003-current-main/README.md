# M9-PAY-002 / M9-PAY-003 exact-main closure evidence

- Project: `FAB-P0001 / TFI`
- Canonical main SHA: `573c140f7007ad98230c90f3c24bc99e1f36a88f`
- Implementation PR: `#2133`
- Final feature head: `4d0687fed9b54793cb1237c39718b51b8d32b669`
- Merge method: protected GitHub Merge Queue
- Merged at: `2026-08-25T16:01:48Z`

## Feature-head evidence

- Developer Fiat Commerce `32868752808`: 5/5 success.
- Developer Fiat Commerce UI `32868752819`: native contract + production web build success.
- Platform Control Plane `32868752821`: schema/account invariants, production Worker compile and one-control-plane guard success.
- Repository CI `32868752829`: success.
- Electron desktop quality gate `32868752823`: success.
- Messaging Product Gate `32868752779`: success.

## Merge Queue evidence

- Explicit sensitive-path authorization was recorded through repository governance using the `automerge` label and `[automerge-force]` title marker after the user explicitly required merge to `main`.
- Merge Queue reported PR #2133 at position 1.
- Authoritative merge-group CI `32869281732`: success.
- The successful merge-group SHA became canonical `main` as `573c140f7007ad98230c90f3c24bc99e1f36a88f`.

## Exact-main evidence

All checks below ran against `main@573c140f7007ad98230c90f3c24bc99e1f36a88f`:

- Developer Fiat Commerce `32869457305`: control-plane unit/fmt, commerce-control wasm32, platform-worker wasm32/fmt, pay-worker wasm32/fmt, schema/security/accounting contract — all success.
- Developer Fiat Commerce UI `32869457162`: native bridge authority contract + production Web build — both success.
- Platform Control Plane `32869457301`: schema/account invariants + production Worker compile + one-control-plane architecture guard — success.
- Merge Queue CI `32869281732` already validated the exact merge-group/main SHA before protected merge.

## Accepted architecture

- One canonical Rust Fabushi Pay / double-entry ledger remains the writable money authority.
- Developer Commerce prices are server-authoritative integer minor units.
- Apple Advanced Commerce uses generic products plus persisted dynamic Mini App SKU/JWS integrity binding.
- Google Play uses global `convertRegionPrices` plus catalog synchronization and fail-closed rail activation.
- Mainland-China settlement routing distinguishes source-order WeChat/Alipay split from LianLian/Huifu external-proceeds payout.
- Global payout routing supports Stripe Connect, Adyen Platform, PayPal Multiparty and PayPal Payouts through provider-neutral orchestration.
- KYC/KYB/provider capability/route state is server-owned; renderer cannot self-approve payout eligibility or set provider secrets/platform fees.
- Settlement fee calculation is based on reconciled net receipts, with explicit reserve, refund/chargeback and payout-clearing accounting.

## External production activation gates

Engineering implementation, protected merge and exact-main automated verification are complete. This evidence does **not** claim that every external payment provider is already production-enabled. Real money movement remains fail-closed until the relevant provider approval, merchant/platform agreement, business-category eligibility, KYC/KYB, production credentials, webhook configuration and settlement account are verified for Apple, Google, WeChat Pay, Alipay, LianLian, Huifu, Stripe, Adyen and/or PayPal as applicable.
