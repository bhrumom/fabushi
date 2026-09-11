# 2026-09-12 — Action-owned packaged App Agent semantic smoke

Project: `FAB-P0003 / FCM`
Task: `FCM-010.10`
Parent intake: `[Fabushi:dc7a68a4-8194-41dd-bc00-aa6074cf0323]`

## Why this follows the Shopify-style model

Fabushi already has the important architectural pieces: Mahayana business logic can be tested separately from UI, and the installed Electron App exposes a private loopback semantic App Agent surface (`status`, `snapshot`, `find`, `action`, `wait`, `assert`). The macOS release E2E still waits for an external `@fabushi test` controller for up to 1500 seconds after the App is ready.

The next safe step is not to remove the external full journey. It is to make GitHub Actions prove, immediately after App-owned registration, that the installed package can be driven deterministically through the semantic bridge without screenshot coordinates or accessibility-tree guessing. This creates a fast fail path for package/bridge regressions while the broader human/agent-like full journey remains an independent acceptance layer.

## Implementation decision

1. Add `runAppAgentCiSmoke` over the existing `createAppAgentSurfaceClient`; do not add a second protocol or server.
2. Wait for the private App Agent surface, then execute `status -> snapshot -> wait -> find -> action -> assert -> find -> action -> wait -> status` against stable agent IDs.
3. Reject snapshots that expose values for elements marked sensitive.
4. Do not accept x/y coordinates in the smoke path; the action is stable-agent-id + generation based.
5. Persist a small redacted JSON report in the existing macOS evidence directory.
6. Run the smoke after exact installed App registration and before the external 1500-second full journey. A smoke failure prevents entering the expensive external wait.
7. Keep the existing full external journey, video, screenshots, device-call trace, Playwright evidence, account/session boundaries and exact-main release identity requirements unchanged.
8. Lock the runner behavior and workflow ordering in the lightweight required `CI result` so future refactors cannot silently remove the self-driving path.

## Security boundaries

- The runner reads only the existing private discovery file through `app-agent-surface-client.js`; it never prints or persists the bearer token.
- Loopback-origin, discovery permissions and token-shape validation remain owned by the existing client.
- The report records only route/screen/generation/operation names and stable semantic ids.
- The protected account flow remains unchanged and the App projection remains refresh-token-free.

## Acceptance boundary

This change proves that GitHub Actions owns a deterministic semantic smoke of the real installed package. It does **not** yet claim that the external full journey can be deleted or reduced from 1500 seconds. That larger latency reduction requires a canonical release run showing an Action-owned full journey with evidence equivalence across the existing category list.
