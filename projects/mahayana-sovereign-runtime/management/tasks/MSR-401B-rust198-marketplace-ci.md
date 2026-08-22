# MSR-401B — Rust 1.98 与 Marketplace CI 收敛

- Portfolio: FAB-P0005
- Parent task: MSR-401
- Status: in-progress
- Branch: `fix/msr-401-rust198-marketplace-e2e`

## Goal

消除最新 `main` 在 Rust 1.98 下的 Mahayana MCP runtime Clippy 回归，并移除 Marketplace E2E 对旧 Flutter development R2 proxy 的依赖，使 Embedded Runtime、Native shared Rust、Global Dharma Mahayana gate 与 Marketplace E2E 在 Mahayana-owned 路径上通过。

## Acceptance

- [ ] `mahayana-mcp-runtime` 在 Rust 1.98 下无当前三个 Clippy error：unused `Uuid`、collapsible nested auth `if`、double-ended iterator `.last()`。
- [ ] 修复不改变 MCP auth 行为；`api.ombhrum.com` bearer 注入仍只作用于受控 host，SSE 仍选择最后一个有效事件。
- [ ] Marketplace 外部 artifact 不再通过旧 `fabushi-flutter-web-dev` proxy 获取。
- [ ] R2 artifact 上传、公开 HTTPS 读取、sha256/size 完整性、publish/install/revoke E2E 均保持 fail-closed。
- [ ] Embedded Runtime / Native Mobile shared Rust / Global Dharma Mahayana gate / Marketplace E2E 有 GitHub Actions 通过证据。
- [ ] PR 合并后从 canonical `main` 回读源码与 CI 证据，并在 FAB-P0005 项目记录中记账。

## Evidence before implementation

- PR #2000 Embedded Runtime run `32572666550`, macOS job `97030348984`: Rust 1.98 Clippy exposes the MCP runtime issues.
- PR #2000 Native Mobile run `32572666552`: Android/iOS simulator tests pass; Shared Rust Host fails on the same MCP Clippy issues.
- PR #2000 Marketplace run `32572666607`, job `97030349531`: R2 put succeeds, then old `https://fabushi-flutter-web-dev.bhrumom.workers.dev/r2?...` returns HTTP 401 for all retries.
- Global Dharma run `32572666580`: global workspace test passes; `mahayana-test` is the only failing job and will be reverified after the shared-runtime repair.
