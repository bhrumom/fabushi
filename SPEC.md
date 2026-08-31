# Fabushi Cross-Platform Device Mesh

## Value Proposition
Fabushi users should be able to install Fabushi on any supported desktop or mobile device, sign in once, and have that device become discoverable and remotely operable from another authenticated Fabushi client or AI assistant without manually configuring a separate VPN product.

The current pain is fragmented remote-control plumbing: discovery, identity, App MCP, Computer MCP, relay connectivity, direct connectivity, mobile lifecycle, and platform-native implementations can drift independently. The product must present one account-scoped device mesh with the same security and control contract on desktop, Android, and iOS.

**Core actions**:
1. Discover live devices that belong to the authenticated Fabushi account.
2. Invoke App MCP or generic Computer MCP tools on a selected device.
3. Prefer an authenticated encrypted direct path and fall back transparently to the Fabushi relay when direct connectivity is unavailable.

## Why LLM / MCP?
**Conversational win**: a user can ask an assistant to find a signed-in device and operate an application or computer without manually selecting network routes, ports, or remote-control protocols.

**LLM adds**: intent interpretation, dynamic tool selection, choosing App MCP when available and generic Computer MCP otherwise, and composing multi-step device workflows.

**What the LLM lacks without Fabushi**: account-scoped device discovery, device identity, route establishment, authorization, native application/computer capabilities, execution audit, and the ability to perform real actions on the user's devices.

## UI / Agent Journey
**First state**: after Fabushi sign-in, the device registers a persistent signed mesh identity, publishes capabilities, and appears in the authenticated account's device list while its platform lifecycle permits availability.

**Discovery**: another Fabushi client or MCP consumer lists only live devices for the same account. Each device exposes platform, capabilities, tool catalog, posture, current route, and route health without leaking sensitive local data.

**Invocation**: the caller selects a tool from the live device catalog. App-specific MCP tools are preferred when an application publishes them; generic Computer MCP remains available as the fallback for applications without an App MCP surface.

**Transport**: peers exchange signed direct-path candidates through the control plane. The data plane probes viable candidates, authenticates the peer node identity, derives an ephemeral session key, and uses an encrypted direct route when healthy. Calls automatically fail over to the relay with bounded retries and without replaying already committed side effects.

**End state**: the caller receives the tool result plus route observability. If the direct path degrades, subsequent traffic uses the relay until direct health recovers with hysteresis.

## Product Context
- **Existing products**: Fabushi desktop, Android, iOS, web/MiniApp surfaces, Remote MCP gateway, App MCP surface, generic Computer MCP surface.
- **Account scope**: device discovery and authorization are restricted to the authenticated Fabushi account.
- **Control plane**: Fabushi gateway owns registration, leases, peer maps, candidate exchange, revocation, capability publication, route health, and audit metadata.
- **Data plane**: direct UDP is preferred where viable; existing secure relay/WebSocket transport remains the reliability fallback.
- **Identity**: persistent P-256 node identity, signed registration, public-key fingerprint pinning, generation/rotation/revocation, and stale-identity rejection.
- **Direct crypto**: P-256 ECDH, HKDF-SHA256 session key derivation, AES-256-GCM authenticated encryption, monotonically increasing per-session sequence numbers, replay rejection, and authenticated associated data binding account/device/session/message metadata.
- **NAT traversal**: host candidates plus STUN-discovered server-reflexive candidates; direct probing must not block relay availability.
- **Mobile lifecycle**: Android and iOS publish presence only while the OS lifecycle permits the agent to run. iOS must not pretend to be permanently online in the background.
- **Safety**: tool execution preserves existing permission checks, sensitive-input rules, redaction, and audit behavior independent of transport route.
- **Testing constraint**: implementation validation is performed through GitHub Actions and the authenticated `fabushi_test` MCP test account/device harness.

## Acceptance Criteria
1. Desktop/gateway direct-path unit tests cover signed peer authentication, ECDH/HKDF/AES-GCM encryption, tamper detection, replay rejection, sequence handling, timeouts, retry policy, direct-to-relay fallback, route hysteresis, candidate parsing, and STUN IPv4 server-reflexive discovery.
2. Android compiles and lints with the native direct-path implementation integrated into the mobile device agent; lifecycle and candidate publication use the same control-plane schema as desktop.
3. iOS compiles and runs unit/UI tests on an iOS Simulator with the native Network.framework direct-path implementation integrated; lifecycle behavior remains foreground-safe.
4. The Remote MCP gateway exchanges account-scoped peer maps and never exposes candidates across account boundaries.
5. Actual MCP `call`, `result`, and `error` envelopes can traverse the encrypted direct data plane; relay remains a transparent fallback.
6. Side-effecting calls use a stable invocation id/idempotency boundary so a direct-path timeout followed by relay fallback cannot execute the same request twice.
7. A latest-branch GitHub Actions interactive runner signs into the Fabushi test account, appears in `fabushi_test.list_devices`, publishes `fabushi.app.status` as available, and successfully serves harmless App MCP and generic Computer MCP calls.
8. The same runner demonstrates direct-route success when available and forced direct failure followed by successful relay fallback.
9. All required branch checks pass, the implementation is merged to `main`, and the same remote test-account smoke is repeated from `main`.
