# GBF-306 — 统一错误/重试/超时/并发和取消

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-306
- Objective: 统一错误/重试/超时/并发和取消。
- Source requirement IDs: GBR-003, GBR-007.
- Stage: M3
- Status: TESTED (GitHub CI/merge pending)
- Dependencies: GBF-303, GBF-304, GBF-305.
- Implementation branch: `gbf/m3-runtime-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:13+08
- Updated: 2026-08-22 17:17+08
- Completed: —

## Acceptance criteria

- [x] Host generation、FeatureHost operation、kernel resilience 的失败/中断语义确定；无旧 generation 影响新请求。
- [x] 不恢复 Grok vendor runtime 或平行正式执行图。
- [ ] GitHub Actions/required checks 通过。
- [ ] merge queue 合入 main 并 post-merge verify。

## Verification

fault tests + Rust runtime/kernel tests + CI.

## Evidence

`evidence/GBF-306/`.

## Next action

审计当前 call path，移除旁路并用 CI guard 固化。
