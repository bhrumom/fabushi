# TFI-M9-GLOBAL-DHARMA-IOS-001 — iOS Global Dharma Mini App / Bot / StoreKit closure

- Project: `FAB-P0001 / TFI`
- Cross-project boundary: `FAB-P0008 / AAC`
- Parent: `M9-GLOBAL-DHARMA-003`
- Baseline canonical main: `8595a50196309c8ebb91c3f8077125d7dc9e3ffa` (aligned from original implementation baseline `8f7e83902a616ecdb62fdaded65ea79227e745f3`)
- Branch: `feat/tfi-ios-global-dharma-commerce-20260906`
- State: `IMPLEMENTING / PR_ACTIVE`
- Owner: iOS / Mini App Host / payments
- Open-source decision: `../../source/2026-09-06-ios-global-dharma-storekit-webmcp-open-source-first.md`

## Goal

Close the real iOS user journey for the official `global-dharma` Mini App without introducing a second Bot, login, WebMCP runtime, payment ledger, or entitlement state machine:

1. Marketplace search for `全球法布施` and install the real release;
2. bind local install to canonical Fabushi account sync so the real `global-dharma-bot` appears in Messages;
3. send natural-language Bot turns through the existing `chat.send(agentId:, mode: agent)` path and unified WebMCP/Mini App Host;
4. expose a Telegram-style `打开应用` action that opens the installed Mini App from the same Host/runtime;
5. reuse the existing Fabushi login session without exposing bearer/refresh credentials to Mini App JavaScript;
6. offer server-authoritative CNY 1080 lifetime purchase of `local.prayer-wheel.start` through Apple Advanced Commerce / StoreKit 2;
7. restore purchases explicitly and trust only canonical server entitlement `access.allowed`;
8. validate on a packaged/installable exact-main iOS build through GitHub Actions and the App-owned semantic device.

## Atomic implementation

### A — Marketplace → account install → Bot

- [x] Keep local package install in `feature.plugin.install`.
- [x] Add canonical Host action `feature.marketplace.add`, backed by `mahayana-product` authenticated `POST /v1/marketplace/plugins/:plugin_id/add`.
- [x] iOS install requires `accountSynchronized=true` and a non-empty Bot id after local install; local-only install is not reported as journey success.
- [x] Keep native request/device/account platform `ios`; normalize Product API browse/list to `mobile`; for external Mini App package installation mirror the real App Host by trying native artifact first and falling back to `mobile` artifact without changing device identity.
- [ ] PR CI proves Rust + iOS build/tests.
- [ ] Packaged exact-main journey proves `全球法布施` search → install → permission approval → return → `global-dharma-bot` visible.

### B — Bot → unified WebMCP → Telegram-like Mini App

- [x] Reuse real `bot.list` discovery and `chat.send(... mode: agent)` stream; no iOS Bot implementation fork.
- [x] Convert the existing Bot desktop icon into semantic `mobile-bot-open-app` / `打开应用` for Global Dharma only.
- [x] `打开应用` first verifies `feature.plugin.active(global-dharma)` and opens `MiniAppWebMcpSurface` backed by the same `MarketplaceModel` / `MahayanaHost`.
- [x] Preserve local Mini App `runtime.call` WebMCP bridge and native approval policy.
- [x] Expose existing Grok-shell back navigation to the six semantic tools so the same user journey can return from Marketplace to Messages.
- [ ] Packaged exact-main journey proves natural-language Bot execution and same-runtime Mini App state at meaningful checkpoints.

### C — Fabushi account boundary (AAC cross-acceptance)

- [x] Reuse current signed-in account through trusted `feature.auth.deviceAgentSession` only in the native app.
- [x] Never inject account bearer/refresh credentials into WKWebView or Mini App JavaScript.
- [x] Account-level Marketplace install is authenticated through canonical `mahayana-product`, not a Swift-only duplicate API client.
- [x] Payment/restore never writes entitlement locally; TFI Fabushi Pay remains the only payment/entitlement authority.
- [ ] Packaged exact-main journey proves no second login is requested after the Fabushi test account session is established.

### D — CNY 1080 lifetime Advanced Commerce

Canonical identifiers are not interchangeable:

- product id: `prod.global-dharma.local-prayer-wheel.lifetime`
- payment SKU: `local-prayer-wheel.lifetime`
- capability: `local.prayer-wheel.start`
- product kind: `digital_durable`
- currency/amount: `CNY / 108000` minor units = `¥1080`

Implementation:

- [x] Read canonical entitlement + `purchaseOptions` and fail closed on SKU/product/currency/amount/product-kind mismatch.
- [x] Enable Apple purchase only when server advertises active rail `apple_in_app_purchase`.
- [x] Create canonical Payment Intent with a fresh idempotency key and server-owned price.
- [x] Require checkout `appleInAppPurchase`, canonical verify path, and Advanced Commerce signing path.
- [x] Read current StoreKit storefront immediately before signing; send the three-letter country code to the server.
- [x] Consume server JWS as StoreKit `advancedCommerceData`; the signed request already carries `paymentId` as `requestInfo.appAccountToken`.
- [x] Verify the resulting StoreKit transaction locally, require its `appAccountToken == paymentId`, re-verify with Fabushi Pay, and call `finish()` only after server success.
- [x] Refresh canonical entitlement and expose the prayer-wheel access as allowed only when `access.allowed == true`.
- [ ] Sandbox completes a real Advanced Commerce charge and entitlement grant.

