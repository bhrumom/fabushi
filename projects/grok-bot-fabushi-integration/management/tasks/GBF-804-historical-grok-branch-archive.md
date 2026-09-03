# GBF-804 — 历史 Grok 分支退出运行权威

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-804
- Stage: M8-release-closure
- Objective: 在正式发布后记录历史 Grok fusion 分支的最终治理决策：仅保留只读审计/追溯价值，不再作为 build/runtime/release 输入，不通过 wholesale merge 恢复旧树。
- Requirements: GBR-008, GBR-009.
- Dependencies: GBF-703, GBF-803.
- Status: NOT_STARTED
- Branch: `gbf/m8-release-closure-20260822`
- Started/Updated: 2026-08-22 19:52+08

## Acceptance
- [ ] ADR 记录 `grok-bot-latest-source-fusion` 和 `grok-bot-0.16-source-fusion` 精确 refs 与 RETAIN_READ_ONLY_AUDIT 决策。
- [ ] repository/project docs 明确 `main` 是唯一运行/发布权威。
- [ ] CI/release workflow 不引用历史 Grok branches。
- [ ] no-wholesale-merge rule 保持可机器审计。
- [ ] post-release branch/ref audit recorded。

## Evidence
`evidence/GBF-804/README.md` and final ADR.
