# GBF-505 — 移除生产 Grok 视觉/runtime 依赖

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-505
- Stage: M5
- Objective: 移除生产 Grok 视觉/runtime 依赖。
- Requirement: GBR-006, GBR-008.
- Dependencies: GBF-501..504.
- Status: TESTED (frontend CI/merge pending)
- Branch: `gbf/m5-avatar-engine-20260822`
- PR: pending
- Started/Updated: 2026-08-22 17:58+08

## Acceptance
- [x] frontend/desktop 无 Grok mark/avatar engine/vendor path；CI 防回流。
- [x] Fabushi 自研源码，不恢复 Grok vendor 视觉资产/runtime。
- [ ] GitHub frontend/CI checks 通过。
- [ ] protected merge + post-main verification。

## Verification
dependency/source audit.

## Evidence
`evidence/GBF-505/README.md`.
