# GBF-204 — 收敛 native capability handlers

- Project ID: FAB-P0004
- Task ID: GBF-204
- Stage: M2
- Status: RELEASED
- Objective: 将桌面高风险系统能力收敛到 allowlisted native handlers，并对拒绝、路径、秘密、网络与诊断行为 fail-closed。
- Dependencies: GBF-202, GBF-203.
- Implementation PRs: #2005, #2009
- Completed: 2026-08-22 20:12+08

## Acceptance
- [x] native capability semantic gate 156/156；event source 28/28。
- [x] permission ceiling、OS encryption unavailable、Secret Vault plaintext、path escape、non-HTTPS download、diagnostic redaction tests 通过。
- [x] handler error path 只通过版本化 edge 返回稳定 failure。
- [x] authoritative CI/Electron tests 通过并合入 main。
- [x] post-main verification 完成。

## Evidence
`evidence/GBF-204/`; PR #2005/#2009; CI #6212; main `dcdc329c...`.
