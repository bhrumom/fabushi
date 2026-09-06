# M8-WEBMCP-002 evidence — Global Dharma Web/service shared runtime

Status: **IMPLEMENTED / PR_CI_PENDING / PACKAGED_PROVIDER_E2E_BLOCKED**

## Exact lineage

- Canonical intake base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`.
- Governed branch: `feat/tfi-global-dharma-web-service-sync-pay-20260906`.
- Persisted source: `projects/telegram-fabushi-integration/source/2026-09-06-global-dharma-web-service-sync-commerce.md` (`2eb4b0cf524942f003bc6ec973ba8119745b2030`).
- Implementation commit: `f9a2df5850e81bd5f1fbe3450adf4ec4e3b0f906`.
- Protected PR / current-head CI: pending at this record revision; exact IDs must be reported from live GitHub, not guessed.

## Reproducible contract/integration evidence added

- `ai-backend/test/global_dharma_shared_runtime.test.js`
  - canonical Tool Contract == official MCP `tools/list`;
  - Bot natural language executes the exact official MCP handler;
  - Bot/WebMCP cross-session convergence through one account runtime;
  - monotonic revision + `as1` cursor; cursor-ahead snapshot recovery;
  - operation idempotent replay and conflicting-key rejection;
  - account isolation;
  - fail-closed prayer-wheel entitlement gate.
- `ai-backend/test/global_dharma_http_integration.test.js`
  - Chinese Marketplace discovery + install;
  - same-account/two-session installed projection;
  - protected runtime endpoint requires authenticated account;
  - shared runtime difference and cross-account isolation;
  - CNY 108000 lifetime purchase option projection without raw session token in response.
- `fabushi/web/tests/global-dharma-web-sync-contract.test.js`
  - WebMCP explicit approval remains present;
  - writes include operationId;
  - Web UI consumes durable snapshot/difference cursor rather than MCP session state as business truth.
- `fabushi/web/tests/global-dharma-paid-capability.test.js`
  - exact CNY 108000 lifetime catalog;
  - PaymentIntent/order idempotency;
  - provider webhook inbox dedupe;
  - entitlement only after succeeded capture;
  - full refund revokes entitlement and order;
  - restore is authenticated server-side order reread.

## Runtime design evidence

- `ai-backend/src/global_dharma_tool_contract.js`: one canonical Global Dharma Tool Contract drives Marketplace domain commands and official MCP metadata.
- `ai-backend/src/global_dharma_runtime_store.js`: shares the existing AccountSync SQLite/WAL authority and records `miniapp.runtime.updated` into the same `as1` journal; it does not introduce NATS/WebSocket/EventStore as a second authority.
- `ai-backend/src/miniapp_marketplace_mcp.js`: Global Dharma Bot calls the official MCP server through an in-memory MCP transport; there is no second business handler.
- `frontend/apps/web/src/app/miniapps/[id]/McpPluginApp.tsx`: opens from durable snapshot then catches up from the current `as1` cursor; reconnect can recover from difference or snapshot.
- `frontend/apps/web/src/app/miniapps/[id]/WebMcpMiniAppAdapter.tsx`: retains foreground write confirmation and supplies stable operation identity.

## Canonical payment facts audited, not duplicated

- Round A PR #2135 is already merged as `db287caa1b8495c94bf9ecafe7f064bca2ee57a0`.
- Canonical catalog owns monthly CNY 3000 / lifetime CNY 108000 and capability `local.prayer-wheel.start`.
- `payment_api.rs` claims provider webhook events with `INSERT OR IGNORE`; duplicate provider event identity cannot be processed twice.
- Succeeded capture creates the order/entitlement; full refund sets the PaymentIntent/order refunded and active entitlement `revoked`.
- `/v1/purchases/restore` authenticates the account and rereads canonical server orders; client local purchase flags are not an authority.
- This Web/service change adds no second payment ledger or PSP-specific truth.

## OSS-first evidence

Reviewed before implementation: MCP TypeScript SDK Streamable HTTP resumability; TDLib update/difference state recovery; NATS JetStream durable consumers; Auth.js; Better Auth; Stripe Node idempotency/webhook conventions. Decision: reuse existing MCP SDK + existing AccountSync journal + existing Fabushi auth/pay. NATS/Auth.js/Better Auth/Stripe-specific ledger were rejected because they would create parallel authorities.

## CI evidence contract

`.github/workflows/global-dharma-web-service-contract.yml` has three independent jobs and `always()` artifact upload:

1. `Backend MCP/runtime/account contract` -> syntax + MCP/runtime/Marketplace/account integration TAP/logs.
2. `Web Mini App production build` -> production build only; no deployment.
3. `CNY 1080 order/webhook/refund/restore contract` -> payment + Web sync TAP/logs.

The repository's `deploy-miniapps-cloudflare.yml` deploys on any branch push touching `frontend/apps/web/**`. The implementation commit therefore used `[skip ci]` intentionally so a feature-branch push did not deploy production. A later docs-only commit opens the PR and lets pull-request gates run without a branch production deployment.

## Hard blockers / non-evidence

- **Hosted account auto-login is not yet proved end to end.** The server requires a stable authenticated account and redacts raw credentials, but the independent Hosted Web page still needs a verified Host-controlled credential bootstrap. Existing candidates are the Electron credential gateway and the five-minute `auth.requestToken` delegated plugin token; the repo currently has a delegated-token issuer but no verified consumer path for `PluginAccessTokenClaims`. AAC-004 remains open until the packaged Host proves this boundary.
- **Provider sandbox is not available/proved in this round.** `developer-fiat-commerce.yml` is currently intentionally paused; real PSP/KYC/provider credentials cannot be fabricated.
- **No packaged-user video exists yet for this branch.** No link is recorded until a real installable accepted-main package/device lane performs search -> install -> Bot -> natural language -> tools/list/tools/call -> open app -> sync -> pay/restore -> entitlement -> feature and uploads video/screenshots/trace/logs.
- These blockers keep this evidence `IN_PROGRESS`; contract green alone is not packaged/provider completion.
