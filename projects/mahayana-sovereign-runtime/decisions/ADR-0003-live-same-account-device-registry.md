# ADR-0003 — Live same-account device registry with explicit ephemeral lifetime

Status: accepted
Date: 2026-09-17

## Context
Fabushi products can run on long-lived user computers and short-lived CI runners. The official MCP must discover every live controllable installation belonging to the authenticated Fabushi account, while avoiding stale/offline inventory and avoiding a separate account/device pairing step after product login.

## Decision
1. **Account authority:** device registration uses a short-lived credential derived/exported from the already authenticated Fabushi product session. Refresh credentials never enter device registration messages or logs.
2. **Live registry only:** the MCP device gateway is presence-oriented. `list_devices` returns only currently connected, non-expired devices for the MCP caller's account. Offline entries are not an account inventory.
3. **Persistent installations:** a normal installed CLI/App may keep a stable local installation ID so reconnects are recognizable, but it is absent from `list_devices` whenever its authenticated device connection is offline.
4. **Ephemeral installations:** CI runners use run-scoped IDs and TTL, derived from trusted runner/run metadata when available. They are never written as durable account devices and disappear on socket close or expiry.
5. **Automatic product binding:** successful CLI/App login starts or refreshes the device agent automatically; logout stops it and removes the exported bounded device credential.
6. **Fail closed:** account mismatch, expired token, invalid resource/audience, or missing tool policy rejects registration/control.
7. **Installer boundary:** one-line installers install signed/released CLI artifacts only; they do not embed account secrets and do not auto-login.

## Consequences
- Official MCP discovery becomes consistent across CLI, desktop/mobile app-owned agents, and GitHub-hosted runners.
- There is no stale device-list cleanup UX because offline devices are naturally absent.
- Device identity and device presence are separate concepts: stable installation ID does not imply persistent server inventory.
