# GBF-301 — 盘点 coordinator/supervisor/host 行为并识别重复正式执行链

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-301
- Objective: 盘点 coordinator/supervisor/host 行为并识别重复正式执行链。
- Source requirement IDs: GBR-002, GBR-003.
- Stage: M3
- Status: TESTED (GitHub CI/merge pending)
- Dependencies: GBF-103, GBF-104.
- Implementation branch: `gbf/m3-runtime-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:13+08
- Updated: 2026-08-22 17:17+08
- Completed: —

## Acceptance criteria

- [x] renderer coordinator 仅编排 typed transport；AppHost feature.execute 唯一进入 FeatureHost；重复/旁路入口有明确决策。
- [x] 不恢复 Grok vendor runtime 或平行正式执行图。
- [ ] GitHub Actions/required checks 通过。
- [ ] merge queue 合入 main 并 post-merge verify。

## Verification

architecture call-path audit + convergence guard.

## Evidence

`evidence/GBF-301/`.

## Next action

审计当前 call path，移除旁路并用 CI guard 固化。
