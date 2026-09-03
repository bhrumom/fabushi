# GBF-402 — 验证并固化 macOS computer adapter

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-402
- Objective: 验证并固化 macOS computer adapter。
- Source requirement IDs: GBR-005.
- Stage: M4
- Status: IMPLEMENTED (target-platform CI pending)
- Dependencies: GBF-401.
- Implementation branch: `gbf/m4-computer-control-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:22+08
- Updated: 2026-08-22 17:38+08
- Completed: —

## Acceptance criteria

- [ ] macOS capture/input/permissions 可观测；用户可抢占 AI batch；无旁路。
- [ ] 所有拒绝路径无副作用且可审计。
- [ ] GitHub Actions 目标平台检查通过。
- [ ] protected merge + post-merge main verification。

## Verification

macOS compile/unit + Electron platform E2E.

## Evidence

`evidence/GBF-402/`.

## Next action

实现/审计并补跨平台与安全测试。
