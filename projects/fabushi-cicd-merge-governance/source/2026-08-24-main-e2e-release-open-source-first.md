# 2026-08-24 — Main 合并后快速 E2E / Release / 自动更新 + 开源优先

项目：`FAB-P0003 / FCM`
来源：用户明确要求

## 原始要求

1. Agent 每合并一个 PR，都必须在 canonical `main` 上快速构建安装包并快速模拟真实用户操作，验证该任务是否真正达到目标。
2. 必须持续修复并重跑，直到该任务相关以及平台规定的全部 E2E 门禁通过；不能只以代码合并或静态检查成功作为任务完成。
3. E2E 全绿后，将通过验证的版本发布到 GitHub Releases。
4. 已安装旧版本必须能够检测 GitHub Release 新版本；用户可点击 App 头像旁的更新按钮完成下载、替换与重启。
5. 构建和测试必须追求最快反馈：跨轮复用依赖、编译缓存、中间产物、模拟器/DerivedData/Gradle/Rust/Node 缓存；小改动只重建失效子图，效果接近热重载，而不是每轮从零开始。
6. 每个任务开始实施前，必须先检查开源仓库是否已有成熟实现；若有，先学习其架构、边界、许可证、安全与维护状态，再优化、创新、融合到 Fabushi，避免重复造轮子。若没有合适成熟方案，要记录搜索范围和自行实现的理由。
7. 并行任务仍然允许；本规则改变的是每个任务自己的启动研究门禁和完成/发布门禁。

## 开源优先调研（本任务已执行）

- `electron-builder/electron-updater`：成熟 GitHub Releases 更新通道，支持签名验证、下载进度、staged rollout；macOS 需要 ZIP 与 `latest-mac.yml` 等 updater 元数据。Fabushi 已使用 `electron-updater`，因此继续复用，不另造更新协议。
- `actions/cache`：GitHub 官方跨 workflow run 缓存，支持精确 key + `restore-keys` 回退；适合作为 Node/Gradle/Xcode 中间态与内容寻址缓存底座。
- `mozilla/sccache` / `mozilla-actions/sccache-action`：Rust/C/C++ 编译结果级缓存，可使用 GitHub Actions cache backend；适合补充现有 `Swatinem/rust-cache`/二进制缓存，降低小改动后的 Rust 重编译成本。
- Playwright 官方 CI 模式：真实用户路径应在 CI/打包产物上运行；可通过并行/分片缩短反馈。Fabushi 已有 Electron Playwright 用户旅程与 Android/iOS UI tests，优先复用现有 E2E，而不是重新建设第二套测试框架。

## 规范化实现约束

- PR 阶段仍以快速 CI 为主；安装包、完整 E2E、签名/notarization、Release 属于合并到 `main` 后的 delivery loop。
- 每个 `main` commit/merged PR 都进入 post-main delivery loop。构建/test 可以并行，但发布必须等待该 commit 的 required E2E 全绿。
- Release 必须绑定精确 `main` SHA，并包含 Electron updater 所需元数据；旧客户端不得把同版本号的新二进制误判为“无更新”。
- 版本号必须单调递增。不能仅用 commit SHA 或 SemVer build metadata 代替可比较版本号。
- 任何 cache miss 都必须能回退到可复现的 clean build；cache 不是 release provenance。
- main delivery 不允许因为另一个 newer commit 到来而静默取消已经合并 PR 的验证；每个 merged SHA 都必须有明确 passed/failed/superseded-with-evidence 状态。

## 验收

- root `AGENTS.md` 写入 open-source-first 启动门禁和 post-main E2E/Release 完成门禁。
- GitHub Actions 有 canonical main post-merge delivery workflow，能够等待/验证 desktop + native mobile E2E，并只在全绿后发布 Release。
- Release 中保留 macOS DMG/ZIP/`latest-mac.yml`/blockmap 等 updater 资产；Electron 旧版本能发现更高版本并由现有头像旁更新控件驱动下载/安装/重启。
- Actions 记录 cache hit/miss 与 warm/cold duration；连续小改动优先命中缓存。
- 本任务自身通过 protected PR、merge queue、canonical-main post-merge 验证后才可关闭。
