# M1.T06 — SQLite schema / durable local-first storage

- **Project**: `FABUSHI-TELEGRAM-FUSION`
- **Task ID**: `M1.T06`
- **Stage**: `M1 Rust Core 骨架`
- **Status**: `TESTED`
- **Started**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Source**: `../../source/完整telegram融合进fabushi.txt`; `../wbs/M1.md`

## Objective

补齐 canonical `native/mahayana-messaging` 的 SQLite 持久化，使项目不再只依赖 Memory/JSON snapshot，并为 local-first 恢复建立版本化数据库基础。

## Implemented

- `rusqlite 0.39`，与 Mahayana/Codex workspace 的 `libsqlite3-sys 0.37` 对齐；
- `MESSAGING_SQLITE_SCHEMA_VERSION = 1`；
- `SqliteStateStore` 实现既有 `MessagingStateStore`；
- SQLite `PRAGMA user_version` migration；
- singleton snapshot schema；
- transaction + UPSERT；
- cursor 以 decimal text 持久化，完整覆盖 `u64`；
- snapshot/database schema compatibility errors；
- Memory / JSON write schema validation；
- tests：empty DB initialization、reopen round-trip、singleton overwrite、future DB schema rejection、unknown snapshot schema rejection。

## Acceptance result

1. 新数据库自动创建明确版本 schema：PASS。
2. `MessagingSnapshot` 事务保存并在重开后恢复：PASS。
3. 重复 save 只保留 singleton state：PASS。
4. 不支持的 DB/snapshot schema 显式拒绝：PASS。
5. Rust fmt/test all-targets/clippy `-D warnings`：PASS。
6. Production Feature Host/contact projection compatibility：PASS。
7. Electron Messenger contract / Native Edge parity / TypeScript bridge：PASS。

## CI evidence

- PR: #1988 `feat(messaging): add SQLite state storage`
- Head verified: `fc8197a8b5b1d738ae1a4d1d6110cd3bf5a92f39`
- Messaging Product Gate run: `32559222693` — SUCCESS
  - Rustfmt: success
  - messaging all-target tests: success
  - Clippy: success
  - Feature Host/contact projection: success
  - Electron Messenger contract: success
- Mahayana fast checks run: `32559222679` — SUCCESS
- Explicit automerge workflow run: `32559222681` — SUCCESS

## CI issue resolved

Initial CI exposed a single-native-link conflict: `rusqlite 0.32` required `libsqlite3-sys 0.30`, while Mahayana/Codex uses `libsqlite3-sys 0.37`. The dependency was aligned to `rusqlite 0.39`, after which both required product gates passed.

## Branch / PR

- Branch: `feat/telegram-m1-sqlite-storage`
- Base: `main`
- PR: #1988

## Evidence files

- `native/mahayana-messaging/Cargo.toml`
- `native/mahayana-messaging/src/store.rs`
- `management/wbs/M1.md`
- `evidence/M1-T06/README.md`

## Remaining gate

`TESTED` reflects current-head CI. Task closure as landed work still requires protected merge queue completion and canonical `main` verification.

## Next action

Enter protected merge queue for #1988. After merge, verify the SQLite code and task record on `main`, then let M1.T02 / #1990 make SQLite the production default with one-time legacy JSON migration.