### E — Restore

- [x] Restore is explicit/user-initiated and calls `AppStore.sync()`.
- [x] Iterate only verified current entitlements; recover original Fabushi `paymentId` from `appAccountToken`.
- [x] Re-verify candidate transactions with Fabushi Pay under the current Fabushi account and require the exact lifetime SKU.
- [x] Refresh canonical entitlement and refuse to unlock on StoreKit state alone.
- [ ] Sandbox proves purchase on one install/device context and restore into the same Fabushi account on a clean/reinstalled context.

## Automated verification before merge

- `GlobalDharmaCommerceTests`:
  - exact canonical CNY 1080 durable offer accepted;
  - tampered price/SKU rejected;
  - pending Apple provider keeps purchase disabled;
  - Advanced Commerce `signatureInfo.token` envelope exact;
  - empty JWS rejected.
- Existing Rust/JS account sync tests remain authoritative for `miniapp.installed → bot.added`, message history, cloud/content state and account isolation.
- Test-driver contract keeps request/device/account `platform=ios`, maps Marketplace API browse/list to server `mobile`, and mirrors the production App Host native→`mobile` artifact fallback. `InstalledPluginPointer` records plugin/version/artifact/runtime/path and has no platform identity field.
- No local `xcodebuild`. All iOS compilation/tests occur in GitHub Actions.

## Post-main packaged acceptance

Only canonical main may satisfy this section. Required evidence from `ios-interactive-app-e2e.yml` or a narrower equivalent that preserves the same gates:

- packaged/installable `.app` built for exact accepted main SHA;
- recording begins before install;
- app logs in with protected CI test credential, then the App itself registers a new App-owned iOS device;
- all six `fabushi.app.status/snapshot/find/action/wait/assert` tools used;
- one screenshot after each meaningful checkpoint;
- complete uncut operation video;
- `.xcresult`, semantic trace, app/runner logs and report uploaded with `if: always()`;
- evidence must identify exact run/job/SHA and remain downloadable.

Journey checkpoints:

1. logged-in Messages home / no second login;
2. enter Marketplace;
3. search `全球法布施`;
4. result `global-dharma` visible;
5. install + approve declared permissions;
6. account sync confirmed and return to Messages;
7. `global-dharma-bot` visible;
8. open Bot and send natural language status/start request;
9. observe Bot stream / WebMCP agent step;
10. invoke `打开应用`;
11. same Global Dharma Mini App/runtime visible and state consistent with Bot operation;
12. entitlement status visible;
13. CI/Simulator test-mode: canonical ledger buy `¥1080` with no StoreKit and no real charge → canonical entitlement allowed → prayer-wheel action allowed; production Apple validation remains a separate Advanced Commerce sandbox gate;
14. CI/Simulator test-mode restore through canonical `/v1/purchases/restore`; production restore remains `AppStore.sync()` + verified transaction + Pay reverify; re-check canonical entitlement in both modes;
15. close Mini App and finish semantic session cleanly.

## Production Apple external blockers — fail closed

The repository cannot fabricate any of the following. If absent at post-main time, payment acceptance remains `BLOCKED`, not `PASS`:

1. Apple has approved Advanced Commerce API access for the Fabushi app / applicable Mini Apps Partner Program use case.
2. App Store Connect contains the appropriate one-time generic product id for the Mini Apps Partner Program and it has been submitted to Apple per Advanced Commerce setup.
3. Canonical `payment_provider_bindings` for this product has provider `apple_advanced_commerce`, a real generic provider product reference, and `sync_state='active'`.
4. The Global Dharma catalog has an explicitly approved Apple `tax_code`; the original seed leaves it `NULL`, and repository code must not guess tax classification.
5. Deployed Commerce/Pay environments have `APPLE_ADVANCED_COMMERCE_ENABLED` and real `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_KEY_ID`, `APPLE_IAP_PRIVATE_KEY_PEM`, `APPLE_BUNDLE_ID`, plus App Store Server verification credentials.
6. A signed eligible iOS build plus Sandbox Apple Account/device is available.

Apple explicitly states Advanced Commerce purchases cannot use StoreKit Testing in Xcode. Therefore local `.storekit` simulation is not accepted as production Apple evidence. The governed GitHub Actions Simulator test-mode is different: it is allowed to exercise the canonical Fabushi purchase ledger only, must never invoke StoreKit or create a real charge, and still must re-read canonical server entitlement before unlocking the capability.

## Evidence

