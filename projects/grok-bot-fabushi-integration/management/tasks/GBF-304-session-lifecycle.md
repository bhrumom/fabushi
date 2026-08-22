# GBF-304 — 统一 session/checkpoint/resume/cancel 语义

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-304
- Objective: 统一 session/checkpoint/resume/cancel 语义。
- Source requirement IDs: GBR-003, GBR-007.
- Stage: M3
- Status: TESTED (GitHub CI/merge pending)
- Dependencies: GBF-302.
- Implementation branch: `gbf/m3-runtime-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:13+08
- Updated: 2026-08-22 17:17+08
- Completed: —

## Acceptance criteria

- [x] kernel resilience 为 canonical session lifecycle；非法转换 fail closed；FeatureHost interrupt 只处理中登记 operation。
- [x] 不恢复 Grok vendor runtime 或平行正式执行图。
- [ ] GitHub Actions/required checks 通过。
- [ ] merge queue 合入 main 并 post-merge verify。

## Verification

mahayana-kernel resilience tests + FeatureHost interrupt tests.

## Evidence

`evidence/GBF-304/`.

## Next action

审计当前 call path，移除旁路并用 CI guard 固化。
