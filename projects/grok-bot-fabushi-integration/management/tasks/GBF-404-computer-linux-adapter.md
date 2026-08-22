# GBF-404 — 实现/验证 Linux X11/Wayland adapter 与降级

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-404
- Objective: 实现/验证 Linux X11/Wayland adapter 与降级。
- Source requirement IDs: GBR-005.
- Stage: M4
- Status: IN_PROGRESS
- Dependencies: GBF-401.
- Implementation branch: `gbf/m4-computer-control-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:22+08
- Updated: 2026-08-22 17:22+08
- Completed: —

## Acceptance criteria

- [ ] Linux X11 capture/input；Wayland 能力检测与受限/portal 路径清晰；无 silent fallback。
- [ ] 所有拒绝路径无副作用且可审计。
- [ ] GitHub Actions 目标平台检查通过。
- [ ] protected merge + post-merge main verification。

## Verification

Ubuntu Actions compile/tests + X11 smoke + Wayland capability test.

## Evidence

`evidence/GBF-404/`.

## Next action

实现/审计并补跨平台与安全测试。
