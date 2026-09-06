# TFI-MACOS-INTERACTIVE-001 — stable settings logout semantic target

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Discovery baseline: protected `main@5147ed58d3f79e5d54f35bad5d85a66003b17ee2`
- Preceding repair: PR `#2390` exposed stable profile navigation test IDs.
- Candidate release already building at discovery: `v1.2.34` from `5147ed58d3f79e5d54f35bad5d85a66003b17ee2`.

## Independent defect

The desktop App MCP uses the shared DOM semantic surface, where `data-testid="x"` becomes stable `agentId="test:x"` unless a production `data-agent-id` is present. The account logout control currently declares only `data-testid="settings-logout"`, while the macOS interactive truth gate requires a completed `fabushi.app.action` with exact `agentId="settings-logout"` and `action="invoke"`. Therefore the old source cannot satisfy its own final gate even after profile/settings navigation becomes safely reachable.

## Atomic repair

Add `data-agent-id="settings-logout"` to the existing logout button without changing logout behavior, permissions, account/session semantics, generation checks, stable-target rebase rules, or the truth gate. Extend the existing App Agent Surface E2E to navigate through the new stable profile settings target and prove `find({agentId: "settings-logout"})` returns exactly one stable, visible, enabled control.

`v1.2.34` is excluded from interactive acceptance if it publishes because this source-contract defect was established before live control. After protected merge, publish a strictly newer immutable macOS test version and run the complete App-owned journey with all six `fabushi.app.*` tools plus `ci_session_status/note/finish` and full always-upload evidence.