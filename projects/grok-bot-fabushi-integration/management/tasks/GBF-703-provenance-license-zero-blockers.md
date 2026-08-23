# GBF-703 — provenance/license release closure

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-703
- Stage: M7-security-provenance
- Objective: 对所有 Grok 历史输入做最终来源/许可发布审计，确保不明授权源码不会进入生产树。
- Requirements: GBR-008, GBR-009.
- Dependencies: GBF-105 and all migration implementation tasks.
- Status: TESTED (CI/merge pending)
- Branch: `gbf/m7-security-provenance-closure-20260822-gh`
- Started/Updated: 2026-08-22 19:40+08

## Acceptance
- [x] Grok Bot 0.20 historical ledger has exactly 148 rows.
- [x] every historical row remains `PROVENANCE_BLOCKED` and `reference-only`.
- [x] `vendor/grok-bot-0.20.0` and retired Grok runtime directories are absent from the production tree.
- [x] clean-room/Fabushi-owned replacements remain separately documented.
- [ ] GitHub security closure gate passes.
- [ ] protected merge + canonical main re-read.

## Evidence
`evidence/GBF-703/README.md` and `evidence/GBF-105/vendor-0.20-provenance.tsv`.
