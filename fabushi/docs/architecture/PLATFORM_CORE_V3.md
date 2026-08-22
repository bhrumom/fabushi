# Mahayana Platform Control Plane v3

Fabushi is a one-stop AI platform. Authentication, connected accounts, workspaces, AI agents, communication, marketplace, commerce, model usage and remote-computer control therefore need one coherent control plane rather than a collection of historical feature backends.

The canonical control plane is the Rust Cloudflare Worker at:

`third_party/mahayana/mahayana-rs/mahayana-platform-worker`

`fabushi/web` is a migration/compatibility boundary for historical content, practice and payment surfaces. It must not grow a second account/session platform.

## Design inputs

This is an independent Fabushi design that adopts architectural principles, not source code, from:

- **Cloudflare OS / Workshop**: browser-first login, authentication gatekeepers, minimum login scopes, connected capabilities requested separately, workspace ownership and capability-oriented authorization.
- **Telegram / TDLib**: stable typed identities, peer-oriented communication, conversations separated from users, explicit membership/read state, deterministic message ordering and retry idempotency.

Fabushi extends both ideas for a mixed human + AI-agent platform.

## Single source of truth

### ACCOUNT_DB

Identity and credential lifecycle belongs to `ACCOUNT_DB`:

- `account_principals`: immutable provider-independent account identity.
- `account_identities`: cryptographically verified sign-in issuer/subject identities.
- `account_contact_points`: verified email/phone values, not account primary keys.
- `account_password_credentials`: password credential material.
- `account_sessions` + `account_refresh_tokens`: rotating sessions and reuse detection.
- `account_oauth_attempts`: short-lived browser-first authorization capabilities.
- `account_connections`: persistent external capabilities that were explicitly connected after login.
- `account_connection_grants`: workspace-scoped permission to use a connection.

A sign-in OAuth grant is not a connected account. Login proves who the user is; it does not silently give the AI persistent access to repositories, mail, drives or other third-party resources.

### PLATFORM_DB

Product collaboration/runtime state belongs to `PLATFORM_DB`:

- workspaces and workspace members;
- AI agents and model/capability policy;
- stable peers for humans, agents and system actors;
- conversations, conversation members and ordered messages;
- marketplace publication metadata;
- double-entry wallet/commerce ledger and entitlements;
- AI usage reservations/events;
- remote-computer/listener control-plane state.

No fake foreign key is created across D1 databases. The Worker authenticates a principal through ACCOUNT_DB and then enforces its PLATFORM_DB membership/capability boundary.

## Browser-first authentication

The existing Mahayana flow remains authoritative:

1. App calls `POST /api/auth/browser/start`.
2. Worker creates a high-entropy short-lived attempt/ticket.
3. Browser login supports password or configured gatekeepers.
4. Provider flows use state and PKCE/nonce as appropriate.
5. Deep links contain only an attempt identifier/status, never account tokens.
6. App polls the one-time attempt and receives the session exactly once.
7. Refresh tokens rotate by family; reuse revokes the session family.

Packaged clients use `https://api.ombhrum.com`. Development may point to the workers.dev deployment.

## Identity model

The old `users` row mixes profile, provider ids, password migration, practice selection, membership and payment-era fields. It is now migration input, not the target model.

`principal_id` is the stable internal identity. Email, phone, Apple, Alipay, Google, Microsoft, GitHub and Cloudflare are identities or connections, never columns that define the principal.

The first migration is additive: historical numeric users receive a deterministic namespaced principal mapping. Existing access-token subjects stay compatible during the rollout; runtime code moves to principal resolution before old columns are removed.

## Workspace + unified human/agent communication

A workspace is the authorization boundary. AI agents are first-class workspace resources with explicit model and capability policy.

Humans and agents use one communication graph:

`principal/agent -> peer -> conversation membership -> message`

This replaces separate historical friend-message and bot-conversation stacks. Direct human chats and human-agent chats differ by conversation kind, not by transport implementation.

Each conversation owns a monotonically increasing message sequence. `client_nonce` provides retry idempotency. Read state belongs to membership, not to the user profile.

## Retired systems

The practice leaderboard / transfer-statistics subsystem is retired. It is not migrated into Platform Core and must not remain a deployment-secret or request-gate dependency.

Other legacy tables/routes remain only when production data or shipped clients still require a migration window. New capabilities may not be added to those compatibility surfaces.

## Refactor boundaries

The historical `fabushi/web/src/router.js` is an orchestrator only. Domain routing lives in core/auth/membership/commerce/community/content/ops/legacy-practice modules.

The Rust `worker_api.rs` is also being decomposed. New product domains must be implemented in dedicated modules; its size is a shrinking budget, never a target to increase. Planned/active boundaries are account/auth, workspace/messaging, marketplace, commerce, AI usage, listener relay, remote computer and common HTTP/security helpers.

## Migration order

1. Add normalized principal/connection/workspace/peer/message tables without dropping production data.
2. Backfill legacy users to principals and verified contact/identity mappings with reconciliation checks.
3. Route new workspace/messaging APIs through Mahayana Platform Worker.
4. Move provider/profile/membership reads out of the giant legacy user row.
5. Move existing domains out of the Rust and JS God files one at a time under CI.
6. Move all shipped clients to the single browser-first account flow and principal-aware APIs.
7. Stop legacy writes, observe a full release window, then remove compatibility tables/routes.

Destructive cleanup only happens after objective evidence shows zero required reads/writes.
