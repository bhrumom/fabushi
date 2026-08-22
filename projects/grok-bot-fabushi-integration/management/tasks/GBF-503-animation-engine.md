# GBF-503 — 实现共享时钟/弹簧/组合动画引擎

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-503
- Stage: M5
- Objective: 实现共享时钟/弹簧/组合动画引擎。
- Requirement: GBR-006.
- Dependencies: GBF-502.
- Status: TESTED (frontend CI/merge pending)
- Branch: `gbf/m5-avatar-engine-20260822`
- PR: pending
- Started/Updated: 2026-08-22 17:58+08

## Acceptance
- [x] 单一 shared RAF clock；spring physics；确定性 per-bot rhythm；可组合 accent/pose/eyes。
- [x] Fabushi 自研源码，不恢复 Grok vendor 视觉资产/runtime。
- [ ] GitHub frontend/CI checks 通过。
- [ ] protected merge + post-main verification。

## Verification
source guard + frontend CI.

## Evidence
`evidence/GBF-503/README.md`.
