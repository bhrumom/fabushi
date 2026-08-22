# GBF-302 — 统一 Agent loop 到 Mahayana sovereign runtime

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-302
- Objective: 统一 Agent loop 到 Mahayana sovereign runtime。
- Source requirement IDs: GBR-002, GBR-003.
- Stage: M3
- Status: TESTED (GitHub CI/merge pending)
- Dependencies: GBF-301.
- Implementation branch: `gbf/m3-runtime-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:13+08
- Updated: 2026-08-22 17:17+08
- Completed: —

## Acceptance criteria

- [x] 桌面正式 Agent 命令只能通过 FeatureCommand/FeatureHost/MahayanaRuntime；无 Grok 并行 agent runtime。
- [x] 不恢复 Grok vendor runtime 或平行正式执行图。
- [ ] GitHub Actions/required checks 通过。
- [ ] merge queue 合入 main 并 post-merge verify。

## Verification

call-path guard + feature-host/runtime CI.

## Evidence

`evidence/GBF-302/`.

## Next action

审计当前 call path，移除旁路并用 CI guard 固化。
