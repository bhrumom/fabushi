# MSR-601 — Upstream isolation and final acceptance

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-601
- **Status:** in-progress
- **Started:** 2026-08-22T16:57:00+08:00
- **Updated:** 2026-08-22T16:57:00+08:00
- **Completed:** null

## Objective
Prove Mahayana's default product path is Fabushi-owned and can operate without vendor product crates while preserving optional audited compatibility adapters behind explicit boundaries.

## Source requirements
MSR-R01 through MSR-R08; final Definition of Done.

## In scope
Dependency/source audit; default-feature isolation; adapter-disable build/test gate; provenance/license closure; project acceptance/evidence closure.

## Out of scope
Deleting audited optional compatibility source before all downstream migration consumers are removed.

## Dependencies
MSR-501 and all required prior MSR tasks.

## Acceptance criteria
1. Default Mahayana native product graph contains no Codex/xAI product crates.
2. Vendor adapters can be disabled without changing Mahayana public contracts.
3. Source-boundary and provenance/license gates pass.
4. Required CI/E2E gates pass on exact final head and merge group.
5. Canonical main is re-read after protected merge.
6. WBS, acceptance matrix, status, changelog, evidence and project status are closed with objective links/SHAs.

## Verification
Dependency/source audit script; no-vendor/default-native CI target; all required Actions; post-merge canonical-main verification.

## Branch / commit / PR
Branch: `feat/msr-native-runtime-parity`
Commit: pending
PR: pending

## Implementation summary
Pending implementation.

## Evidence
Pending final CI/merge/main evidence.

## Blockers / risks
Adapter removal must not be claimed until all default/native surfaces prove independence.

## Next action
Complete all predecessor tasks, add no-vendor gate, then close project only from canonical main evidence.
