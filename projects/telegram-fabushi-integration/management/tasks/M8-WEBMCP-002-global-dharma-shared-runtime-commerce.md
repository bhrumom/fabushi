# M8-WEBMCP-002 — Global Dharma shared WebMCP runtime + commerce journey

- Project: `FAB-P0001 / TFI`
- Stage: `M8 WebMCP + M9 payment integration`
- Status: `DESKTOP_E2E_VERIFIED / OVERALL_IN_PROGRESS`
- Started: `2026-09-06`
- Canonical intake base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`
- Current canonical main readback: `main@77f72b13304b75a45530de03fb807f52c3624be1`
- Web/service protected merge: #2445 `7ec44b0b000e25ceb8799843cf98f85f3c6aa9b6` -> `c82b29cd6404c2f19b93d8479b2e2cae45469249`
- Desktop protected merge: #2448 -> `d7c8b45c3a7409d14d11bbf49107ff320b05ad84`
- Branch: `feat/tfi-global-dharma-web-service-sync-pay-20260906`
- Source: `../../source/2026-09-06-global-dharma-web-service-sync-commerce.md`
- Cross-project dependency: `FAB-P0008/AAC-004`

## Objective

Close the Web/server authority boundary for the official `global-dharma` Mini App so Marketplace/Bot/WebMCP use one Tool Contract, Bot and graphical Mini App observe the same durable account-scoped runtime, authenticated users receive a bounded server-side session projection, and the CNY 1080 lifetime prayer-wheel purchase/restore path consumes canonical Fabushi Pay rather than client-local state.

## Atomic acceptance

### A. Canonical Tool Contract
- One source defines Global Dharma tool names, descriptions, annotations/approval metadata and natural-language hints.
- Official MCP `tools/list`, Marketplace manifest commands and Mini App Bot command projection are derived from that source.
- Contract test fails if Marketplace/Bot inventory drifts from live MCP inventory.

### B. Durable account-scoped runtime
- Global Dharma `mode/running/loops/sent/logs/pendingContent` is persisted through existing `AccountSyncStore`, not process-local `Map` authority.
- Every mutation has a monotonic account event sequence/cursor and runtime revision.
- Initial state, difference replay, cursor-ahead/expired snapshot recovery and account isolation are objectively tested.

### C. Idempotency + approval
- Mutating tool calls carry a stable operation/idempotency identity.
- Same key + same operation/arguments replays the original receipt without duplicate side effect.
- Same key + different operation/arguments fails closed.
- read/write/open-world/destructive metadata remains explicit; WebMCP UI cannot silently skip required user confirmation.

### D. Bot / Web UI bidirectional convergence
- Bot natural-language routing resolves only against the current canonical Global Dharma Tool Contract.
- Bot-triggered tool mutation is visible when the Web UI opens and the Web UI receives later mutations through the same durable sequence.
- Reconnect from an old cursor deterministically catches up without a second event authority.
- `tools/list` and `tools/call` evidence is captured in contract/integration tests.

### E. Commerce / entitlement
- Lifetime product is server-authoritative CNY `108000` minor units and protects exact capability `local.prayer-wheel.start`.
- Web/server integration reuses canonical Fabushi Pay PaymentIntent/Order/provider verification/webhook/refund/reconciliation/entitlement APIs.
- Duplicate provider callback/idempotency key cannot duplicate capture/ledger/entitlement.
- Refund/reversal revokes or denies access according to canonical entitlement state; restore/reconciliation re-reads server authority.
- No Mini App local flag or raw payment state can authorize the host capability.

### F. Objective evidence / delivery
- Fast contract tests: Global Dharma Tool Contract parity, runtime idempotency/replay, account isolation, auth/session redaction, payment facade/entitlement contract.
- Integration test: Marketplace search/install -> Bot route -> MCP tools/list/tools/call -> runtime difference/reconnect -> entitlement read.
- Heavy/package/provider validation only through GitHub Actions.
- Protected PR merge + canonical-main readback required.
- Final packaged-user journey must retain full video, meaningful checkpoint screenshots, trace/report/logs and a real downloadable artifact link. If provider sandbox/package/device is unavailable, task remains BLOCKED/IN_PROGRESS and records the exact dependency.

## Baseline history

- PR #2169 (`M8-WEBMCP-001`) merged as `fefb35fc8a4e5c8dabecc9c11803764ec950b6e9`.
- PR #2135 (`M9-GLOBAL-DHARMA-003` Round A) merged as `db287caa1b8495c94bf9ecafe7f064bca2ee57a0`.
- M2 account sync provides durable `as1:<sequence>` difference/snapshot recovery and is the required event substrate.

## Web/service evidence

- Intake source commit: `2eb4b0cf524942f003bc6ec973ba8119745b2030`.
- Implementation commit: `f9a2df5850e81bd5f1fbe3450adf4ec4e3b0f906`.
- Current-main synchronization merge: `a53b576ab99f0c3fbeed65e4e3937424d9abd3c6`.
- #2445 is MERGED. Exact-head run `34049805438` is SUCCESS with backend/runtime/account job `101531239556`, CNY1080 order/webhook/refund/restore job `101531239450`, and Web production build job `101531239575`; artifacts `9994199494` / `9994192661` / `9994207785`.
- Merge queue run `34049934041` / job `101531586697` accepted `c82b29cd6404c2f19b93d8479b2e2cae45469249`.

## Desktop consumer evidence

- Pre-package real-Rust-Host evidence: #2448 head `1655ea8070e07ad7dd8ab8e9347fbcb43f6ddf8f`, run `34051925481`, artifact `9994834346`; 12 screenshots, trace and Global Dharma user-journey video.
- #2448 then merged through protected main as `d7c8b45c3a7409d14d11bbf49107ff320b05ad84`.
- Exact accepted-main Electron run `34052575208` is SUCCESS. Packaged Linux, macOS and Windows jobs all succeeded and aggregate `Electron desktop result` passed.
- Exact-main diagnostics: Linux `9995167107`, macOS `9995176003`, Windows `9995159094`. macOS artifact contains 12 named checkpoints, `global-dharma-user-journey.webm`, `trace.zip`, and Playwright report.
- The packaged journey proves: search `全球法布施` -> install -> Bot projection -> natural-language WebMCP `status` -> open Telegram-style app -> same host revision -> controlled logged-in account projection (`tokenExposed:false`) -> exact CNY 108000 lifetime entitlement -> restore -> Bot starts entitled local prayer wheel -> reopen app at same newer revision -> restart recovery -> logout cleanup.

## Blockers / non-claims

- No real payment provider charge is claimed. Packaged evidence uses explicit deterministic `FABUSHI_FEATURE_HOST_MODE=test`; production product/price/entitlement authority remains canonical Fabushi Pay.
- Real PSP/web-provider credentials, checkout URL, KYC/KYB/provider activation and production reconciliation remain external Round C dependencies and must fail closed when absent.
- Android 1.2.52 interactive run `34051316405` failed with timeout / stale surface generation / App-owned connection refresh failure; artifact `9994884584` preserves the failure. Mobile terminal proof remains PENDING.

## 2026-09-08 acceptance position

Desktop/Web/service requirements for the requested Global Dharma search/install -> Bot -> WebMCP -> synchronized Web UI -> bounded Fabushi account session -> CNY 1080 lifetime entitlement -> restore -> local prayer-wheel journey are `E2E_VERIFIED` on packaged Electron. The overall cross-platform/production task remains `IN_PROGRESS` until mobile terminal acceptance and production provider/reconciliation evidence are closed.
