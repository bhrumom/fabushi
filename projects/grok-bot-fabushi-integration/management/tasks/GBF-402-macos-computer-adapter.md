# GBF-402 — macOS computer-control adapter

- Project: `FAB-P0004`
- Stage: `M4-computer-control`
- Status: `IN_PROGRESS`
- Dependency: `GBF-401`

## Objective

Validate and harden the existing CoreGraphics-based macOS capture/input adapter behind the unified capability gate, including permission denial and target constraints.

## Acceptance

- Screenshot, pointer, keyboard and wait actions use the shared action contract.
- Accessibility/screen-recording denial fails closed with no input side effect.
- Capability target/scope/expiry/revoke checks occur before native calls.
- macOS automated contract/E2E coverage is green.

## Evidence

Target: `evidence/GBF-402/` plus CI links and merged commit.
