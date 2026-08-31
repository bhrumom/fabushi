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


## App MCP tools after device discovery

The connector URL and account flow do not change. After `list_devices`, inspect
the selected device's live catalogue with `describe_device_tool`. New desktop
and Runner builds publish these additive tools:

- `fabushi.app.status`
- `fabushi.app.snapshot`
- `fabushi.app.find`
- `fabushi.app.action`
- `fabushi.app.wait`
- `fabushi.app.assert`
- `computer_control_route`

Use `fabushi.app.*` to test Fabushi through stable semantic IDs and exact UI
generations. Continue using the existing browser and native `computer_*` tools
for every other application; an application is not required to implement App
MCP. `computer_control_route` returns the preferred App MCP -> browser semantic
-> native semantic -> coordinate fallback order without hiding or removing any
underlying tool.

The packaged app exposes its semantic surface through a loopback-only bridge
with a per-process bearer and a private discovery file. No arbitrary
JavaScript, shell, reflection, or internal-function tool is added. Typed values
are excluded from the remote device trace, and sensitive fields require the
existing encrypted secure-input flow.

## GitHub Actions Runner flow

`.github/workflows/interactive-runner-mcp.yml` builds or downloads the real desktop package, launches it in Xvfb, and provisions the same protected account session that the installed application uses. Only the application starts and owns the device-registration child process and embedded Computer Use MCP. The Runner is intentionally undiscoverable until the logged-in Fabushi application is running.

This is also the production ownership model. A signed installed application polls its Rust-owned account session from the trusted Electron main process, exports only the current access credential to an owner-only file, and registers the application device with the official gateway. Refresh credentials never leave the account session store. Logout or application shutdown removes the credential and stops device registration. The public plugin only discovers devices belonging to its authenticated Fabushi account and relays calls to the tools advertised by those applications.

Use these tools in order:

1. `list_devices`
2. `describe_device_tool` for any unfamiliar device tool
3. `device_call` with `ci_session_status`
4. Computer Use reads and actions against the packaged Fabushi app
5. `device_call` with `ci_session_note` for important observations
6. `device_call` with `ci_session_finish` after validation

The workflow uploads only an explicit evidence allowlist: status, notes, redacted device-call trace, generated regression candidate, video, screenshot and process logs. Account sessions and tokens are never included.


### GitHub-linked Runner identity

The default interactive Runner uses the protected ordinary CI test account, then exports a non-refreshable application session valid only for that run. An optional GitHub-linked mode requests a GitHub Actions OIDC assertion for the `fabushi-ci-runner` audience. The Platform Worker verifies the exact repository and owner ids, workflow ref and source SHA, protected ref, event, GitHub-hosted environment, assertion age and derived device id, then resolves the workflow actor's GitHub identity to its existing Fabushi account. In both modes only the packaged application consumes the bounded CI session and registers the device.

To see the Runner in ChatGPT, add `https://fabushi-mcp.ombhrum.com/mcp` and sign in to Fabushi with the same GitHub account that dispatched the workflow. `list_devices` then returns only devices in that Fabushi account namespace, including the live `gha-<run>-<attempt>-interactive` Runner.

## Server installation

Install the checked-out `chatgpt-vps-control` package under `/opt/fabushi-remote-mcp/current`, run `npm ci --omit=dev --ignore-scripts`, create the system user `fabushi-mcp`, copy the example environment to `/etc/fabushi-remote-mcp.env`, install `systemd/fabushi-remote-mcp.service`, and add the Cloudflare Tunnel ingress mapping:

```yaml
- hostname: fabushi-mcp.ombhrum.com
  service: http://127.0.0.1:8792
```

Keep the final `http_status:404` rule last. Validate the tunnel configuration before restarting it, then verify `/health`, OAuth metadata, an unauthenticated `/mcp` challenge and a WebSocket authentication rejection.

## Rollback

Stop and disable `fabushi-remote-mcp.service`, remove the hostname ingress, restart the tunnel and revoke/delete `/var/lib/fabushi-remote-mcp/state.json`. The existing private packaged stdio Computer Use runtime continues to operate independently.
