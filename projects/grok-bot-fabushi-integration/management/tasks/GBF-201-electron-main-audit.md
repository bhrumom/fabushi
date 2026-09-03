# GBF-201 — 审计并收敛 Electron main.cjs 生命周期/IPC 行为

- Project ID: FAB-P0004
- Task ID: GBF-201
- Stage: M2
- Status: RELEASED
- Objective: 审计并收敛 Electron main.cjs 生命周期/IPC 行为，保留 main 后续修复并移除历史旁路。
- Dependencies: GBF-104.
- Implementation PRs: #2005, #2009
- Completed: 2026-08-22 20:12+08

## Acceptance
- [x] main/source lifecycle + IPC 差异完成 capability-level 决策。
- [x] 生命周期、拒绝、错误、恢复路径有自动化证据。
- [x] authoritative CI / Electron Host smoke / packaged macOS-Windows-Linux journeys 全绿。
- [x] merge queue 合入 `main`，merge `dcdc329cb76e609c469eaabbcccb707c0005f56d`。
- [x] post-merge `main` 重新读取验证 canonical implementation。

## Evidence
`evidence/GBF-201/`; PR #2005/#2009; Electron run #521; CI #6212; canonical main `dcdc329c...`.
