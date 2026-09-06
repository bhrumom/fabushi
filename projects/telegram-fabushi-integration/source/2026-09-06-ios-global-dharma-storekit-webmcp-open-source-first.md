# iOS Global Dharma StoreKit / WebMCP open-source-first decision

- Project: FAB-P0001 / TFI
- Cross-project: FAB-P0008 / AAC
- Atomic task: `TFI-M9-GLOBAL-DHARMA-IOS-001`
- Baseline canonical main: `8f7e83902a616ecdb62fdaded65ea79227e745f3`
- Date: 2026-09-06

## Existing first-party truth to reuse

1. `M8-WEBMCP-001` already supplies the unified Mini App Host/WebMCP bridge. iOS `MiniAppWebMcpSurface` loads the installed plugin UI locally and routes declared tools through `runtime.call`; write/destructive operations retain native approval.
2. iOS `GrokMobileShell` already discovers real Bots via `bot.list`, and `MobileBotChat` sends natural-language turns with `chat.send(agentId:, mode: agent)` and renders `agent.step` / streamed output.
3. `M9-GLOBAL-DHARMA-003` already defines canonical paid capability truth: `global-dharma`, capability `local.prayer-wheel.start`, lifetime SKU `prod.global-dharma.local-prayer-wheel.lifetime`, CNY minor amount `108000`, durable entitlement.
4. Canonical entitlement read remains `GET /v1/plugins/:plugin_id/entitlements/:capability`. `access.allowed` is the authorization truth and `purchaseOptions` is server-authoritative for price and active rails.
5. Canonical Fabushi Pay already exposes intent -> checkout -> Apple verification, and iOS `FabushiPayStoreKit` already uses the server `paymentId` as StoreKit `appAccountToken`, verifies the StoreKit transaction locally, requires server verification, and only then finishes the transaction.
6. The provider-binding seed intentionally keeps `apple_advanced_commerce` and `google_play` at `pending_configuration`; therefore a production/sandbox App Store purchase must fail closed until an external Apple product/binding is activated. The Web provider is not a substitute for the iOS StoreKit acceptance gate.
7. AAC remains the account/session authorization project. It must not become a second payment ledger. The iOS payment client may reuse only a short-lived current-account credential from the trusted Host; no refresh token or payment entitlement is exposed to WebView JavaScript.

## Open-source / platform references reviewed

### Apple StoreKit 2

Apple StoreKit 2 is the primary implementation reference because the client is native iOS and the app already uses StoreKit 2.

- `Transaction.currentEntitlements` is the normal local view of currently entitling verified transactions, including non-consumables.
- StoreKit maintains transaction state during normal operation; `AppStore.sync()` should be user initiated for an explicit Restore Purchases action rather than called automatically on launch.
- Transactions remain untrusted until verification succeeds; Fabushi additionally requires its own server verification before entitlement access is accepted.
- Xcode StoreKit testing is suitable for deterministic client purchase/restore coverage, but it does not prove that a production App Store Connect product/provider binding exists or that App Store Server API can resolve a local Xcode test transaction.

### RevenueCat `purchases-ios` (MIT)

Reviewed only as an open-source reference for restore/entitlement UX and state management. Fabushi must **not** introduce RevenueCat as a second entitlement or payment backend because canonical Rust Fabushi Pay + `PLATFORM_DB` already own price, payment, reconciliation, and entitlement truth.

Reusable pattern: explicit Restore action -> refresh verified purchases -> refresh canonical entitlement -> gate capability from entitlement state.

## Decision

Implement the minimum iOS adapter around existing canonical systems:

1. Add an account-scoped `GlobalDharmaCommerceModel` that reads the canonical entitlement and server purchase options.
2. Allow the lifetime StoreKit action only when the canonical lifetime purchase option advertises `apple_in_app_purchase` as active.
3. Create a canonical payment intent with a fresh idempotency key, obtain checkout action, then delegate the StoreKit transaction to `FabushiPayStoreKit`.
4. Add explicit user-triggered restore. It calls `AppStore.sync()`, enumerates only verified `Transaction.currentEntitlements`, and re-verifies matching transaction/payment identity with Fabushi Pay before refreshing canonical entitlement.
5. Never unlock from local StoreKit state alone. `local.prayer-wheel.start` is usable only when canonical entitlement says `access.allowed == true`.
6. The Mini App and Bot remain on the same Host/runtime state. Add a Bot-level `打开应用` action that opens the installed Global Dharma Mini App surface from the same `MarketplaceModel`, preserving WebMCP/runtime state instead of creating a second WebView-local state machine.
7. Add semantic elements for purchase/restore/access state so the App-owned iOS device can be verified through all six `fabushi.app.*` tools.
8. Keep production StoreKit unavailable when Apple provider binding is pending. Local StoreKit test coverage is evidence for client behavior only; live sandbox remains a separate gate.

## Security / privacy invariants

- No client-authored amount, currency, product entitlement, or access grant.
- No WebView access to bearer or refresh credentials.
- No transaction `finish()` before Fabushi Pay accepts the transaction.
- A transaction from another Fabushi account cannot be restored into the current account because server payment ownership is authoritative.
- Revoked/refunded/inactive server entitlements fail closed.
- Restore is explicit and user initiated.

## External release blocker definition

Live StoreKit sandbox/production acceptance is BLOCKED until all of the following are real and active:

- App Store Connect non-consumable product for the canonical lifetime SKU has an external product identifier;
- Fabushi `payment_provider_bindings` row for provider `apple_advanced_commerce` is `active` for the lifetime product;
- the active binding/provider reference returned by canonical purchase options resolves through StoreKit in the target signed build;
- required App Store Server API credentials are configured in the deployed Fabushi Pay environment;
- an eligible StoreKit sandbox/TestFlight account/device can complete and restore the purchase.

No code path may convert these missing external facts into a synthetic pass.