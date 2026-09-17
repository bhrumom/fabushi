# ADR-0002: Independent Chrome account and browser agent

Status: proposed for CWA-007. Date: 2026-09-12.

Reuse existing Fabushi browser/start + secret-bound attempt polling, user-info verification and account-scoped device registry. Chrome owns a short-lived access session in trusted-context storage.session only; discard refresh credentials. No token in URL, page DOM, content-script messages or logs. Browser restart requires login. Preserve desktop Host ownership of desktop credentials.

Native browser WebSocket cannot set Authorization. Add a distinct browser-agent route that requires the configured published Chrome origin, a bounded first authentication frame, authentication timeout and existing account verification before registration. Keep /agent header authentication unchanged. Browser registration uses a ten-minute maximum lease and reconnect re-verification. Reject frame processing while authentication is pending. Profile device IDs are stable random IDs; account identity always comes from the server.

Reuse the exact browser-control command dispatcher, with explicit exclusive remote transport and session-generation invalidation on disconnect/logout. Queue bounded CDP/tab events with an explicit overflow signal, expose polling via MCP. Do not fork the browser engine. Both local and remote modes retain all nine commands. Remote switching must finish outstanding operations before claims can be reused; revoke all claims without closing user tabs.

## Upstream survey / provenance

- microsoft/playwright, Apache-2.0, upstream pushed 2026-09-11 (GitHub API read 2026-09-12). Reviewed packages/extension README: per-client tab groups, exclusive tab ownership, per-profile token and explicit disconnect. It offers an existing-browser MCP solution but its local token/Node transport is not Fabushi account discovery. Learn ownership/disconnect patterns; reuse existing Fabushi dispatcher instead of adding a second engine/dependency.
- GoogleChrome/chrome-extensions-samples, Apache-2.0. Reviewed functional-samples/tutorial.websockets/service-worker.js and manifest: MV3 worker keepalive requires activity below 30 seconds. Adapt heartbeat lifecycle, not the example's external demo service or unauthenticated protocol.
- Official Chrome storage reference: session storage is memory-backed and trusted-context access can be constrained. Official WebSockets guide documents worker activity. Use trusted session storage and 20-second heartbeat; service restart/expired session must fail closed.
- Existing Fabushi gateway tests cover account filtering/socket-generation/result routing. Extend these with browser origin, first-frame auth, timeout and logout/reconnect regression. CI packaged journey must verify real extension UI and command round trip.

References: https://github.com/microsoft/playwright/tree/main/packages/extension ; https://github.com/GoogleChrome/chrome-extensions-samples/tree/main/functional-samples/tutorial.websockets ; https://developer.chrome.com/docs/extensions/reference/api/storage ; https://developer.chrome.com/docs/extensions/how-to/web-platform/websockets

No third-party implementation copied; no new runtime dependency. Stable production extension ID and deployed gateway support are required before users can connect.
