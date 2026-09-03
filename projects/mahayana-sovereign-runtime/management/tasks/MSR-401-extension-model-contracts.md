# MSR-401 — Extension, MCP and model contracts

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-401
- **Status:** in-progress
- **Started:** 2026-08-22T16:56:00+08:00
- **Updated:** 2026-08-22T16:56:00+08:00
- **Completed:** null

## Objective
Normalize MCP, skills, plugins, connectors, MiniApps and model capability negotiation behind Mahayana-owned observable contracts.

## Source requirements
MSR-R01, MSR-R02, MSR-R08; Codex MCP runtime status/providers; Fabushi extension/tool-plane requirements.

## In scope
Observable MCP runtime state; provider-neutral extension descriptor; model feature negotiation; integration tests.

## Out of scope
Rewriting every individual third-party connector.

## Dependencies
MSR-202.

## Acceptance criteria
1. MCP connections expose observable lifecycle/status without reconnect side effects.
2. Extensions use a Mahayana-owned descriptor/capability contract.
3. Model runtimes declare supported features and requests negotiate before execution.
4. MiniApp/plugin/connector adapters can map into the same capability plane.
5. CI proves contract behavior and source isolation.
6. Protected merge and canonical-main verification complete.

## Verification
MCP/model/host integration tests in Mahayana Fast Checks and source-boundary audit.

## Branch / commit / PR
Branch: `feat/msr-native-runtime-parity`
Commit: pending
PR: pending

## Implementation summary
Pending implementation.

## Evidence
Pending CI/merge evidence.

## Blockers / risks
Status inspection must be passive and must not create or reconnect transports.

## Next action
Add MCP runtime status snapshots and model/extension capability negotiation.
