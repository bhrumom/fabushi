# GBF-401 — 定义 versioned / target-bound computer-control capability schema

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-401
- Objective: 定义 versioned / target-bound computer-control capability schema。
- Source requirement IDs: GBR-005, GBR-007.
- Stage: M4
- Status: IN_PROGRESS
- Dependencies: GBF-204, GBF-305.
- Implementation branch: `gbf/m4-computer-control-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:22+08
- Updated: 2026-08-22 17:22+08
- Completed: —

## Acceptance criteria

- [ ] 每次控制请求绑定 device/window/browser target + generation；target mismatch fail closed；序列化兼容测试。
- [ ] 所有拒绝路径无副作用且可审计。
- [ ] GitHub Actions 目标平台检查通过。
- [ ] protected merge + post-merge main verification。

## Verification

protocol unit tests + security review.

## Evidence

`evidence/GBF-401/`.

## Next action

实现/审计并补跨平台与安全测试。
