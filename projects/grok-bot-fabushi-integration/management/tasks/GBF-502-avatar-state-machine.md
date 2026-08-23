# GBF-502 — 建立 Fabushi 动态头像语义状态机

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-502
- Stage: M5
- Objective: 建立 Fabushi 动态头像语义状态机。
- Requirement: GBR-006.
- Dependencies: GBF-501.
- Status: TESTED (frontend CI/merge pending)
- Branch: `gbf/m5-avatar-engine-20260822`
- PR: pending
- Started/Updated: 2026-08-22 17:58+08

## Acceptance
- [x] idle/listening/thinking/tool-running/speaking/result/error 有显式状态映射。
- [x] Fabushi 自研源码，不恢复 Grok vendor 视觉资产/runtime。
- [ ] GitHub frontend/CI checks 通过。
- [ ] protected merge + post-main verification。

## Verification
state contract guard.

## Evidence
`evidence/GBF-502/README.md`.
