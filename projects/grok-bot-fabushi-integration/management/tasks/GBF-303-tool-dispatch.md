# GBF-303 — 统一 tool/MCP/extension dispatch

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-303
- Objective: 统一 tool/MCP/extension dispatch。
- Source requirement IDs: GBR-002, GBR-003, GBR-004.
- Stage: M3
- Status: TESTED (GitHub CI/merge pending)
- Dependencies: GBF-302.
- Implementation branch: `gbf/m3-runtime-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:13+08
- Updated: 2026-08-22 17:17+08
- Completed: —

## Acceptance criteria

- [x] renderer 无 runtime.callTool/plugin direct execution旁路；MCP tool call 经 FeatureCommand -> FeatureHost -> Runtime 并写 audit/event。
- [x] 不恢复 Grok vendor runtime 或平行正式执行图。
- [ ] GitHub Actions/required checks 通过。
- [ ] merge queue 合入 main 并 post-merge verify。

## Verification

static call-path guard + Rust FeatureHost tests.

## Evidence

`evidence/GBF-303/`.

## Next action

审计当前 call path，移除旁路并用 CI guard 固化。
