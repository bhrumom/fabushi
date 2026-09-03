# ADR-0001: Sovereign Fabushi Integration

Status: Accepted — 2026-08-22

## Decision
Grok Bot 历史源码/行为是迁移输入，不是 Fabushi 的长期外部运行时依赖。所有保留能力必须归入 Fabushi/Mahayana 正式模块；历史分支不得整分支覆盖 main。

## Consequences
迁移速度可能慢于大爆炸复制，但可保留 main 后续修复、降低重复架构和回滚风险，并使产品所有权清晰。
