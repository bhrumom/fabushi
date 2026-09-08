# M9-GLOBAL-DHARMA-003 — Paid local prayer-wheel capability

- Project: `FAB-P0001`
- Milestone: `M9`
- Owner: platform / payments / miniapp host
- State: IN_PROGRESS
- Source: `../../source/2026-08-25-global-dharma-paid-prayer-wheel.md`

## Goal

Make the official Global Dharma local prayer-wheel capability a canonical Fabushi Monetization entitlement with monthly CNY 30.00 and lifetime CNY 1080.00 purchase options, and enforce the same access decision at host boundaries.

## Atomic acceptance tasks

### Round A — canonical access truth (#2135)

- [x] Reuse canonical Rust Fabushi Pay and `PLATFORM_DB`; no second ledger.
- [x] Reuse #2133 dynamic fiat Product/Price/provider binding instead of creating a parallel catalog.
- [x] Add forward-only migration from legacy `local-prayer-wheel` to exact `local.prayer-wheel.start` capability.
- [x] Backfill existing active monthly entitlement expiry from the 30-day catalog term.
- [x] Add pure Rust entitlement decision policy with fail-closed subscription expiry semantics.
- [x] Extend canonical entitlement endpoint with `access` and server-authoritative `purchaseOptions` while preserving `entitlement` compatibility.
- [x] Hide Apple/Google from active rails until provider bindings are active.
- [x] Add static contract coverage for SKU/price/capability/provider invariants.
- [x] Compile/test through protected PR CI.
- [x] Merge through protected `main`; PR #2135 merged as `db287caa1b8495c94bf9ecafe7f064bca2ee57a0` on 2026-08-25.

### Round B — Host enforcement and checkout

- [x] Wire the narrow authenticated user Pay proxy into the Platform Router without exposing admin/provider routes.
- [x] Wire desktop Mini App Host access check + createIntent/openCheckout to the native authenticated bridge.
- [x] Gate Global Dharma `hostRequest` before any local prayer-wheel execution/staging.
- [x] Add desktop E2E: no entitlement -> purchase required -> checkout action; valid entitlement -> host request allowed.
- [ ] Verify refund/cancel/expiry removes access in the full cross-platform E2E path. Server contract coverage exists, but mobile terminal acceptance remains open.
- [ ] Extend the same canonical access contract to native mobile host execution paths and close terminal mobile evidence.

### Round C — production delivery

- [ ] Apply production platform/payment migrations/deploy for the exact verified main SHA.
- [ ] Run production health/smoke/reconciliation and record evidence.

## External production dependencies

These are fail-closed and cannot be fabricated in repository code:

- App Store product/provisioning and provider binding activation for Apple;
- Google Play product/base-plan provisioning and provider binding activation for Google;
- real `FABUSHI_PAY_CHECKOUT_URL` / PSP credentials for web provider;
- KYC/KYB and payout provider accounts for actual developer payout.

Until those provider-side facts exist, the corresponding rail must remain unavailable even if a static product config lists it.

## Evidence

- #2132 merged canonical Monetization convergence into main.
- #2133 merged dynamic fiat commerce and Global Dharma product seed into main.
- Round A PR: #2135 from `feat/m9-global-dharma-paid-capability-v2`, merged as `db287caa1b8495c94bf9ecafe7f064bca2ee57a0`.
- Core Round A files:
  - `migrations/0013_global_dharma_paid_capability_gate.sql`
  - `src/capability_access.rs`
  - `src/worker_api/commerce.rs`
  - `fabushi/web/tests/global-dharma-paid-capability.test.js`

## 2026-09-06 — Desktop Round B execution

- Intake canonical main: `8f7e83902a616ecdb62fdaded65ea79227e745f3`.
- Governed branch: `feat/tfi-global-dharma-desktop-webmcp-commerce-20260906`.
- Source capture: `../../source/2026-09-06-global-dharma-desktop-bot-webmcp-commerce.md`.
- This round is desktop-first; mobile remains a later atomic task and is not claimed here.

Implementation slice:

