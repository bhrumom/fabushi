# 2026-08-25 Global + China Developer Marketplace Payout Requirements

## User requirement

Extend the existing FAB-P0001 / M9 Developer Commerce system so Mini App developers can be paid out in mainland China and globally without creating a second payment or ledger core.

The canonical Fabushi ledger remains the source of truth. KYC/KYB, bank-account verification, payment-network custody and external payout execution are delegated to qualified marketplace/platform payment providers wherever possible.

## Required payout topology

### Mainland China

1. WeChat-origin marketplace orders: prefer WeChat Pay Platform Collection & Payment (`平台收付通`) so developers/second-level merchants receive funds inside the licensed payment institution and Fabushi commission is allocated by order-level profit sharing. Never require the gross order to be manually pooled in a normal Fabushi operating bank account.
2. Alipay-origin marketplace orders: prefer Alipay internet-platform direct settlement / platform merchant capability (`互联网平台直付通` or the currently approved equivalent) for seller onboarding, payment, settlement and commission allocation.
3. Apple / Google / other externally settled store proceeds: route developer payable amounts through an approved mainland-China payout provider. Priority provider is LianLian Account+ after commercial/compliance approval; Huifu platform settlement is the fallback.
4. Provider eligibility is fail-closed. A configured API URL is not evidence of regulatory/product approval.
5. Commercial payouts should default to verified enterprise / individual-business developer entities. Personal seller support requires an explicit provider-approved route, limits, tax policy and risk policy.

### Global

1. Stripe Connect is the first global marketplace onboarding/payout adapter where the Fabushi legal entity and developer country are supported.
2. Adyen for Platforms is a first-class provider for balance-platform, split and enterprise-scale settlement use cases.
3. PayPal multiparty/platform onboarding is an optional fallback where approved; ordinary PayPal checkout or an email address is not treated as a marketplace payout account.
4. Every provider account must expose provider capability/KYC state to Fabushi. `active` is only allowed when the provider says payouts are enabled.

## Unified settlement model

All pay-in rails converge into one Fabushi Developer Ledger:

`gross -> taxes -> provider/store fees -> refunds/chargebacks -> net receipts -> Fabushi platform fee -> reserve -> developer payable -> available -> payout clearing -> paid`

Fabushi platform fee must be calculated from server-side policy and settlement inputs, never from client-provided developer id, amount, fee basis or payout provider. The default commercial policy may be configured as 5% of net receipts; the database/API must support per-product/developer policy without hard-coding that rate into clients.

## Required developer experience

Bot Father / Developer Commerce must expose:

- legal-entity / payout onboarding status;
- pending, available, reserved and paid balances by currency;
- configured payout accounts and provider state;
- payout schedule (manual/automatic where supported);
- payout request and status/history;
- transparent settlement breakdown (gross, provider/store fee, tax, refunds, platform fee, reserve, developer payable).

Sensitive identity documents, bank credentials and provider secrets must not be stored in the renderer or exposed to Mini Apps. Hosted/embedded provider onboarding is preferred.

## Provider abstraction

Fabushi must route through a provider-neutral contract rather than hard-coded `stripeAccountId` fields:

- `create_onboarding_session`
- `get_account_status`
- `request_payout`
- `get_payout_status`
- `handle_webhook`
- `reverse_or_reconcile`

Canonical providers:

- `stripe_connect`
- `adyen_platform`
- `paypal_multiparty`
- `wechat_platform`
- `alipay_platform`
- `lianlian_account_plus`
- `huifu_dougong`

## Current official constraints verified 2026-08-25

- WeChat Pay Platform Collection & Payment supports second-level merchant onboarding, frozen settlement funds, order-level profit sharing/platform commission, and currently documents a default maximum split ratio of 30%. The public product page currently focuses mainly on online physical-goods marketplace scenarios, so Fabushi digital-goods eligibility must remain a commercial/qualification gate.
- Adyen for Platforms supports balance accounts, split instructions, commission/cost allocation and payout to verified transfer instruments.
- LianLian Account+ materials describe platform accounts, multi-role account management, splitting/settlement/withdrawal capabilities. The specific Apple/Google-proceeds-to-Mini-App-developer business flow still requires provider approval.

Primary references:
- https://pay.wechatpay.cn/doc/v3/partner/4012086891
- https://pay.wechatpay.cn/doc/v3/partner/4012691594
- https://docs.adyen.com/platforms/process-payments
- https://docs.adyen.com/platforms/quickstart-guide/payouts/
- https://accpms.lianlianpay.com/

## Acceptance boundary

Implementation is complete only when the provider-neutral data model, routing, settlement waterfall, developer APIs/UI, fail-closed KYC/provider capability checks, webhook/idempotency handling and automated tests are merged into canonical `main` and verified there. Live external payouts additionally require each provider's approved merchant/platform contract and production credentials; those external approvals must never be represented as completed by source code alone.
