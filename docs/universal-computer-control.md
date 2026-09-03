# Universal computer control

This document describes the Fabushi implementation that turns an installed desktop app into an account-bound computer that can be observed and controlled from another Fabushi client by either a person or a Bot.

## Product contract

Installation, presence, authorization, and control are separate states:

1. The signed desktop application installs the platform Computer Use runtime with the application and starts the Mahayana Host in the user's login session.
2. After account login the desktop registers and heartbeats even while remote control is disabled. Other clients on the same account can therefore show the computer as online without silently gaining control.
3. First control requires the desktop's eight-character pairing code. The resulting client secret is stored only by the paired client and can be revoked from the desktop profile.
4. The desktop must also have **Remote control** enabled before it polls or accepts sessions. Turning the switch off closes active WebRTC peers immediately but keeps presence online.
5. A paired session can carry direct pointer/keyboard commands or a natural-language Bot request. Bot execution still passes through the desktop's normal local-execution policy, model tool review, and operating-system permissions.

This gives the requested UU-remote-style discovery without making account presence equivalent to unattended control.

## Runtime layers

| Layer | Implementation | Responsibility |
| --- | --- | --- |
| Device presence | Mahayana Platform Worker and desktop controller | Account-scoped registration, heartbeat, online state, pairing, revocation, expiring sessions, ICE signaling |
| Human transport | Browser WebRTC data channel | End-to-end screen frames, pointer gestures, keyboard/text actions, disconnect and backpressure |
| Human executor | `mahayana-computer` | Cross-platform screenshots and input, exact session generation checks, human input pre-empts AI input |
| Bot executor | bundled `fabushi-computer` stdio MCP | Complete semantic Computer Use, app/window targeting, browser control, accessibility snapshots, stale-ref rejection, coordinate fallback and post-action state |
| Desktop surface | Electron profile/info sidebar | Always-visible device state, pairing code, control switch, client revocation and active-session status |
| Mobile surface | iOS/Android restricted WebView | Official-origin-only remote UI with retained cookies and WebRTC, no injected native JavaScript bridge |

The MCP runtime is content-addressed and copied into `desktop/resources/computer-control` during CI packaging. Electron reuses its signed executable as a private Node runtime and injects the MCP configuration into every local Bot thread. It never exposes the MCP server on a TCP port.


## Fabushi Agent Surface: Web MCP and App MCP

Fabushi now adds a structured application layer without replacing any remote or
local computer-control path. The main Web application registers the shared
`fabushi.app.status`, `snapshot`, `find`, `action`, `wait`, and `assert` tools
through WebMCP when the browser supports it. Electron exposes the same live
renderer state through a private loopback bridge to the packaged stdio MCP, and
iOS/Android implement the same native semantic contract for platform tests and
future account-bound device transports.

The preferred routing is App MCP for Fabushi, browser DOM/accessibility for Web
content, native AX/UIA/AT-SPI for other applications, and bounded screenshot /
coordinate Computer Use only as the final fallback. The complete existing
`computer_*` registrar, remote device discovery, WebRTC control, CI session
tools, secure input, human-input preemption and OS permission boundaries remain
available. See `docs/fabushi-agent-surface.md` for the full contract.

## Background Computer Use behavior

Fabushi uses application-scoped observation before whole-desktop coordinates:

- `computer_applications` resolves installed/running apps by stable identifier and path.
- `computer_app_state` launches or reads a selected app with `activate: false` by default, returning its accessibility tree and an app/window screenshot even when it is not frontmost.
- `computer_elements` produces an indexed semantic snapshot. Element references live for 90 seconds, are consumed by writes, and are rejected after the UI generation changes.
- `computer_element_action` and `computer_native_secondary_action` use the actions advertised by the fresh accessibility node. Typed values are omitted from audit output.
- `computer_use_bridge` exposes the Computer Use-compatible `list_apps`, `get_app_state`, `click`, `drag`, `press_key`, `type_text`, `scroll`, `set_value`, `select_text`, and secondary-action vocabulary.
- Raw `computer_use` remains available for canvases, games, remote surfaces, and inaccessible controls. It returns a post-action screenshot and supports bounded action batching.
- Browser tools use managed/attached CDP sessions, accessibility/DOM snapshots, locators, coordinate fallback, logs, dialogs, downloads, and PDF utilities.

