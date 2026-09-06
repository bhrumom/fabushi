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
