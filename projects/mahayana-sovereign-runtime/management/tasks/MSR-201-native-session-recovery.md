# MSR-201 — Native session and recovery ownership

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-201
- **Status:** in-progress
- **Started:** 2026-08-22T16:55:00+08:00
- **Updated:** 2026-08-22T16:55:00+08:00
- **Completed:** null

## Objective
Own session lifecycle, snapshots, unfinished-operation suspension and reclaim in Mahayana contracts rather than vendor app-server semantics.

## Source requirements
MSR-R01, MSR-R02, MSR-R04; Codex unfinished-turn/session semantics in `docs/08-upstream-capability-matrix.md`.

## In scope
Provider-neutral session snapshot/restore; explicit operation suspension; pending-prompt requeue/reclaim; conformance tests.

## Out of scope
Removing the optional Codex compatibility adapter before MSR-601.

## Dependencies
MSR-102.

## Acceptance criteria
1. Kernel exposes provider-neutral snapshot/restore and suspend/reclaim contracts.
2. Native engine serializes/restores session state without vendor types.
3. Suspended unfinished operations requeue work instead of being marked cancelled.
4. Resume executes the reclaimed pending prompt without duplicating user input.
5. CI proves snapshot/restore and suspension/reclaim semantics.
6. Protected merge and canonical-main verification complete.

## Verification
Kernel/native-engine unit and conformance tests in Mahayana Fast Checks; post-merge source audit.

## Branch / commit / PR
Branch: `feat/msr-native-runtime-parity`
Commit: pending
PR: pending

## Implementation summary
Pending implementation.

## Evidence
Pending CI/merge evidence.

## Blockers / risks
Suspension is cooperative around model/tool boundaries; blocking third-party calls cannot be preempted safely without runtime-specific cancellation.

## Next action
Add contracts and wire NativeEngine state/requeue semantics.
