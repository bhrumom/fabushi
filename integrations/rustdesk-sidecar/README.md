# Fabushi RustDesk sidecar

This directory is the license and runtime boundary for RustDesk-derived remote-control code used by Fabushi.

## Boundary

- Fabushi remains authoritative for account identity, same-account device membership, session creation, user authorization, least-privilege grants, revocation, expiry and audit.
- The sidecar is a separately built and distributable AGPL-3.0-only derivative of the pinned RustDesk upstream source in `UPSTREAM.lock`.
- Fabushi account tokens, cookies and long-lived device credentials MUST NOT be passed into the RustDesk process. A controller may pass only an already-authorized session identifier, an ephemeral transport credential, target RustDesk peer id, route policy and the immutable per-session capability grant.
- Sidecar control is inherited stdin/stdout only. It MUST NOT open an unauthenticated TCP/HTTP control listener.
- Permission escalation is forbidden after session creation. A new Fabushi session is required for broader capabilities.
- Session close, Fabushi client revocation, target device revocation or expiry must terminate the RustDesk connection and erase ephemeral controller state.

## Source availability and attribution

The build workflow clones the exact public RustDesk commit recorded in `UPSTREAM.lock`, applies the source overlay in this directory and builds the sidecar from source. The resulting derivative is distributed under AGPL-3.0-only, with RustDesk attribution and corresponding source/overlay available from the same Fabushi release source tree. No RustDesk logos, branding assets or other non-code assets are copied into Fabushi.

## Protocol

The sidecar accepts newline-delimited JSON on stdin and emits newline-delimited JSON events on stdout. The protocol version is `fabushi.rustdesk-sidecar.v1`.

Controller commands are `hello`, `open`, `mouse`, `key`, `clipboard`, `file`, `audio`, `reconnect` and `close`. Every command after `open` includes the Fabushi `sessionId`. `open` carries the immutable grant `{display,input,clipboard,fileTransfer,audio}` and a direct/relay policy. Sidecar events include `ready`, `route`, `display`, `frame`, `clipboard`, `fileProgress`, `audio`, `error`, `disconnected` and `closed`.

Frame/audio/file payloads are bounded and never written to Fabushi audit logs; audit records contain only session/device/provider/route/capability/result metadata.
