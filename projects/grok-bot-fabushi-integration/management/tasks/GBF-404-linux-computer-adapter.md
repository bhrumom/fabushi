# GBF-404 — Linux computer-control adapter

- Project: `FAB-P0004`
- Stage: `M4-computer-control`
- Status: `IN_PROGRESS`
- Dependency: `GBF-401`

## Objective

Implement Linux computer control with explicit X11 support and a fail-closed Wayland/portal degradation contract, sharing the same action and capability model as other desktop platforms.

## Acceptance

- X11 capture and input are implemented or explicitly capability-gated unavailable when the required display extension is absent.
- Wayland is detected and never silently falls back to unsafe global input.
- Capability target/scope/expiry/revoke checks precede native calls.
- Linux compile/contract/E2E coverage is green with deterministic unavailable-path tests.

## Evidence

Target: `evidence/GBF-404/` plus CI links and merged commit.
