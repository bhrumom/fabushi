# GBF-102 — Recursive source manifests

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-102
- Stage: M1-source-inventory
- Status: RELEASED
- Objective: 对两个固定历史来源 head 递归枚举 Git mode/type/object/size/path，保证来源树 100% 可重建、可校验。
- Source requirements: GBR-001, GBR-008
- Dependencies: GBF-101 pinned refs.
- Branch: `gbf/gbf-101-m1-inventory-20260822`
- Started/Updated: 2026-08-22

## Acceptance / verification

- [x] latest 0.20 head manifest: 13,717 entries; tree `20b5abfc13b1e21abecd72fcc4a816b3233e4431`.
- [x] legacy 0.16 head manifest: 13,694 entries; tree `a0f061511a387f5de543882d8109f0c64e26f4a3`.
- [x] 每条记录包含 mode/type/object/size/path。
- [x] 生成文件记录 SHA-256；脚本重新枚举数量一致。
- [ ] PR required CI / protected merge / post-merge main verification pending.

## Evidence

`evidence/GBF-102/README.md`, `summary.json`, `manifests/*.tsv`, `evidence/M1-validation.json`.

## Result / next

文件级清单已本地轻量验证。继续 GBF-103/104/105 并在同一 M1 PR 中接受 CI。

- Completed: 2026-08-22 17:01+08
