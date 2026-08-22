# GBF-403 — 实现/验证 Windows computer adapter

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-403
- Objective: 实现/验证 Windows computer adapter。
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

- [ ] Windows capture + pointer/keyboard/scroll adapter 可编译；状态报告能力，不伪造权限。
- [ ] 所有拒绝路径无副作用且可审计。
- [ ] GitHub Actions 目标平台检查通过。
- [ ] protected merge + post-merge main verification。

## Verification

Windows Actions compile/tests + smoke contract.

## Evidence

`evidence/GBF-403/`.

## Next action

实现/审计并补跨平台与安全测试。
