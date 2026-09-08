# M9-GLOBAL-DHARMA-003 desktop WebMCP / entitlement evidence

State: `DESKTOP_E2E_VERIFIED / OVERALL_IN_PROGRESS`
Date: `2026-09-08`
Intake main: `8f7e83902a616ecdb62fdaded65ea79227e745f3`
Feature merge main: `d7c8b45c3a7409d14d11bbf49107ff320b05ad84`
Current canonical main at final readback: `77f72b13304b75a45530de03fb807f52c3624be1`
Original execution branch: `feat/tfi-global-dharma-desktop-webmcp-commerce-20260906`
Evidence synchronization branch: `docs/tfi-global-dharma-packaged-evidence-20260908`

## Scope verified on packaged desktop

- Marketplace search/install of official `global-dharma` and Messenger Bot projection.
- Bot natural-language route resolves the installed Mini App Tool Contract and executes through the same WebMCP host function used by the iframe.
- Host-owned `fabushi.miniapp.execution.v1` durable revision is pushed to an open iframe and read back when the iframe is opened later or the app restarts.
- Mini App receives a bounded authenticated session projection only; no access/refresh bearer credential is exposed (`tokenExposed:false`).
- Exact `local.prayer-wheel.start` entitlement is checked before prayer-wheel start and before accepting a returned hostRequest for that capability.
- Lifetime CNY 1080.00 comes from canonical server purchase options (`108000` minor units). The Platform Router exposes only user create-intent/get-intent/checkout Pay routes; provider/admin routes remain outside the facade.
- Explicit `FABUSHI_FEATURE_HOST_MODE=test` provides deterministic intent/callback/idempotency/restore semantics for packaged CI without becoming a production entitlement source.
- Restart preserves Bot/UI revision, entitlement and CloudStorage state; logout clears the controlled Mini App session and durable execution projection.

## Canonical implementation / merge evidence

- Round A canonical entitlement PR: #2135, merged as `db287caa1b8495c94bf9ecafe7f064bca2ee57a0`.
- Web/service shared-runtime PR: #2445, merged as `c82b29cd6404c2f19b93d8479b2e2cae45469249`.
- Desktop Bot/WebMCP/commerce PR: #2448, merged to canonical `main` as `d7c8b45c3a7409d14d11bbf49107ff320b05ad84` on 2026-09-06.
- Later unrelated changes advanced canonical main to `77f72b13304b75a45530de03fb807f52c3624be1`; #2448 remains an ancestor of main.

## Exact-main packaged Electron evidence

Workflow: `Electron desktop quality gate`
Run: `34052575208`
Head branch: `main`
Head SHA: `d7c8b45c3a7409d14d11bbf49107ff320b05ad84`
Conclusion: `SUCCESS`

Jobs:

- Electron macOS `101538691957`: SUCCESS; package + notarization + packaged user journey + diagnostics upload succeeded.
- Electron Linux `101538692043`: SUCCESS; package + packaged user journey + diagnostics upload succeeded.
- Electron Windows `101538692052`: SUCCESS; package + packaged user journey + diagnostics upload succeeded.
- Aggregate `Electron desktop result` `101540495911`: SUCCESS.

Artifacts tied to the exact feature merge SHA:

- macOS package `9995186046` (`fabushi-electron-mac`).
- macOS diagnostics `9995176003` (`fabushi-electron-mac-e2e-diagnostics`), artifact digest `sha256:150b63f97b75217034c20289ab2bacdc71eb265edc52230676932e4223e26e56`.
- Linux package `9995174215`; Linux diagnostics `9995167107`.
- Windows package `9995164889`; Windows diagnostics `9995159094`.
- Pre-package real-Rust-Host evidence `9995095838`.

macOS diagnostics contain:

1. `01-authenticated-messenger.png`
2. `02-marketplace-search-global-dharma.png`
3. `03-marketplace-installed.png`
4. `04-contact-bot-projection.png`
5. `05-bot-natural-language-webmcp-complete.png`
6. `06-open-app-same-revision-account-and-paywall.png`
7. `07-cny1080-lifetime-entitlement-purchased.png`
8. `08-entitlement-restored.png`
9. `09-bot-starts-entitled-local-prayer-wheel.png`
10. `10-open-app-follows-bot-prayer-wheel-revision.png`
11. `11-restart-recovers-history-state-entitlement-cloud.png`
12. `12-logout-clears-miniapp-session-and-execution.png`
13. `global-dharma-user-journey.webm`
14. `trace.zip` plus the Playwright HTML report.

The packaged test asserts the full chain: search -> install -> Bot projection -> natural-language status request -> shared WebMCP execution revision -> `打开应用` -> same revision and logged-in bounded account projection -> exact `CNY 108000` lifetime purchase -> restore -> Bot starts entitled `local-prayer-wheel` -> reopen app at the same newer revision -> restart recovery -> logout cleanup.

Locally extracted only for user delivery from the immutable GitHub artifact on 2026-09-08:

- Original WebM SHA-256: `472260ee5da38dff970caeb3af97115e32a2b243d8d76b48b8101249c027f3ae`.
- MP4 transcode SHA-256: `18648574b914f4ab524e880cb3374736b6db73bebf0d79ea7fea70b21315ef80`.
- Video dimensions: 1280x800; packaged journey screencast duration: 6.44s.

## Payment semantics and limitation

No real provider charge occurred in this evidence. The packaged desktop journey uses the explicit deterministic `FABUSHI_FEATURE_HOST_MODE=test` provider so that PaymentIntent, callback deduplication, durable entitlement and restore can be exercised without charging money. Product identity, amount, entitlement capability and Host gate remain server-authoritative and match the production contract.

This is valid simulated-user acceptance evidence for the requested desktop journey. It is not evidence that a production PSP account, KYC/KYB, real checkout URL or payout rail has been activated.

## Remaining blockers / non-claims

- Production web PSP/provider activation and real `FABUSHI_PAY_CHECKOUT_URL` / provider credentials are external and remain unverified; production purchase must fail closed until present.
- App Store / Google Play product provisioning and provider bindings remain external mobile dependencies.
- Android terminal journey remains not accepted: interactive run `34051316405` failed with timeout / stale surface generation / App-owned connection refresh failure; artifact `9994884584` preserves that failure evidence.
- Round C production migrations, production health/smoke/reconciliation, and a fresh terminal mobile journey remain open.

Therefore desktop Round B is `E2E_VERIFIED`, while the cross-platform/production M9 task stays `IN_PROGRESS`.
