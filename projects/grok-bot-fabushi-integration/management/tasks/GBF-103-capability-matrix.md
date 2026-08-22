# GBF-103 — Capability matrix

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-103
- Stage: M1-source-inventory
- Status: RELEASED
- Objective: 将共同基线到两个历史 Grok 输入 head 的全部变化文件映射到稳定 capability domain，避免功能漏盘点。
- Source requirements: GBR-001, GBR-002
- Dependencies: GBF-102.
- Branch: `gbf/gbf-101-m1-inventory-20260822`
- Started/Updated: 2026-08-22

## Acceptance / verification

- [x] latest 变化面 149 files、0.16 变化面 69 files 的 union 形成 151-row capability matrix。
- [x] 每个 path 有 deterministic domain。
- [x] `classification=CAPABILITY_MAPPED`；unclassified = 0。
- [x] 关键域覆盖 Electron/Host/UI/Mahayana/native/computer-control/auth/CI/ASR 等。
- [ ] PR required CI / protected merge / post-merge main verification pending.

## Evidence

`evidence/GBF-103/capability-matrix.tsv`, `evidence/GBF-103/README.md`, `evidence/M1-validation.json`.

## Result / next

能力映射已建立；继续 GBF-104 将每一个 source/main path difference 赋予处理决策。

- Completed: 2026-08-22 17:01+08
