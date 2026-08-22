# FCM-004 — Release gate alignment

- Project ID: FAB-P0003
- Project Key: FCM
- Status: planned
- Created: 2026-08-22

## Objective

Align manual store delivery workflows with canonical release validation evidence.

## Acceptance criteria

1. Store delivery workflows verify source commit identity.
2. Release workflows require documented platform quality gates before upload.
3. GitHub Release evidence links exact delivered artifacts.
4. Delivery remains manually dispatched and does not weaken protected main.

## Current evidence

Native Electron release already verifies tagged source and canonical platform gates before packaging. Apple and Google delivery workflows remain under alignment review.

## Next action

Audit each delivery workflow and add missing release gate checks in a dedicated PR.
