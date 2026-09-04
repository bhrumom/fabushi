# MSR Bot Runtime Contract — FAB-ARCH-P0-20260904

- Project ID: `FAB-P0005`
- Status: architecture baseline; implementation unverified

## Requirements and architecture

1. Mahayana CLI/Runtime is the only core for every Bot; no TFI/GBF/MiniApp-specific hidden runtime.
2. Canonical Bot identity -> exactly one durable Mahayana session. Reopen/restart/install/update reuses it. Group/conversation/topic are scoped context keys inside the session.
3. Session state, interruption/recovery, compaction, tool calls and approvals remain provider-neutral MSR contracts.
4. Device, WebMCP/App MCP, MiniApp MCP/CLI and native Computer Use are capability providers discovered through one MSR catalog and invoked through one policy/approval/audit bus.
5. Tool progress/result/error exposed to messaging are typed, correlated and redacted; raw secrets/provider implementation logs never become chat content.
6. Capability absence/stale device/stale MiniApp generation/revoked authorization fails closed.

## Cross-project links

- TFI: `projects/telegram-fabushi-integration/decisions/ADR-0014-mahayana-bot-miniapp-cross-project-contract.md`
- GBF: `projects/grok-bot-fabushi-integration/docs/2026-09-04-bot-behavior-device-contract.md`

## Verification

Focused session mapping/recovery tests, capability policy/approval contracts, MiniApp/device discovery negatives, then GitHub Actions and packaged cross-project E2E. No local build/test.