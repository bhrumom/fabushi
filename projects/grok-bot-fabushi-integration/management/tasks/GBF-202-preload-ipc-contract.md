# GBF-202 — 收敛 preload/IPC contract

- Project ID: FAB-P0004
- Task ID: GBF-202
- Stage: M2
- Status: RELEASED
- Objective: renderer 仅通过版本化专用 preload/native edge 调用 Host 与系统能力，删除通用 `fabushi:host` 旁路。
- Dependencies: GBF-201.
- Implementation PRs: #2005, #2009
- Completed: 2026-08-22 20:12+08

## Acceptance
- [x] generic `fabushi:host` IPC 已删除。
- [x] `window.mahayana` / edge contract versioned 且 sender allow/deny fail-closed。
- [x] edge contract/failure/security tests 进入 CI。
- [x] Electron Host smoke 与三平台 packaged journeys 全绿。
- [x] main merge `dcdc329c...` 后重新读取验证专用 Mahayana edge 仍为 canonical path。

## Evidence
`evidence/GBF-202/`; PR #2005/#2009; Electron #521; main `dcdc329cb76e609c469eaabbcccb707c0005f56d`.
