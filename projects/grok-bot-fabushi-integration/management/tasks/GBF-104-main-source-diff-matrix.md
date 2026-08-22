# GBF-104 — Main/source diff matrix

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-104
- Stage: M1-source-inventory
- Status: TESTED (merge/main closure pending)
- Objective: 对每个固定 source head 与固定 main 的全部 path difference 给出明确处理分类，禁止无决策的大规模覆盖。
- Source requirements: GBR-001, GBR-002, GBR-009
- Dependencies: GBF-102, GBF-103.
- Branch: `gbf/gbf-101-m1-inventory-20260822`
- Started/Updated: 2026-08-22

## Acceptance / verification

- [x] latest -> main: 2,046 difference rows, 每行有 domain + decision。
- [x] 0.16 -> main: 2,118 difference rows, 每行有 domain + decision。
- [x] 分类只使用 `MAIN_HAS`, `MAIN_SUPERSEDES_REVIEW`, `SOURCE_BETTER_REVIEW`, `MIGRATE_REWRITE_REVIEW`, `DEPRECATE`, `DEPRECATE_OR_REWRITE`。
- [x] main-only/retired-client/Grok-derived 路径分别按权威策略处理。
- [ ] PR required CI / protected merge / post-merge main verification pending.

## Evidence

`evidence/GBF-104/diff-*.tsv`, `summary.json`, `README.md`, `evidence/M1-validation.json`.

## Result / next

差异已无空处理分类；继续 GBF-105 provenance，之后按 capability domain 进入 M2-M7 原子审计/实现。
