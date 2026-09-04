# MSR P0 acceptance / risk / dependency / changelog — FAB-ARCH-P0-20260904

## Gates
- MSR-107: architecture/provenance audit only; implementation-time exact-file provenance remains mandatory in every later adaptation task.
- MSR-210: hard-blocked until MSR-201 reaches independent `REVIEW-PASS/accepted contract`; then must satisfy its own review/merge/CI/exact-main packaged evidence.
- MSR-211: hard-blocked until MSR-202, MSR-210, GBF-409 and GBF-411 reach independent accepted contracts; then must satisfy its own delivery gates.

## Risks
- `MSR-P0-R1` CRITICAL: duplicate runtime/session ownership -> divergent memory/tools/recovery. Owner MSR-210.
- `MSR-P0-R2` HIGH: device/MiniApp provider bypasses approval/audit. Owner MSR-211.
- `MSR-P0-R3` HIGH: stale/replayed invocation repeats mutation. Owner MSR-211.
- `MSR-P0-R4` LEGAL: architecture-level upstream pin mistaken for file-level permission/provenance. Owner MSR-107 + implementing task.

## Change log 2026-09-04 repair
Preserved PR #2320 `REVIEW-REJECTED` history, normalized MSR-107/210/211, exposed live MSR-201/202 and GBF-409/411 blockers, added implementation-time exact-file provenance/NOTICE gate and full canonical-main packaged evidence identity. No CI/merge/release status was promoted.
