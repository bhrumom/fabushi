# M1.T06 — SQLite schema / durable local-first storage

- **Project**: `FABUSHI-TELEGRAM-FUSION`
- **Task ID**: `M1.T06`
- **Stage**: `M1 Rust Core 骨架`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Source**: `../../source/完整telegram融合进fabushi.txt`; `../wbs/M1.md`

## Objective

补齐 canonical `native/mahayana-messaging` 的 SQLite 持久化，使项目不再只依赖 Memory/JSON snapshot，并为后续 local-first 会话/消息索引和跨端恢复建立版本化数据库基础。

## In scope

- versioned SQLite schema and migration entrypoint;
- `SqliteStateStore` implementing existing `MessagingStateStore`;
- crash-safe transactional singleton snapshot persistence;
- schema/snapshot version validation;
- Rust tests for create/save/load/overwrite/reopen/schema rejection;
- Messaging Product Gate verification.

## Out of scope

- 本轮不把每个 message/conversation 拆成完整关系表；先建立可靠的 SQLite persistence boundary，后续按查询/索引需求增量规范化。
- 不删除 JSON store，保留为兼容/测试 adapter，默认产品切换另立任务验证。

## Acceptance criteria

1. 新数据库可自动创建明确版本的 SQLite schema。
2. `MessagingSnapshot` 可事务性保存并在重新打开数据库后完整恢复。
3. 重复 save 覆盖 singleton snapshot，不产生多份冲突状态。
4. 不支持的 DB schema / snapshot schema 返回显式错误。
5. `cargo fmt`、`cargo test --all-targets`、`cargo clippy --all-targets -D warnings` 由 GitHub `Messaging Product Gate` 验证。

## Branch / PR

- Branch: `feat/telegram-m1-sqlite-storage`
- Base: `project/telegram-m0-live-audit` (stacked after M0 audit)
- PR: pending

## Evidence

Pending implementation and CI.

## Next action

实现 SQLite store + tests，创建 stacked PR 并依据 GitHub Actions 结果修复。
