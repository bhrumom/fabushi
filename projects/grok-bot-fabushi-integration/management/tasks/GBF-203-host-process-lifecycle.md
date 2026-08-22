# GBF-203 — 收敛 host-process lifecycle

- Project ID: FAB-P0004
- Task ID: GBF-203
- Stage: M2
- Status: RELEASED
- Objective: 将 Rust Host 进程生命周期、health/restart、pending request 与 generation 隔离收敛为单一实现。
- Dependencies: GBF-201.
- Implementation PRs: #2005, #2009
- Completed: 2026-08-22 20:12+08

## Acceptance
- [x] spawn generation 防止旧进程迟到 exit/error/stdout 污染新 generation。
- [x] `health()` / explicit `restart()` / closed state / generation-scoped pending cleanup 已实现。
- [x] host fault/restart tests 进入 CI 并通过。
- [x] Electron Host smoke 与 packaged journeys 使用真实 Rust Host 通过。
- [x] merge queue + post-main verification 完成。

## Evidence
`evidence/GBF-203/`; PR #2005/#2009; Electron #521; main `dcdc329c...`.