- [x] Narrow authenticated Platform Router user-Pay proxy: create-intent / get-intent / checkout only; admin/provider verification routes excluded.
- [x] Electron native session projection, canonical entitlement read, CNY 1080 lifetime purchase facade and restore facade.
- [x] Bot natural-language route resolves the installed Tool Contract and executes through the same app-scoped `runtime.call` WebMCP function used by the iframe.
- [x] One host-owned durable `fabushi.miniapp.execution.v1` revision shared by Bot and Mini App UI, mirrored through native client persistence and deleted on account-session reset.
- [x] Exact `local.prayer-wheel.start` entitlement gate before prayer-wheel start and before accepting a returned hostRequest for that capability.
- [x] Explicit deterministic CI-only payment provider under `FABUSHI_FEATURE_HOST_MODE=test`, with intent idempotency, callback dedupe, durable entitlement and restore; production stays on canonical Pay/entitlement authority.
- [x] Packaged Electron E2E covers search -> install -> Bot -> natural language -> WebMCP -> open app same revision -> safe account projection -> CNY 1080 purchase -> restore -> prayer-wheel start -> restart recovery -> logout cleanup, with 12 named screenshots plus video/trace recording.
- [x] Linux light native contract gate: 35/35 PASS; no local heavy build/E2E.
- [x] Protected PR CI green and PR #2448 merged.
- [x] Protected merge to canonical main as `d7c8b45c3a7409d14d11bbf49107ff320b05ad84`.
- [x] Canonical-main packaged Electron Linux/macOS/Windows matrix green in Actions run `34052575208`; diagnostics artifacts `9995167107` / `9995176003` / `9995159094` retain screenshots/video/trace/report.

Evidence: `../../evidence/M9-GLOBAL-DHARMA-003/README.md`.

## 2026-09-07 Web/service credential dependency

The Host-controlled Mini App credential now has an explicit server-consumer contract: five-minute, session-bound, exact-plugin scope; canonical entitlement may consume it only for the matching plugin/capability read. Purchase/restore remain Host-authenticated Platform Router operations. This closes the Web/service side of the AAC-004 bootstrap/revoke gap without creating a second payment or identity authority.

## 2026-09-07 desktop evidence and Android blocker readback

- Desktop #2448 functional evidence head `1655ea8070e07ad7dd8ab8e9347fbcb43f6ddf8f` passed Electron run `34051925481`. Artifact `9994834346` contains checkpoints `01`-`12`, including exact CNY `108000` purchase, restore, entitled `local.prayer-wheel.start`, restart recovery and logout cleanup; Global Dharma journey WebM and trace are included.
- No real provider charge occurred: the desktop evidence uses the deterministic `FABUSHI_FEATURE_HOST_MODE=test` provider path while server-authoritative product/entitlement semantics remain unchanged.
- Android release `android-v1.2.52-262491811@380b6ed5a96a5b6d1295267e07d9c8dc45fa84ab` is immutable and checksummed. Interactive run `34051316405` did not reach terminal success; artifact `9994884584` reports `failed-timeout` after stale generation calls and App-owned connection refresh failure. Android purchase/restore/terminal evidence remains PENDING.

## 2026-09-08 — Canonical-main packaged desktop closure readback

- PR #2448 is merged; accepted feature merge SHA is `d7c8b45c3a7409d14d11bbf49107ff320b05ad84`.
- Exact-SHA `Electron desktop quality gate` run `34052575208` is SUCCESS. Linux, macOS and Windows packaged jobs all completed successfully, and the aggregate `Electron desktop result` job passed.
- Canonical-main diagnostics artifacts: Linux `9995167107`, macOS `9995176003`, Windows `9995159094`; all are tied to `main@d7c8b45c3a7409d14d11bbf49107ff320b05ad84`.
- macOS packaged evidence contains `global-dharma-user-journey.webm`, `trace.zip`, and checkpoints `01`-`12`. The journey proves Marketplace search/install, Bot projection, natural-language WebMCP execution, Telegram-style app opening at the same runtime revision, bounded logged-in account projection with `tokenExposed:false`, exact CNY `108000` lifetime purchase, restore, entitled `local.prayer-wheel.start`, restart persistence and logout cleanup.
- Desktop Round B is therefore `E2E_VERIFIED` for deterministic CI payment semantics. Overall task remains `IN_PROGRESS` because real PSP/provider activation, Round C production smoke/reconciliation, and fresh terminal mobile proof are not complete.
