# GBF-205 — 收敛 native/edge contract

- Project ID: FAB-P0004
- Task ID: GBF-205
- Stage: M2
- Status: RELEASED
- Objective: 统一 native/Mahayana edge method、event、schema、error 与 sender trust contract。
- Dependencies: GBF-202.
- Implementation PRs: #2005, #2009
- Completed: 2026-08-22 20:12+08

## Acceptance
- [x] edge contract version=1，method/event allowlist 唯一。
- [x] untrusted sender、missing handler、handler failure、subscription/dispose 测试通过。
- [x] renderer 不再拥有通用 Host IPC。
- [x] CI、Electron Host smoke、三平台 packaged journeys 全绿。
- [x] merge queue + post-main verification 完成。

## Evidence
`evidence/GBF-205/`; PR #2005/#2009; Electron #521; main `dcdc329c...`.
