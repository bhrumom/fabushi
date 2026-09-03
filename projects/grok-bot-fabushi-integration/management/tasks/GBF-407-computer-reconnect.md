# GBF-407 — computer-control crash/reconnect 幂等恢复

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-407
- Objective: computer-control crash/reconnect 幂等恢复。
- Source requirement IDs: GBR-005, GBR-007.
- Stage: M4
- Status: TESTED (cross-platform CI/merge pending)
- Dependencies: GBF-402..406.
- Implementation branch: `gbf/m4-computer-control-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:22+08
- Updated: 2026-08-22 17:38+08
- Completed: —

## Acceptance criteria

- [ ] session generation 变化后旧请求/nonce/target 全失效；重连不重复副作用。
- [ ] 所有拒绝路径无副作用且可审计。
- [ ] GitHub Actions 目标平台检查通过。
- [ ] protected merge + post-merge main verification。

## Verification

fault/idempotency tests + cross-platform CI.

## Evidence

`evidence/GBF-407/`.

## Next action

实现/审计并补跨平台与安全测试。
