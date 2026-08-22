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

## Implemented

- 新增 bundled `rusqlite` dependency；
- 新增 `MESSAGING_SQLITE_SCHEMA_VERSION = 1`；
- 新增 `SqliteStateStore`，直接实现既有 `MessagingStateStore`，不创建第二套消息核心；
- SQLite `PRAGMA user_version` migration；
- singleton snapshot schema；
- transaction + UPSERT 覆盖保存；
- cursor 以十进制文本保存，避免 `u64` 被 SQLite signed integer 截断；
- snapshot schema 与 database schema 显式兼容性错误；
- Memory / JSON store 同步增加 snapshot schema write validation；
- Rust tests：空库初始化、重开 round-trip、singleton overwrite、future DB schema reject、unknown snapshot schema reject。

## Acceptance criteria

1. 新数据库可自动创建明确版本的 SQLite schema。**IMPLEMENTED**
2. `MessagingSnapshot` 可事务性保存并在重新打开数据库后完整恢复。**IMPLEMENTED / CI PENDING**
3. 重复 save 覆盖 singleton snapshot，不产生多份冲突状态。**IMPLEMENTED / CI PENDING**
4. 不支持的 DB schema / snapshot schema 返回显式错误。**IMPLEMENTED / CI PENDING**
5. `cargo fmt`、`cargo test --all-targets`、`cargo clippy --all-targets -D warnings`。**GITHUB ACTIONS PENDING**

## Branch / PR

- Branch: `feat/telegram-m1-sqlite-storage`
- Base: `project/telegram-m0-live-audit` (stacked after PR #1987)
- PR: #1988 `feat(messaging): add SQLite state storage`

## Evidence

- `native/mahayana-messaging/Cargo.toml`
- `native/mahayana-messaging/src/store.rs`
- `management/wbs/M1.md`
- PR #1988
- Current head at time of update: preceding implementation commit `488bba7f251407b4e9535c3d1d0990599a6c9402`; subsequent documentation commits only update project records.

## Blockers / risks

- GitHub Actions status has not appeared yet for the current stacked PR head, so the task remains `IN_PROGRESS` and is not called `TESTED`.
- JSON store remains available intentionally; switching product default to SQLite should be a separate verified cutover after storage CI is green.

## Next action

Wait for the repository's normal PR event to expose Messaging Product Gate results; once available, fix any rustfmt/test/clippy issue, then promote M1.T06 only with the actual CI evidence. After that, normalize conversation/message indexes and product-default SQLite cutover in the next atomic task.
