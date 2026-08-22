# GBF-403 — Windows computer-control adapter

- Project: `FAB-P0004`
- Stage: `M4-computer-control`
- Status: `IN_PROGRESS`
- Dependency: `GBF-401`

## Objective

Implement a native Windows observe/input adapter using the same `ComputerAction` contract and capability policy as macOS, without a second control runtime.

## Acceptance

- Capture and pointer/keyboard actions are implemented on Windows.
- Native errors and unsupported states fail closed.
- Capability target/scope/expiry/revoke checks precede native calls.
- Windows compile/contract/E2E coverage is green.

## Evidence

Target: `evidence/GBF-403/` plus CI links and merged commit.
