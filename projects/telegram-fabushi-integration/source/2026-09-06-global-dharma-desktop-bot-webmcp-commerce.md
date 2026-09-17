# 2026-09-06 — 全球法布施 Desktop Bot / WebMCP / Commerce closure

- Project: `FAB-P0001 / TFI`
- Cross-project governance: `FAB-P0008 / AAC`
- Canonical intake base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`
- Execution branch: `feat/tfi-global-dharma-desktop-webmcp-commerce-20260906`

## User requirement

Complete the desktop/Electron Global Dharma Mini App journey as a real product path rather than a mock or documentation-only path:

1. Marketplace search for `全球法布施` must discover and install the official `global-dharma` Mini App.
2. Installed state must project a `全球法布施` Bot into Messenger; the Bot accepts natural-language input.
3. Bot natural-language execution must resolve to the same app-scoped WebMCP Tool Contract used by the Mini App UI. Tool lifecycle, current page/surface, progress and resulting state must have one host-owned shared revision so that opening the Telegram-style `打开应用` UI shows the same state the Bot has reached.
4. An authenticated Fabushi desktop session must give the Mini App a controlled account session automatically. Raw Fabushi access/refresh tokens must never be disclosed to the Mini App or model; account state is host-mediated and account-scoped.
5. The official local prayer-wheel capability is protected by canonical Fabushi Monetization entitlement `local.prayer-wheel.start`; lifetime purchase is exactly CNY 1080.00 (`108000` minor units). The journey must preserve server-authoritative product/price, PaymentIntent/Order, callback/webhook idempotency, canonical entitlement access checks, restore/reconciliation, and a CI test mode. No client-local purchase flag may unlock the capability.
6. Required desktop simulated-user journey: search -> install -> open Bot -> natural-language send -> WebMCP execute -> open app -> verify shared state -> buy/restore entitlement -> local prayer wheel becomes usable.
7. Heavy build/package/E2E work runs only on GitHub Actions. Completion requires protected-main merge, canonical-main packaged Electron E2E, step screenshots, complete video, Playwright trace/report/logs and a real downloadable evidence link. Missing provider/package/permission/evidence must fail closed and be recorded as a blocker.

## Live baseline verified at intake

- `M8-WEBMCP-001` implementation PR `#2169` is already merged (`fefb35fc8a4e5c8dabecc9c11803764ec950b6e9`), although the task record still describes pre-merge closure gates.
- Desktop already injects app-scoped WebMCP and existing E2E proves Global Dharma search/install, Bot projection, natural-language routing, WebMCP tool discovery and account CloudStorage recovery.
- `M9-GLOBAL-DHARMA-003` Round A PR `#2135` is already merged (`db287caa1b8495c94bf9ecafe7f064bca2ee57a0`): canonical lifetime/monthly products, exact `local.prayer-wheel.start` capability, fail-closed entitlement policy and server-authoritative purchase options exist.
- M9 Round B remains incomplete on canonical main: desktop Host access check, createIntent/openCheckout bridge, hostRequest gate and purchase/restore E2E are not yet closed.
- `AAC-003` already owns authenticated-session recovery and public Marketplace discovery for `global-dharma`; this work extends that account boundary to controlled Mini App session projection without exposing credentials.

## Open-source-first startup gate

Reviewed before implementation:

- W3C/Web Machine Learning WebMCP repository (`webmachinelearning/webmcp`): use `document.modelContext` tool registration/discovery/execution semantics; reuse the existing Fabushi adapter rather than a second command mapping.
- Official MCP Apps repository (`modelcontextprotocol/ext-apps`): preserve a host-mediated, sandboxed AppBridge and explicit Host -> View tool-input/state notification shape for UI synchronization.
- Stripe official idempotency/webhook guidance as an external payment-design cross-check: retries require stable idempotency identity and webhook duplicate delivery must be deduplicated. Fabushi already has these concepts in canonical Rust Pay, so no Stripe-specific or second ledger is introduced.

Decision: extend Fabushi's existing app-scoped WebMCP host with one shared per-MiniApp execution/state projection; route Bot execution through that same host tool boundary; expose only a bounded account-session projection; consume the existing canonical Fabushi Pay product/intent/order/webhook/entitlement APIs. No third-party source code is copied.

## Security and authority invariants

- `main` + project records remain authoritative; chat state is not evidence.
- Mini App tool inventory is intersected with the installed app's signed/approved Tool Contract.
- Raw account tokens, PSP secrets and provider credentials stay in native/server trust boundaries.
- Amount, currency, product, entitlement capability and provider availability are server-authoritative.
- Write/destructive WebMCP operations retain Host approval semantics.
- Entitlement access is checked at the Host boundary immediately before `local.prayer-wheel.start`, not only in UI.
- Test mode must be explicit and impossible to activate as a production entitlement source.
