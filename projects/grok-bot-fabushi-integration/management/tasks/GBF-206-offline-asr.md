# GBF-206 — 评估并保留/迁移 Offline ASR

- Project ID: FAB-P0004
- Task ID: GBF-206
- Stage: M2
- Status: RELEASED
- Objective: 确认 Offline ASR 的产品归属、受控下载/校验/执行边界，并纳入当前 Electron 架构。
- Dependencies: GBF-104.
- Implementation PRs: #2005, #2009
- Completed: 2026-08-22 20:12+08

## Acceptance
- [x] Offline ASR 为 Fabushi 当前架构能力，不依赖 Grok runtime。
- [x] 模型 acquisition 仅 HTTPS 且支持 SHA-256 校验。
- [x] ASR process 是桌面唯一允许的隔离 provider 进程面之一。
- [x] offline-asr contract/failure tests 纳入 CI 并通过。
- [x] merge queue + post-main verification 完成。

## Evidence
`evidence/GBF-206/`; PR #2005/#2009; CI #6212; main `dcdc329c...`.
