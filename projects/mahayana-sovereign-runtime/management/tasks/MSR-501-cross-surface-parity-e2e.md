# MSR-501 — Cross-surface parity and E2E

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-501
- **Status:** in-progress
- **Started:** 2026-08-22T16:57:00+08:00
- **Updated:** 2026-08-22T16:57:00+08:00
- **Completed:** null

## Objective
Prove the same Mahayana-owned session, policy, tool and extension contracts are consumable from required Electron, iOS, Android, Web and CLI/Headless surfaces without vendor-specific public types.

## Source requirements
MSR-R04, MSR-R07, MSR-R08.

## In scope
Contract journeys; FFI/Host compatibility; CI matrix; desktop/mobile/web/headless smoke and E2E evidence where applicable.

## Out of scope
Store release publication unrelated to runtime parity.

## Dependencies
MSR-401 and upstream runtime parity tasks.

## Acceptance criteria
1. Required surfaces compile against the same Mahayana public contracts.
2. Session open/run/approval/interrupt-or-suspend/status journey is represented on each applicable surface.
3. Electron and native mobile quality gates pass.
4. Web/CLI/headless contract smoke passes.
5. No surface imports vendor public product types for the tested journey.
6. Protected merge and canonical-main verification complete.

## Verification
GitHub Actions Electron desktop, Native mobile, CI, Mahayana Fast Checks and relevant Host/FFI contract tests.

## Branch / commit / PR
Branch: `feat/msr-native-runtime-parity`
Commit: pending
PR: pending

## Implementation summary
Pending implementation.

## Evidence
Pending CI/merge evidence.

## Blockers / risks
Platform-specific UI coverage may be split from contract-level parity, but the shared runtime journey must remain identical.

## Next action
Add one shared conformance journey and execute it through each available surface adapter in CI.