Platform adapters are AXUIElement + ScreenCaptureKit/CoreGraphics on macOS, UI Automation + User32/GDI on Windows, and AT-SPI + X11 on Linux. Semantic/background actions are preferred. A raw-input fallback may need to activate the target on platforms that do not provide a safe background input primitive. Screen Recording and Accessibility remain explicit OS grants; the app never bypasses the lock screen or secure desktop.

## Grok Bot comparison

The reconstructed Grok Bot uses two related but distinct Linux VPS paths:

- Its human desktop surface is VNC/noVNC connected to a remote Linux graphical session.
- Its model path uses X11 (`xdotool`, `xrandr`/`xdpyinfo`, and `ffmpeg x11grab`) with normalized coordinates, settling, screenshots, and bounded batching.

Fabushi retains the useful model contract—observe, act, settle, return state—but replaces the fixed VPS/X11 assumption with native adapters for the user's own desktop. It also adds account presence, per-client pairing, exact-device routing, semantic accessibility trees, background app capture, short-lived references, and a single arbitration boundary shared by human and AI input.

No recovered Grok source is copied into Fabushi. The implementation is the repository's independent clean-room Computer Use layer described in `chatgpt-vps-control/docs/clean-room-computer-use.md` and `chatgpt-vps-control/docs/grok-computer-use-port.md`.

## Open-source remote-desktop decision

The following mature projects were evaluated against the existing Fabushi account, security, mobile, and licensing boundaries:

| Project | Useful capability | Integration decision |
| --- | --- | --- |
| RustDesk | Cross-platform capture/input, rendezvous and relay, mobile clients | Do not vendor into the proprietary application: the client is AGPL-3.0 and would replace rather than extend the existing identity/session model. Its direct-or-relay topology remains a useful reference. |
| MeshCentral / MeshAgent | Mature unattended agent, web relay, device fleet and remote desktop | Best future optional high-frame-rate provider because it is Apache-2.0, but keep it as an isolated service/adapter so Fabushi authorization remains authoritative. It is not required for the current WebRTC control path. |
| noVNC | Proven mobile-browser VNC client | Keep as a Linux VPS compatibility option. It requires a VNC server and does not provide semantic accessibility or native macOS/Windows background app control. |
| webrtc-rs | Rust WebRTC primitives under MIT/Apache-2.0 | Suitable if signaling/media moves into the Rust Host. The current browser-to-browser WebRTC path avoids an additional native media stack and already fits the mobile WebView clients. |

The shipped implementation therefore fuses the mature architectural pieces, not entire third-party products: authenticated device presence, expiring session signaling, WebRTC direct transport with ICE relay fallback, platform-native capture/input, and semantic AI control. An isolated MeshCentral-compatible provider can be added later for continuous high-frame-rate remote support without changing the Bot tool contract.

## Security invariants

- Same-account discovery reveals label, platform-neutral device id, online state, and last-seen time; it does not grant a control secret.
- Pairing, remote-control enablement, active session, device id, client id, and session generation must all match before an action is executed.
- Disabling control or revoking a client closes its active peer.
- Mobile WebViews allow only the exact official HTTPS origin, reject certificate errors and mixed content, and expose no native bridge.
- The Bot MCP is private stdio, inherits no network listener, and rereads the canonical `feature-host/runtime/settings.json` local-execution/AI-control policy before every tool call; missing or malformed policy fails closed.
- Mutating MCP tools are annotated destructive/non-idempotent as appropriate and remain subject to Codex approval policy and OS privacy controls.
- Semantic references are short-lived and invalidated after mutation. Sensitive typed text is not recorded in audit summaries.
- Human input goes through the same local executor and pre-empts queued AI control.

## CI and release coverage

Heavy verification is intentionally CI-only. Changes to this feature route through the main CI, Computer Control security workflow, Electron desktop matrices, macOS hot package, native Electron release, Apple delivery, and native mobile workflows. Release artifacts stage the Computer Use runtime before Electron packaging, and source-invariant tests prevent a package from omitting the MCP entry point or its required dependencies.

Paired mobile clients receive a separate high-entropy possession token. Only its hash is stored by the Platform Worker, and the token is required to create a control session; account login alone cannot reuse another client ID. The client-token migration revokes legacy pairings and closes their sessions, so users pair once again after deployment.
