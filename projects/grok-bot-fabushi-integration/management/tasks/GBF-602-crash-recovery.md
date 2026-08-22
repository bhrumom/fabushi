# GBF-602 — 验证 crash/restart 恢复无重复副作用

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-602
- Stage: M6
- Objective: 验证 crash/restart 恢复无重复副作用。
- Requirements: GBR-003, GBR-007.
- Dependencies: GBF-304, GBF-601.
- Status: TESTED (CI/merge pending)
- Branch: `gbf/m6-reliability-observability-20260822`
- Started/Updated: 2026-08-22 18:06+08

## Acceptance
- [x] Host generation isolation + kernel lifecycle + computer generation 共同阻止 stale side effects。
- [x] secret/privacy boundary preserved.
- [ ] GitHub CI/benchmark pass.
- [ ] protected merge + post-main verify.

## Verification
fault/recovery tests.

## Evidence
`evidence/GBF-602/`.
