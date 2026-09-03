# GBF-801 — 全平台 release-candidate regression

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-801
- Stage: M8-release-closure
- Objective: 对同一 RC head 强制执行 canonical CI、Electron desktop、Native Mobile、Computer Control、M7 Security、Mahayana fast、Messaging Product Gate，任何一项非 success 都阻止发布。
- Requirements: GBR-002, GBR-003, GBR-004, GBR-005, GBR-006, GBR-007, GBR-008, GBR-009.
- Dependencies: M2..M7 merge/test closure.
- Status: IN_PROGRESS
- Branch: `gbf/m8-release-closure-20260822`
- Started/Updated: 2026-08-22 19:52+08

## Acceptance
- [ ] RC coordinator dispatches all seven canonical workflows against the exact same branch/head.
- [ ] Every dispatched workflow completes `success`; run ids/head SHAs are captured.
- [ ] No failed/skipped required platform gate is treated as pass.
- [ ] protected merge + post-main verification.

## Evidence
`evidence/GBF-801/README.md` plus GitHub workflow run ids.
