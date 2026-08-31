# ADR-0008 — Tailscale-inspired account device mesh

- Status: Accepted for implementation
- Date: 2026-08-31
- Project: `FAB-P0004 / GBF`
- Task: `GBF-412`

## Context

Fabushi already has an account-scoped WSS device gateway, dynamic MCP tool catalogs, secure-input exchange, an Electron device-agent supervisor, and native App MCP semantic surfaces. The missing pieces are durable node identity, an explicit transport/path model, native mobile registration/dispatch, and end-to-end evidence that installed and logged-in devices are discoverable and controllable.

Tailscale demonstrates a mature separation between identity/control state and a data plane whose path can move between direct endpoints and relays. Its BSD-3-Clause code and tests are valid upstream research inputs, but copying the entire VPN product would duplicate Fabushi authorization, add unrelated network-routing scope, and not provide the proprietary mobile GUI wrappers.

## Decision

Fabushi will implement one first-party **account device mesh** inside its existing remote MCP architecture.

### Identity and trust

- Fabushi account access tokens authenticate the account boundary only.
- Every device also owns a persistent P-256 node key.
- The device signs each registration over device id, connection generation, tool schema version, nonce and node public key.
- The gateway verifies the signature, stores only the public key/fingerprint, and binds calls to the currently registered socket generation.
- Private node keys remain in the platform secure store where available; filesystem fallbacks are private mode and limited to CI/desktop compatibility.

### Control plane

- The existing Fabushi gateway remains the authoritative control plane for account isolation, device leases, tool catalogs, permissions and audit.
- Public device state gains a versioned mesh section: node fingerprint, signed status, features, supported/preferred/active path, posture and tags.
- Desired-state updates and future path candidates must be versioned and generation-bound.

### Data path

- Phase 1 uses the existing TLS WebSocket relay as the reliable baseline path.
- The protocol models path state immediately, so direct UDP/WebRTC/QUIC candidates can be added later without changing MCP tool names or authorization.
- A direct path may only be selected after authenticated candidate exchange and health validation; relay remains the automatic fallback.
- No product claim may say a direct path exists until CI/live evidence proves it.

### Platform adapters

- Electron retains the current child agent and full Computer Use tools.
- Android publishes the shared App MCP contract through a foreground-capable native agent, with explicit user-visible service state when persistent operation is requested.
- iOS publishes the same contract while active and uses supported background execution/wake mechanisms. Suspension is reported as offline/unavailable rather than hidden behind a false heartbeat.
- All adapters use the same device registration and call/result envelopes.

### Upstream provenance

- Architectural concepts are adapted from `tailscale/tailscale`, BSD-3-Clause.
- Any future copied or modified upstream source must retain SPDX/copyright notices and be listed in the provenance ledger.
- This ADR currently authorizes a clean-room Fabushi protocol implementation, not wholesale source vendoring.

## Consequences

Positive:

- Same-account discovery and authorization remain simple and auditable.
- Node identity survives access-token refresh and detects registration spoofing.
- Relay reliability is preserved while the protocol can evolve toward direct paths.
- Mobile and desktop use one tool contract and one gateway.

Tradeoffs:

- Phase 1 does not yet provide a WireGuard VPN or direct peer data path.
- iOS availability follows platform lifecycle limits.
- Secure key storage requires separate Android Keystore, Apple Keychain/Secure Enclave and desktop implementations.

## Rejected alternatives

1. **Fork the entire Tailscale product into Fabushi.** Rejected because it duplicates unrelated VPN routing/DNS/admin surfaces and does not include every GUI wrapper.
2. **Keep bearer-token-only registration.** Rejected because a leaked short-lived account token could impersonate a device until expiry.
3. **Create a second mobile-only gateway.** Rejected because it fragments authorization, audit and discovery.
4. **Claim permanent iOS background presence.** Rejected because it conflicts with OS lifecycle guarantees and would make online state untrustworthy.
