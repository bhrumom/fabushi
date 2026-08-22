# GBF-207 — Electron E2E closure

- Project ID: FAB-P0004
- Task ID: GBF-207
- Stage: M2
- Status: RELEASED
- Objective: 用真实 Electron sandbox + Rust Host + 三平台 packaged application user journeys 证明当前桌面架构可运行。
- Dependencies: GBF-201..206.
- Implementation PRs: #2005, #2009
- Completed: 2026-08-22 20:12+08

## Acceptance
- [x] Messenger edit 使用应用内受控对话框，不依赖原生 `prompt()`。
- [x] AI 群组创建必须选择 Bot；Host 零 Agent 拒绝路径保持 fail-closed。
- [x] message pin selector 与 invoice flow 均按真实产品 UI 修复。
- [x] Electron Host simulated user smoke SUCCESS。
- [x] macOS / Windows / Linux package + packaged user journey 全部 SUCCESS。
- [x] `Electron desktop result` SUCCESS；CI #6212 / Messaging #57 / Self-hosted Messaging #121 / Portfolio #65 SUCCESS。
- [x] PR #2009 merge queue 合入 main，merge `dcdc329cb76e609c469eaabbcccb707c0005f56d`。
- [x] post-main canonical verification 完成。

## Evidence
`evidence/GBF-207/`; Electron run #521; PR #2009; canonical main `dcdc329c...`.
