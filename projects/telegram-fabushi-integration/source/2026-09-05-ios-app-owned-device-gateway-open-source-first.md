# 2026-09-05 — iOS App-owned device gateway open-source-first review

- Project: `FAB-P0001 / TFI`
- Work item: `TFI-M11-IOS-INTERACTIVE-001`
- Canonical baseline re-read before implementation: `main@1bdde6f7a04bdf39b60d4413599a1337137e3029`
- Problem boundary: GitHub Actions must boot an iOS Simulator, install/login the Fabushi Test iOS app, then the **installed app itself** must register its existing semantic App Surface to the account-scoped Fabushi device gateway so `@fabushi test` can discover and control it. A pre-online Runner/device-agent is explicitly not the product model.

## Existing first-party contracts to reuse

1. `mobile/ios/Fabushi/FabushiAppAgentSurface.swift` already owns the stable six-tool semantic contract: `fabushi.app.status`, `snapshot`, `find`, `action`, `wait`, `assert`.
2. `third_party/mahayana/mahayana-rs/mahayana-product` already exposes `feature.auth.deviceAgentSession`, which returns the current account's short-lived access credential/device identity to the trusted installed application while retaining refresh credentials in Rust-owned storage.
3. `chatgpt-vps-control/lib/device-gateway.js` already defines the account-scoped WebSocket protocol: bearer-authenticated `/agent`, then `register` / `registered`, heartbeat, `call`, and `result`.
4. The gateway's `device_call` result contract consumes `response.result.structuredContent` when available and never requires a second UI automation protocol.
5. Native iOS already uses XCUITest/XCTest and stable accessibility identifiers for simulator verification and `.xcresult` evidence.

## Upstream alternatives reviewed

| Upstream | License verified | Potential reuse | Decision |
| --- | --- | --- | --- |
| `mobile-dev-inc/Maestro` | Apache-2.0 | Mobile UI flow driver | **Do not add.** It would create a second UI-driving source of truth beside the existing App Surface/XCUITest and does not solve account-owned device registration. |
| `appium/appium` | Apache-2.0 | Cross-platform WebDriver automation | **Do not add.** Same duplication problem, plus an extra server/driver lifecycle in CI. |
| `daltoniam/Starscream` | Apache-2.0 | Swift WebSocket client | **Do not add.** The required transport is one bounded authenticated WebSocket; Foundation `URLSessionWebSocketTask` already provides it on the deployment target. |
| `apple/swift-nio` | Apache-2.0 | General networking/WebSocket foundation | **Do not add.** It is substantially broader than this client need and would enlarge dependency/build surface without replacing an existing Fabushi contract. |

License evidence was read from each upstream repository's canonical LICENSE file on 2026-09-05. No upstream source code is copied into Fabushi by this task.

## Reuse decision

Implement the missing iOS transport as a narrow first-party adapter using Foundation `URLSessionWebSocketTask` only. It must:

- start only after the app has a logged-in account session;
- obtain the short-lived current account credential through `feature.auth.deviceAgentSession`;
- authenticate to `wss://fabushi-mcp.ombhrum.com/agent` with that access token;
- register only the existing six `fabushi.app.*` tools and dispatch calls to the existing `FabushiAppAgentSurface`;
- send heartbeat/reconnect without retaining a refresh token outside Rust-owned account state;
- stop/cancel on logout;
- retain a redacted, argument-free device-call trace for CI evidence;
- never expose arbitrary Swift invocation, shell, JavaScript, password input, or Runner credentials.

## CI decision

Do **not** restore the temporarily paused `.github/workflows/native-mobile.yml` and do not turn it into a Runner device-agent gate. Add a dedicated, narrow iOS Simulator interactive evidence workflow instead. It may reuse the existing protected CI test-account login/export mechanism to create a bounded refresh-token-free app session, but the Simulator app—not a sidecar process—must own gateway registration.

The workflow must retain evidence with `if: always()`: full-session simulator video, step screenshots/attachments where produced, app/device trace, `.xcresult`, simulator/app logs, and a machine-readable + human-readable report. A failed journey must preserve the same evidence classes.
