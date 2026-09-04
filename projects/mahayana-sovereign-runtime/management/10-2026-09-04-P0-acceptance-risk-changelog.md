# MSR P0 acceptance / risk / dependency / changelog — FAB-ARCH-P0-20260904

## Gates
- MSR-107: current upstream audit accepted with Apache-2.0 NOTICE/provenance obligations.
- MSR-210: session binding review-passed before TFI MiniApp->Bot and group Bot closure.
- MSR-211: capability policy plane review-passed before Bot can use device/MiniApp tools.

## Risks
- `MSR-P0-R1` CRITICAL: multiple runtime/session owners cause divergent memory/tools/recovery. Mitigation: MSR-210 invariant + source guard.
- `MSR-P0-R2` HIGH: device/MiniApp tool bypasses policy. Mitigation: MSR-211 single bus + deny/stale tests.
- `MSR-P0-R3` MEDIUM: upstream copy drifts provenance. Mitigation: MSR-107 exact SHA/license/NOTICE ledger.

## Change log 2026-09-04
Recorded MSR as the sole Bot runtime/session owner for `FAB-ARCH-P0-20260904`; pinned current upstream audit revisions; added atomic session/capability tasks. No implementation/test/release claim.