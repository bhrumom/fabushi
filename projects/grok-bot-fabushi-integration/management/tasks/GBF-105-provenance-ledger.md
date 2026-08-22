# GBF-105 — Provenance ledger

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-105
- Stage: M1-source-inventory
- Status: TESTED (merge/main closure pending)
- Objective: 对 Grok 迁移变化面和 0.20 vendor 历史快照建立来源/许可状态/复用策略，保证不明授权代码不会静默进入产品。
- Source requirements: GBR-008, GBR-009
- Dependencies: GBF-102.
- Branch: `gbf/gbf-101-m1-inventory-20260822`
- Started/Updated: 2026-08-22

## Acceptance / verification

- [x] 151-row migration-surface ledger 每行有 provenance origin / license state / reuse policy；UNKNOWN=0。
- [x] 追溯 `8bb9f6a093f17189010e5f5231c8694d53ccf190`：0.20 canonical production snapshot 共 148 entries。
- [x] 该 vendor snapshot 的 parent 是固定 0.16 head；后续由 `25e02683d0c2a8767faabee8df0d0c0668931b8f` 删除。
- [x] vendor snapshot 在 `grok-bot-latest-source-fusion` head 与 current main 均不存在。
- [x] 148 个 vendor entries 全部标记 `PROVENANCE_BLOCKED` / reference-only；无明确授权不得原样发布。
- [x] Grok-derived behavior 采用 Fabushi-owned clean reimplementation 优先策略。
- [ ] PR required CI / protected merge / post-merge main verification pending.

## Evidence

`evidence/GBF-105/provenance-ledger.tsv`, `vendor-0.20-provenance.tsv`, `historical-vendor.json`, `README.md`.

## Result / next

来源阻塞已显式化且生产 main 不保留 vendor snapshot。后续 GBF-703 需要持续审计迁移 PR，确保 release retained-source blocking=0。
