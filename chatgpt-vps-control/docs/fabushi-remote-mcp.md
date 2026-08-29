# Fabushi account-scoped remote MCP

Fabushi exposes its device registry and Computer Use bridge as a standard remote MCP so an external AI client, including ChatGPT, can control a computer that is logged into the same Fabushi account. The controlled desktop remains the execution authority: the remote service only discovers devices, describes their published tools and relays bounded calls to the selected device.

## Public endpoints

For the production deployment described here:

- MCP connector: `https://fabushi-mcp.ombhrum.com/mcp`
- OAuth issuer: `https://fabushi-mcp.ombhrum.com`
- Device agent: `wss://fabushi-mcp.ombhrum.com/agent`
- Health check: `https://fabushi-mcp.ombhrum.com/health`

The Node service binds only to `127.0.0.1:8792`; the existing authenticated Cloudflare Tunnel supplies HTTPS and WebSocket transport. The origin service is not opened on a public interface.

## Identity and authorization

1. An MCP client dynamically registers a callback URL.
2. Authorization Code + PKCE opens the existing Fabushi browser-login flow.
3. The completed Fabushi session is verified through the account API.
4. The MCP service issues its own scoped access/refresh tokens containing only the stable Fabushi account id, display label, client id, resource and scopes. It does not persist the original Fabushi access token.
5. A desktop or temporary Runner connects to `/agent` with an ordinary Fabushi access token. The gateway resolves that token to the same account id.
6. Device registry keys are `accountId + deviceId`; listing and calls require the MCP token's account to match.

The service applies bounded client, authorization, code, token, device and pending-call registries, short authorization/code lifetimes, device leases, heartbeat expiry, exact socket-generation binding and audit events with hashed account references.

## GitHub Actions Runner flow

`.github/workflows/interactive-runner-mcp.yml` starts the device agent before compiling the desktop app. ChatGPT can therefore discover the Runner and query `ci_session_status` while the build is running. After packaging, the same device id reconnects through the package's embedded Computer Use stdio MCP; the workflow then starts the packaged Fabushi app in Xvfb and records the live session.

Use these tools in order:

1. `list_devices`
2. `describe_device_tool` for any unfamiliar device tool
3. `device_call` with `ci_session_status`
4. Computer Use reads and actions against the packaged Fabushi app
5. `device_call` with `ci_session_note` for important observations
6. `device_call` with `ci_session_finish` after validation

The workflow uploads only an explicit evidence allowlist: status, notes, redacted device-call trace, generated regression candidate, video, screenshot and process logs. Account sessions and tokens are never included.

## Server installation

Install the checked-out `chatgpt-vps-control` package under `/opt/fabushi-remote-mcp/current`, run `npm ci --omit=dev --ignore-scripts`, create the system user `fabushi-mcp`, copy the example environment to `/etc/fabushi-remote-mcp.env`, install `systemd/fabushi-remote-mcp.service`, and add the Cloudflare Tunnel ingress mapping:

```yaml
- hostname: fabushi-mcp.ombhrum.com
  service: http://127.0.0.1:8792
```

Keep the final `http_status:404` rule last. Validate the tunnel configuration before restarting it, then verify `/health`, OAuth metadata, an unauthenticated `/mcp` challenge and a WebSocket authentication rejection.

## Rollback

Stop and disable `fabushi-remote-mcp.service`, remove the hostname ingress, restart the tunnel and revoke/delete `/var/lib/fabushi-remote-mcp/state.json`. The existing private packaged stdio Computer Use runtime continues to operate independently.
