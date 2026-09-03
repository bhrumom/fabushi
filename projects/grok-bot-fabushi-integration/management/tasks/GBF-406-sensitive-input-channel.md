# GBF-406 — 敏感输入一次性安全通道

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-406
- Objective: 敏感输入一次性安全通道。
- Source requirement IDs: GBR-005, GBR-007.
- Stage: M4
- Status: TESTED (cross-platform CI/merge pending)
- Dependencies: GBF-401.
- Implementation branch: `gbf/m4-computer-control-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:22+08
- Updated: 2026-08-22 17:38+08
- Completed: —

## Acceptance criteria

- [ ] challenge 有随机 nonce/target/generation/expiry；approve/deny/expire/replay 全 fail-safe；敏感值不落普通日志。
- [ ] 所有拒绝路径无副作用且可审计。
- [ ] GitHub Actions 目标平台检查通过。
- [ ] protected merge + post-merge main verification。

## Verification

security unit/E2E.

## Evidence

`evidence/GBF-406/`.

## Next action

实现/审计并补跨平台与安全测试。
