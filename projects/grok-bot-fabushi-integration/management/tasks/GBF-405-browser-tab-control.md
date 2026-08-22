# GBF-405 — Browser tab-level control

- Project: `FAB-P0004`
- Stage: `M4-computer-control`
- Status: `IN_PROGRESS`
- Dependency: `GBF-401`

## Objective

Define and enforce a browser target identity so AI/browser automation acts only on the selected tab/session and does not disturb unrelated tabs or windows.

## Acceptance

- Browser target identity includes browser session/window/tab identity.
- Target mismatch is denied before input/navigation side effects.
- Control routing is compatible with the unified capability schema.
- Isolation E2E demonstrates an unrelated tab remains unchanged.

## Evidence

Target: `evidence/GBF-405/` plus CI links and merged commit.
