# AAC-004 — Mini App controlled Fabushi account session

- Project: `FAB-P0008 / AAC`
- Status: `IN_PROGRESS`
- Started: `2026-09-06`
- Canonical intake base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`
- Current canonical main readback: `main@8595a50196309c8ebb91c3f8077125d7dc9e3ffa`
- Current synchronized Web/service head: `a53b576ab99f0c3fbeed65e4e3937424d9abd3c6`
- Branch: `feat/tfi-global-dharma-web-service-sync-pay-20260906`
- Parent product task: `FAB-P0001/TFI M8-WEBMCP-002`
- Source: `../../../telegram-fabushi-integration/source/2026-09-06-global-dharma-web-service-sync-commerce.md`

## Objective

Allow an already-authenticated Fabushi user to open/install/use an official Mini App without a second login while keeping the raw Fabushi access token, refresh token and provider credentials outside the Mini App/model boundary. Server/Host resolves the canonical account and exposes only the minimum app-scoped account/session projection required for runtime, sync and entitlement reads.

## Acceptance

- [ ] MCP, runtime-state, Marketplace account mutation and commerce/entitlement routes resolve one stable Fabushi user/account identity; bearer/cookie/session transport identifiers are not used as ownership namespaces.
- [ ] A valid Fabushi session automatically scopes `global-dharma` runtime and installed state to the authenticated account.
- [ ] Raw access/refresh tokens are never serialized into MCP structuredContent, Mini App runtime state, account-sync events, browser localStorage or model-visible tool arguments/results.
- [ ] Session revoke/logout causes subsequent protected Mini App runtime/commerce reads to return unauthenticated/fail closed; old account runtime cannot be read under another account.
- [ ] Public Marketplace browse remains independent of revoked/expired session, preserving AAC-003 behavior.
- [ ] Same account with different valid device/session tokens converges to the same Mini App runtime and entitlement authority; different account remains isolated.
- [ ] Contract/integration tests cover redaction, same-account convergence, cross-account isolation and revoked-session denial.
- [ ] Changes pass protected PR gates and exact canonical-main readback before this task can be completed.

## Reuse / non-goals

- Reuse canonical Fabushi auth and `/api/auth/user-info`/`resolveUser` identity boundary; do not add Auth.js/Better Auth or a parallel auth database.
- Reuse AAC-003 terminal-session cleanup and public Marketplace decoupling.
- Do not expose raw auth material to Mini App JavaScript as a convenience token.
- Do not mark entitlement from a client purchase flag; server-side canonical entitlement read remains authoritative.

## Evidence

- Intake/audit source: `projects/telegram-fabushi-integration/source/2026-09-06-global-dharma-web-service-sync-commerce.md` at commit `2eb4b0cf524942f003bc6ec973ba8119745b2030`.
- Implementation commit: `f9a2df5850e81bd5f1fbe3450adf4ec4e3b0f906`; protected PR/CI and packaged Host credential-bootstrap evidence remain pending.