- Baseline main: `8595a50196309c8ebb91c3f8077125d7dc9e3ffa` (aligned from original `8f7e83902a616ecdb62fdaded65ea79227e745f3`)
- Governed branch: `feat/tfi-ios-global-dharma-commerce-20260906`
- Pull request: `#2446` — `feat(iOS): close Global Dharma Mini App commerce journey`
- Design record commit: `2aca32d7dc5cdac2764cba5d35502d739117e40e`
- Commerce model commit: `de86a41b766f764bcd1632bbb42dc52e49ff659a`
- StoreKit restore commit: `9467566f8e325b70f464e41f9c1991315560da25`
- First fast-gate failure: Mahayana fast checks run `34038687786`; `cargo fmt --all -- --check` reported formatting only; fixed in branch commit `6b53d35efdacb0ab2f564bc00e2db9111eeb6cd3`.
- Full Host/Product/WebMCP/FFI PR validation at head `34ac2618e7e5f268485573c94085a9ddfbc13b4e`: Mahayana fast `34039127343` success; Vendor Isolation `34039127324` success; Native mobile fast gate `34039127357` success; CI `34039127390` success; Project portfolio governance `34039127412` success; GBF security `34039127371` success; Electron desktop quality `34039127425` success; Computer control security `34039127321` success.
- Marketplace Contract run `34039127475` exposed a real live iOS discovery defect in `Test Mahayana marketplace packages`: request/device `platform=ios` was passed directly to the Product API, which accepts only `cli|desktop|mobile|web`, producing HTTP 400 `invalid_marketplace_platform`. Diagnostic artifact `mahayana-marketplace-validation-diagnostics` id `9991275111`, digest `sha256:f86763ee928dea7b74a0bc0c15429cea78e088ed836df1c885c154c1f7ddfd05`.
- Fix commit `dd8520a49b00fcbdd8c468bce25577085ac99f8b`: normalize Marketplace API browse/list native platforms (`ios|android → mobile`) while preserving native request/device semantics; mapper unit test added. Subsequent live validation proved the test-driver also had to mirror the already-existing App Host native→`mobile` artifact fallback for universal Mini App packages.
- Alignment merge commit: `9d51e3e3d514cfcc2b6337e1baaecdc51c8453d3` merges canonical `main@8595a50196309c8ebb91c3f8077125d7dc9e3ffa` into the governed iOS branch without conflicts.
- Final pre-alignment head `c0c050b6120e744849a71d1df3fe05ec372413b6` had four failing checks — Mahayana iOS test-driver contract `34039955034`, Global Dharma Rust `34039955089`, Plugin Marketplace Contract `34039955156`, Mahayana fast checks `34039955007` — all blocked at the same `backend.rs` rustfmt delta before substantive test execution.
- GitHub Actions supplied the exact rustfmt correction for `backend.rs`; this round applies only that emitted formatting delta and delegates authoritative `cargo fmt --check` to Actions because the local Mac has no Rust toolchain.
- CI/Simulator payment acceptance is now explicitly canonical-ledger-only/no-charge; production Apple Advanced Commerce remains separately fail-closed on real Apple eligibility/configuration.
- Final-head PR CI / merge-queue / accepted-main SHA / post-main iOS build / packaged journey / video / screenshots / `.xcresult` / trace/logs/report: pending; only real GitHub identifiers may satisfy them.

- Current-head Marketplace Contract run `34048201512` reached the live package test after rustfmt/Worker checks passed, then failed `live_official_global_dharma_is_external_verified_and_persistent` because the test-driver called `PluginInstaller.install(..., "ios")` directly and returned `no compatible artifact for platform ios`. Diagnostic artifact `9993892782`, digest `sha256:457de7cee04532c9fc561244f70989f5fc9245da45401f69e69842650802d52b`.
- Live official `global-dharma@1.0.0` metadata advertises one verified `local-web` artifact `global-dharma-universal-ui` for `desktop|mobile|web|cli`. The real App Host already retries `mobile` when native `ios|android` installation fails, so this is a test-driver parity defect rather than an iOS product-install defect.
- Follow-up keeps `platform=ios` for request/device/account semantics and adds the same native→`mobile` artifact fallback to the test-driver; authoritative proof must come from the next GitHub Actions Marketplace Contract run.

- Current-head Marketplace Contract run `34048908027` proved the native→`mobile` artifact fallback works: the previous `no compatible artifact for platform ios` error disappeared and the focused fallback unit test passed. The remaining failure was a stale live-test assertion at `test_driver_backend.rs:111` expecting `receipt.platform == "ios"`; actual value is `Null` because `InstalledPluginPointer` intentionally has no platform field. The install response already preserves native request/device semantics as top-level `platform: "ios"`, while the selected official artifact correctly declares `mobile`. Diagnostic artifact `9994122473`, digest `sha256:2a9d801c476cf5fcc6dae44c373cc13ec8b2dbf62cbecf7a639a3f4b96adbc8d`.
- Follow-up corrects only the live-test contract: assert top-level native `platform == "ios"` and assert the selected release artifact supports `mobile`; do not invent a platform field in the persisted receipt. Authoritative verification remains the next GitHub Actions Marketplace Contract run.
