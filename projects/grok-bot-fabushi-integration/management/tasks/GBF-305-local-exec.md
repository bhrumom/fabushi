# GBF-305 — 统一 local execution 能力边界

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-305
- Objective: 统一 local execution 能力边界。
- Source requirement IDs: GBR-003, GBR-005.
- Stage: M3
- Status: TESTED (GitHub CI/merge pending)
- Dependencies: GBF-303.
- Implementation branch: `gbf/m3-runtime-convergence-20260822`
- PR: pending
- Started: 2026-08-22 17:13+08
- Updated: 2026-08-22 17:17+08
- Completed: —

## Acceptance criteria

- [x] renderer/desktop 无任意 child_process exec；允许的本地进程只限 Mahayana host 与 Offline ASR；AI computer/local-tool 执行受 settings/approval policy。
- [x] 不恢复 Grok vendor runtime 或平行正式执行图。
- [ ] GitHub Actions/required checks 通过。
- [ ] merge queue 合入 main 并 post-merge verify。

## Verification

process-surface guard + deny-path tests.

## Evidence

`evidence/GBF-305/`.

## Next action

审计当前 call path，移除旁路并用 CI guard 固化。
