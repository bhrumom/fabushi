# M9-GLOBAL-DHARMA-003 desktop WebMCP / entitlement evidence

State: `IMPLEMENTATION_IN_PROGRESS`
Date: `2026-09-06`
Intake main: `8f7e83902a616ecdb62fdaded65ea79227e745f3`
Execution branch: `feat/tfi-global-dharma-desktop-webmcp-commerce-20260906`

## Scope under verification

- Marketplace search/install of `global-dharma` and Messenger Bot projection.
- Bot natural-language route resolves the installed Mini App Tool Contract and executes through the same WebMCP host function used by the iframe.
- Host-owned `fabushi.miniapp.execution.v1` durable revision is pushed to an open iframe and read back when the iframe is opened later or the app restarts.
- Mini App receives a bounded authenticated session projection only; no access/refresh bearer credential is exposed.
- Exact `local.prayer-wheel.start` entitlement is checked before a prayer-wheel start and again before accepting a returned hostRequest for that capability.
- Lifetime CNY 1080.00 comes from canonical server purchase options. The Platform Router exposes only user create-intent/get-intent/checkout Pay routes; provider/admin routes remain outside the facade.
- Explicit `FABUSHI_FEATURE_HOST_MODE=test` provides deterministic intent/callback/idempotency/restore semantics for packaged CI without becoming a production entitlement source.

## Local light gate

- `git diff --check`: PASS.
- `node --test desktop/electron/edge-ipc.test.cjs desktop/electron/native-capability-handlers.test.cjs`: 35/35 PASS on Linux.
- No local Electron build, Cargo build, package build or Playwright E2E was run.

## Planned protected evidence

The existing Electron workflow runs packaged E2E outside PR context and records `trace: on`, `video: on`; its `always()` artifact upload includes `desktop/playwright-report/**` and `desktop/test-results/**` for 90 days. The extended `desktop/e2e/miniapp-bot-parity.spec.ts` writes eleven named step screenshots into that artifact.

Do not mark COMPLETE until real values replace every PENDING field:

- implementation commit: `8fa7e9dc31f6dc8d75242b28dfbe92eb1b106d59`
- pull request: `#2448` (`feat(desktop): close Global Dharma WebMCP commerce loop`)
- PR checks: `PENDING RERUN` — initial head run `34047027979` failed native TS/CJS parity and `34047028119` failed rustfmt; both root causes fixed in `6f094d3f`, then latest `main@8595a50196309c8ebb91c3f8077125d7dc9e3ffa` merged into the branch
- protected merge SHA: `PENDING`
- canonical-main Electron workflow run: `PENDING`
- Linux/macOS/Windows packaged jobs: `PENDING`
- diagnostics artifact IDs: `PENDING`
- video file(s): `PENDING`
- trace/report: `PENDING`
- downloadable artifact/video link: `PENDING`

Missing packages, permissions, provider bindings, workflow gates or artifacts are blockers, never evidence of success.

## 2026-09-07 current evidence

- Desktop pre-package run: `34051925481` SUCCESS on `1655ea8070e07ad7dd8ab8e9347fbcb43f6ddf8f`; artifact `9994834346` (`sha256:1bf06fa2d3a6dc308a118ea173a392ece92049dfb1053cf78fb9331445ea3e14`). Contains 12 named PNGs, `global-dharma-user-journey.webm` (`sha256:3afde68f3855faf4c7b3bf2e1e363866ab7f609ef8442037566f0f1cabb3c7b8`) and `trace.zip` (`sha256:b0f83cf852c19b3d8be72045c5c203dbd8d079d52c6f4e30d55780801f8971f0`).
- Android 1.2.52 release: run `34050780156` SUCCESS; artifact `9994614114`; tag `android-v1.2.52-262491811` targets `380b6ed5a96a5b6d1295267e07d9c8dc45fa84ab`.
- Android interactive: run `34051316405` FAILURE; artifact `9994884584` (`sha256:dfad88db72093413f625963f1f9ff7898266e81a9211a09b41d99cc304d3d852`). `report.json` says `failed-timeout`; six semantic tool classes appear in trace, but two actions fail `stale_app_surface_generation` and the App-owned channel terminates with `connection-refresh-failed`, not `logged-out`. Full Android journey/video remains PENDING.

## 2026-09-08 authoritative desktop current-main readback

This readback supersedes the historical desktop `PENDING` fields above. The overall M9 record stays open for mobile and real production-provider delivery.

- Protected implementation merge: #2448 -> `d7c8b45c3a7409d14d11bbf49107ff320b05ad84`.
- Exact Mini App entry repair: #2476 makes literal query `小程序` discover/install `全球法布施`; #2481 makes the exact-entry test part of the packaged macOS evidence gate.
- Current WebMCP/UI repair: #2486 -> `f4364d9b79449d2c55deeeca18204ff93ef1ed3e`, covering canonical production `/v1` fallback handling, natural-language argument mapping to `content`, and the graphical Global Dharma WebMCP UI.
- Accepted source readback: `main@77f72b13304b75a45530de03fb807f52c3624be1`.
- Canonical-main Electron workflow: run `34115411357`, SUCCESS. Linux `101720936725`, macOS `101720937161`, Windows `101720937232`, aggregate result `101724595866` are all SUCCESS.
- Current-main package artifacts: macOS `10016425667`, Windows `10016410170`, Linux `10016273903`.
- Current-main diagnostics: macOS `10016406321` (`sha256:1c60a3d9725d08ec65044c94fd1c31d128663bba9b0b52819f24d99f8d49ea97`), Windows `10016396451`, Linux `10016261244`.
- macOS diagnostics contains exact-entry evidence `01-search-miniapp-finds-global-dharma.png`, `02-global-dharma-installed-from-miniapp-search.png`, `miniapp-search-entry-user-journey.webm`, then full parity checkpoints `01-authenticated-messenger.png` through `12-logout-clears-miniapp-session-and-execution.png`, `global-dharma-user-journey.webm`, `global-dharma-user-journey-restart-logout.webm`, Playwright `trace.zip`, and HTML report.
- Downloaded-byte verification of the three current-main macOS recording segments:
  - `miniapp-search-entry-user-journey.webm`: `sha256:568f3204061e252abfa60f368f196643ecbb20c6ea1618c0213a75540e1b40cc`.
  - `global-dharma-user-journey.webm`: `sha256:a1bfd4dd378e0abe6f0d235152c529d0490a6cf45ecd076a1af20ed7697d2872`.
  - `global-dharma-user-journey-restart-logout.webm`: `sha256:f807f8928842c24e2f68fe1726c435c13a91eac9b4f40f559fb732412af472bd`.
- Evidence semantics: exact `小程序` discovery/install -> Global Dharma Bot projection -> natural-language WebMCP -> Telegram-style `打开应用` -> same durable revision/state -> bounded automatic Fabushi session projection -> CNY `108000` lifetime test purchase -> restore -> canonical entitlement permits `local.prayer-wheel.start` -> Bot/UI shared-state follow-through -> restart recovery -> logout cleanup.
- Payment evidence is intentionally non-charging: `FABUSHI_FEATURE_HOST_MODE=test` exercises canonical product/intent/order/entitlement/restore behavior without a real RMB transaction. Real PSP credentials/KYC/provider activation remain production blockers and are not simulated as complete.
- Desktop acceptance state: `CURRENT_MAIN_PACKAGED_E2E_ACCEPTED`. Android/native terminal completion and production payment deployment remain separate `IN_PROGRESS` gates.
