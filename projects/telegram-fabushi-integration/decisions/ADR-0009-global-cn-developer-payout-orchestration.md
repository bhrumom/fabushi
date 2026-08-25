# ADR-0009: Provider-neutral Global + China Developer Payout Orchestration

- Status: Accepted
- Date: 2026-08-25
- Project: FAB-P0001 / TFI
- Stage: M9 Payments

## Context

Fabushi already has a server-authoritative payment catalog, PaymentIntent, provider verification, double-entry journal, developer pending/available balances, settlement release and payout reservation. The current payout account model is admin-created and provider-agnostic only by string; it does not model KYC/KYB, country/currency capabilities, marketplace onboarding, routing, provider execution attempts, store/provider fee reconciliation or the different legal fund flows required in mainland China and global markets.

Creating separate China and global payment cores would fragment accounting and make refunds, chargebacks and developer liabilities inconsistent.

## Decision

### 1. One authoritative ledger

The existing Fabushi ledger and payment core remain authoritative. External marketplace/platform providers are execution and regulated-account layers, not the Fabushi source of truth.

### 2. Provider-neutral payout accounts

Developer payout accounts record provider, external account reference, legal region, supported currencies, onboarding/KYC/KYB capability state and operational state. The renderer never receives provider credentials or raw identity documents.

### 3. Purpose-aware regional routing

Routing is server-side and fail-closed:

- Mainland China + WeChat-origin order: `wechat_platform` original-order split.
- Mainland China + Alipay-origin order: `alipay_platform` original-order split.
- Mainland China + Apple/Google/external store proceeds: `lianlian_account_plus` preferred; `huifu_dougong` fallback only when configured and approved.
- Global marketplace payout: `stripe_connect` preferred where supported, then `adyen_platform`, then approved `paypal_multiparty` according to configured capability/priority.

The developer/client can choose among already eligible payout accounts but cannot authoritatively choose a provider that is not allowed by region/purpose/currency policy.

### 4. Settlement waterfall before availability

Developer availability is based on reconciled net receipts rather than gross sales alone:

`gross - tax - provider/store fee - refunds/chargebacks = net receipts`

`platform fee = policy basis points * net receipts / 10000`

`developer payable = net receipts - platform fee - reserve`

All arithmetic uses integer minor units. Provisional capture remains in pending; reconciliation/release moves only the reconciled payable amount into available balance. This avoids treating store fees as if the developer had already earned them.

### 5. External provider execution is explicit

A payout has reservation and execution attempts. Reserving money in the Fabushi ledger is not equivalent to a successful external payout. Provider attempts have idempotency keys, provider reference, state, response/error metadata and webhook reconciliation.

### 6. Compliance gates

No payout account becomes `active` until the provider/account capability is verified. Missing commercial approval, provider credentials, KYC/KYB, supported country/currency or required seller status returns a configuration/compliance error and does not move funds.

## Open-source-first evidence

We reviewed proven upstream patterns before implementing:

- Stripe Connect official samples: connected-account onboarding and platform transfer patterns. We adapt the account/capability separation, not the Node/Python code.
- Adyen official `adyen-examples` / Adyen for Platforms documentation: balance accounts, split instructions, commissions and verified payout instruments. We adapt the balance-platform semantics while keeping Fabushi ledger authoritative.
- WeChat Pay official APIv3 SDK and Platform Collection & Payment docs: signed server-side API calls, second-level merchant onboarding, order-level profit sharing, idempotent asynchronous result checks. We use the protocol pattern and do not introduce a Java runtime dependency.
- Alipay official EasySDK/OpenAPI patterns: server-side signed OpenAPI and merchant authorization. We keep the adapter boundary because the exact product grant is commercial/account-specific.
- LianLian Account+ and Huifu platform products: multi-role accounts, splitting/settlement/withdrawal capabilities; production activation remains subject to business approval.

No upstream SDK is copied into the Rust/Cloudflare runtime because the canonical SDKs are primarily Java/Node/other runtimes and would worsen deployment/runtime ownership. Fabushi implements protocol adapters behind its existing Rust payment boundary and retains provider licensing/provenance separation.

## Consequences

Positive:
- one ledger across Apple, Google, Web, WeChat, Alipay and payout providers;
- Fabushi platform fee is auditable and consistent;
- China fund flows can use licensed original-order split products rather than manual pooling;
- providers can be replaced without changing Mini App product/payment contracts;
- all unavailable providers fail closed.

Costs / constraints:
- production activation requires provider contracts, credentials and approved business categories;
- Apple/Google store proceeds require reconciliation before downstream developer payout;
- China digital-goods qualification cannot be inferred from API availability alone;
- tax/Merchant-of-Record policy remains jurisdiction-specific and must be configured operationally.

## Rejected alternatives

1. **One Stripe-only global payout system** — rejected because mainland China marketplace settlement and local payment flows require different regulated products and country support.
2. **Separate China ledger** — rejected because it would fragment refunds, reserves, platform fees and developer balances.
3. **Manual bank transfers from Fabushi operating account** — rejected as the default due to operational, reconciliation and regulatory/custody risk.
4. **Client-selected platform fee/provider** — rejected because money movement policy must remain server-authoritative.
