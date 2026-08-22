# GBF-405 — 浏览器标签页级 target-bound 控制

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-405
- Objective: 浏览器标签页级 target-bound 控制。
- Source requirement IDs: GBR-005.
- Stage: M4
- Status: TESTED (cross-platform CI/merge pending)
- Dependencies: GBF-401.
- Implementation branch: `gbf/m4-computer-control-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:22+08
- Updated: 2026-08-22 17:38+08
- Completed: —

## Acceptance criteria

- [ ] browser control 必须绑定 browser/session/target/tab generation；错误 target 或 stale generation 被拒绝；不影响其它 tab。
- [ ] 所有拒绝路径无副作用且可审计。
- [ ] GitHub Actions 目标平台检查通过。
- [ ] protected merge + post-merge main verification。

## Verification

browser target contract + isolation E2E.

## Evidence

`evidence/GBF-405/`.

## Next action

实现/审计并补跨平台与安全测试。
