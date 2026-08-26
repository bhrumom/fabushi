# ADR-0008 — Dynamic Fiat Mini App Commerce

- Status: Accepted
- Date: 2026-08-25
- Project: FAB-P0001 / TFI

## Context

Fabushi is a host platform for a potentially very large third-party Mini App catalog. Requiring every digital SKU to be manually maintained in App Store Connect / Play Console does not scale. Requiring every digital purchase to pass through a Fabushi token also adds an unnecessary conversion layer when the store supports direct fiat settlement.

## Decision

1. Fabushi owns the canonical developer product catalog and price-revision history.
2. Digital products may be directly priced in fiat. FBC/credits remain an optional rail, never a required intermediary.
3. A developer may choose SKU, descriptors, product kind, entitlement, tax classification, fiat price and supported rails. Developer identity, Mini App ownership, platform fee and provider credentials are server authority only.
4. iOS uses Apple Advanced Commerce API / Mini Apps Partner Program when the account has the required entitlement. Fabushi hosts SKU metadata, uses generic App Store product identifiers, creates `CREATE_ONE_TIME_CHARGE` / `CREATE_SUBSCRIPTION` payloads at runtime, and signs `advancedCommerceData` with an In-App Purchase ES256 key.
5. Android uses Google Play Billing for the user purchase and Android Publisher API for server-side catalog synchronization. Store sync state is explicit and fail-closed.
6. Web/Desktop use the existing Fabushi Pay web/merchant provider rails.
7. All provider rails converge on the existing Fabushi Pay PaymentIntent, provider verification/webhook, balanced ledger, entitlement and developer settlement pipeline.
8. `global-dharma` is represented through the same developer/app/catalog tables as third-party Mini Apps. Payment core must not branch on its identity.

## Consequences

- App Store Connect does not need one manually maintained entry per Fabushi Mini App SKU when Advanced Commerce is available.
- Google catalog work is automated by the control plane rather than delegated to Mini App developers.
- Missing Apple entitlement/generic IDs/signing key/tax code or Google service-account permission produces pending/error state instead of a fake successful purchase path.
- Store program approval, tax agreements and production credentials remain operational prerequisites and cannot be manufactured by code.
