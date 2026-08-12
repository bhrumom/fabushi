# Fabushi 极速功能测试开发规范

## 目标

业务逻辑优先进入 Mahayana Rust Core；React Host 只负责交互。普通 Pull Request 不启动 iOS Simulator、Android Emulator 或完整安装包构建。只有平台桥接和发布候选才运行重型测试。

## 新功能的最短路径

1. 在 `frontend/packages/shared/src/mahayana-host-features.ts` 增加稳定 feature id。
2. 在 `frontend/apps/web/src/lib/mahayana-host/contracts.ts` 增加命令或事件契约。
3. 先在 `MockMahayanaHostTransport` 实现确定性行为，让 UI 和用户旅程立即可测试。
4. 在 Host 页面增加真实用户操作入口，并通过 Runtime 事件更新 feature state。
5. 在 `host-fast-user-journey.spec.ts` 增加最短用户操作。
6. 实现 Rust/Tauri transport 后，复用同一契约和同一用户旅程；不得复制业务规则到 UI。

只要功能被加入 feature catalog，却没有在用户旅程中被实际触发，它会保持 `pending`，`Host fast E2E` 会失败。

## 本地快速命令

```bash
cd frontend
corepack enable
pnpm install --frozen-lockfile
pnpm --filter @fabushi/web typecheck:host

cd ../fabushi/e2e
npm ci
npm run test:host-fast
```

Rust 核心定向检查：

```bash
cd third_party/mahayana/mahayana-rs
cargo test -p mahayana-miniapp-protocol -p mahayana-miniapp-bridge --profile ci
cargo check -p mahayana-ffi --profile ci --no-default-features --features local-only
```

## Gate 分层

- **每次 PR，秒级到分钟级：** Host TypeScript、Playwright MockTransport 用户旅程、受影响 Rust crate。
- **平台桥接改动：** Tauri command contract、Swift/Kotlin 插件 smoke。
- **主分支或发布候选：** 安装包、签名、真实设备、升级与回滚。

## 性能预算

- Host 用户旅程自身不超过 120 秒，包括 Next 开发服务器冷启动。
- 新测试不得依赖固定 `sleep`；使用可观察状态和 Playwright 自动等待。
- 不在普通 PR 中执行 Rust release LTO、五平台打包或全量 Flutter E2E。
- 失败时上传 trace、截图和 HTML 报告；成功时不上传大体积 artifact。
