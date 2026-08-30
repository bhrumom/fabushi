# Fabushi Public MCP

## Value Proposition

Fabushi exposes a public remote MCP endpoint that any Fabushi user can add to ChatGPT or another compatible AI client. After the user signs in with their own Fabushi account, the AI can discover and control only devices where the Fabushi application is signed in to that same stable Fabushi `userId`.

The MCP is a product capability for all users, not a CI-only or GitHub-only integration.

**Core actions**
1. Sign in to the Fabushi MCP with a normal Fabushi account.
2. List online devices belonging to that Fabushi `userId`.
3. Invoke only the tools explicitly advertised by a selected same-account device.

## Why an AI Assistant

Users can ask the assistant to inspect, test, or operate their already-authenticated computers without manually navigating each device. The LLM contributes intent interpretation and multi-step tool orchestration; Fabushi contributes authenticated device identity, transport, authorization, and real actions.

## Authentication UX

- The public resource URL is `https://fabushi-mcp.ombhrum.com/mcp`.
- Adding the MCP starts a standard OAuth 2.0 Authorization Code + PKCE flow.
- The user is taken directly to the official Fabushi account login experience. There is no intermediate MCP-specific page requiring a second click.
- Fabushi account login may use any provider enabled for the account service (password/account identifier, email registration, Alipay, Google, GitHub, Microsoft, Apple, Cloudflare, etc.). Provider identities are login methods only; device ownership is always the resulting stable Fabushi `userId`.
- After login, the browser returns directly to the AI client's OAuth callback.
- The MCP access token is scoped to `devices.read` and/or `devices.control` and carries the Fabushi account identity.

## Device Ownership

- Every installed Fabushi client registers its device agent with a short-lived Fabushi account access token.
- The gateway resolves that token to a stable Fabushi `userId` and binds the live device to that account.
- `list_devices` returns only live devices whose bound account matches the MCP caller's `userId`.
- `device_call` rejects cross-account device IDs even when the caller knows the identifier.
- Logging out, lease expiry, workflow completion, or token expiry removes/invalidates the device presence.

## CI / Interactive Runner

GitHub Actions is only one source of a temporary Fabushi device. It must not define the public identity model.

For production CI testing, an interactive Runner may authenticate with a dedicated ordinary Fabushi test account supplied through protected GitHub Actions secrets. The resulting session is the same account session shape used by installed clients. A tester can then add the public MCP to ChatGPT and sign in with that same test Fabushi account to discover and control the Runner.

The existing GitHub OIDC actor-to-Fabushi mapping path may remain as an optional hardened mode, but it must not be required for normal users or for the dedicated test-account workflow.

## Security

- OAuth Authorization Code + PKCE S256; no bearer tokens in URLs.
- Dynamic client registration accepts only validated redirect URIs.
- Login return URLs are allowlisted to the MCP origin and are bound to the one-time browser-login attempt.
- MCP bearer tokens are short-lived, refreshable, account-scoped, and auditable.
- Device registration and every device call are account-scoped server-side; clients cannot choose an arbitrary owner id.
- CI credentials remain GitHub Actions secrets and are written only under `RUNNER_TEMP` with restrictive permissions.

## Product End State

A user should experience Fabushi MCP like a first-party account-scoped connector: add the MCP URL, sign in once with their Fabushi account, return to the AI client, and immediately see only their own currently online Fabushi devices.