# GBF-603 — 统一 correlation/structured logging

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-603
- Stage: M6
- Objective: 统一 correlation/structured logging。
- Requirements: GBR-007.
- Dependencies: GBF-203, GBF-303.
- Status: TESTED (CI/merge pending)
- Branch: `gbf/m6-reliability-observability-20260822`
- Started/Updated: 2026-08-22 18:06+08

## Acceptance
- [x] 每次 Electron edge invocation 记录 edge/method/correlation/status/duration，绝不记录 args/results/secret。
- [x] secret/privacy boundary preserved.
- [ ] GitHub CI/benchmark pass.
- [ ] protected merge + post-main verify.

## Verification
edge trace contract test.

## Evidence
`evidence/GBF-603/`.
