# GBF-504 — 动画性能与无障碍闭环

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-504
- Stage: M5
- Objective: 动画性能与无障碍闭环。
- Requirement: GBR-006, GBR-007.
- Dependencies: GBF-503.
- Status: TESTED (frontend CI/merge pending)
- Branch: `gbf/m5-avatar-engine-20260822`
- PR: pending
- Started/Updated: 2026-08-22 17:58+08

## Acceptance
- [x] reduced-motion；IntersectionObserver offscreen pause；侧栏无 N pointer listeners；无 setInterval legacy loop。
- [x] Fabushi 自研源码，不恢复 Grok vendor 视觉资产/runtime。
- [ ] GitHub frontend/CI checks 通过。
- [ ] protected merge + post-main verification。

## Verification
performance/accessibility static gate + frontend build.

## Evidence
`evidence/GBF-504/README.md`.
