# 2026-09-08 — Global Dharma desktop packaged closure readback

- Project: `FAB-P0001 / TFI`
- User request reference: `Fabushi:33ccf7b0-d200-441d-acd7-7f02ff0c270c`
- Scope: Marketplace -> Global Dharma install -> Messenger Bot -> natural-language WebMCP -> Telegram-style open-app shared state -> bounded Fabushi account session -> CNY 1080 lifetime entitlement/restore -> local prayer wheel.
- Result: `DESKTOP_E2E_VERIFIED / OVERALL_IN_PROGRESS`
- Evidence synchronization branch: `docs/tfi-global-dharma-packaged-evidence-20260908`

## Truth readback

1. Canonical feature implementation PR #2448 is merged as `d7c8b45c3a7409d14d11bbf49107ff320b05ad84`.
2. Current main is `77f72b13304b75a45530de03fb807f52c3624be1`; the feature merge remains in main history.
3. Exact feature-merge SHA `Electron desktop quality gate` run `34052575208` is SUCCESS.
4. Packaged matrix jobs succeeded on Linux (`101538692043`), macOS (`101538691957`), and Windows (`101538692052`); aggregate result `101540495911` succeeded.
5. Exact-main diagnostics exist for Linux (`9995167107`), macOS (`9995176003`), Windows (`9995159094`).
6. macOS diagnostics contain 12 screenshots, a full Global Dharma WebM screencast, trace.zip and Playwright report.

## Acceptance trace

| Requested behavior | Objective packaged assertion/evidence | Result |
|---|---|---|
| Search Mini App `全球法布施` | Global Apps search finds `global-dharma`; checkpoint 02 | PASS |
| Install | install action transitions to `打开`; checkpoint 03 | PASS |
| Bot appears in messages/contacts | `全球法布施 @global_dharma_bot`; checkpoint 04 | PASS |
| Natural-language Bot execution | send `please show status now`; response says status read; execution source=`bot`, phase=`completed`, tool=`status`; checkpoint 05 | PASS |
| Bot and UI use same WebMCP/runtime | opened iframe lists status/start/stop/send and exact execution revision equals Bot revision; checkpoint 06 | PASS |
| Telegram-style `打开应用` | Bot composer exposes open-app control and controlled `global-dharma` iframe opens | PASS |
| Fabushi account auto session | Mini App session loggedIn=true, pluginId=`global-dharma`, tokenExposed=false; raw bearer tokens absent | PASS |
| CNY 1080 lifetime purchase contract | lifetime option product=`prod.global-dharma.local-prayer-wheel.lifetime`, currency=CNY, amount=108000; purchase result entitled; checkpoint 07 | PASS in deterministic CI provider |
| Restore | restore reports restored=true and entitlement allowed; checkpoint 08 | PASS |
| Entitled local prayer wheel | Bot sends `启动转经轮`; Host confirms permission and execution surface=`local-prayer-wheel`, entitlementAllowed=true; checkpoint 09 | PASS |
| UI follows Bot after operation | reopened app revision equals newer Bot start revision; checkpoint 10 | PASS |
| Durable state | restart recovers history/execution revision/entitlement/CloudStorage; checkpoint 11 | PASS |
| Logout cleanup | controlled session loggedIn=false and local/durable execution projections are cleared; checkpoint 12 | PASS |

## Payment truth boundary

The user-facing packaged simulation did not charge a real PSP. It deliberately ran `FABUSHI_FEATURE_HOST_MODE=test` so intent, callback dedupe, entitlement and restore could be deterministically exercised. Product/price/capability remain server-authoritative. This proves the integration contract and simulated-user journey, not external PSP production activation.

## Remaining blockers

- Production web PSP / `FABUSHI_PAY_CHECKOUT_URL` / provider credentials / KYC-KYB are not proven.
- Round C production migration, production smoke and reconciliation remain pending.
- Android terminal Global Dharma journey is still blocked by run `34051316405` (`failed-timeout`, stale app-surface generation, App-owned connection refresh failure) with artifact `9994884584`.

## Next execution

Do not reimplement the desktop path. The next atomic work is to repair the Android terminal path and then run fresh packaged mobile evidence; separately, activate a real provider/sandbox rail and run exact-main production/sandbox payment reconciliation without weakening fail-closed behavior.
