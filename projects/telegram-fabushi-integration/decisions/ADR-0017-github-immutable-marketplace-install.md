# ADR-0017 — Marketplace 采用 GitHub 不可变版本安装更新合同

- **状态**：Accepted; M8-MARKET-003 delivery gates passed
- **日期**：2026-09-13
- **项目**：`FAB-P0001` / `TFI`

## 背景

原有市场同时存在 bundled userscript、package release、Web localStorage 安装标记和 Host 安装路径。它们的版本、来源和更新判断不一致，无法让用户像油猴脚本一样清楚地看到当前版本、最新版本、更新来源和权限，也无法证明市场展示的代码就是用户实际安装的代码。

## 决策

1. 所有可安装 Mini App/插件使用 `fabushi.marketplace.install.v1`，外层仍是 `mahayana.external-release.v1`。
2. release metadata 必须包含稳定 `pluginId`、版本、public GitHub repository、40 位 commit `sourceRef`，以及每个平台 artifact 的 HTTPS URL、SHA-256、size、format、entry、runtime 和 platforms。
3. Marketplace 只负责审核、索引和返回 metadata，不托管或代理可执行包字节；`marketplaceHostsPackage` 必须显式为 `false`。
4. Desktop/mobile/CLI 通过 Mahayana Host 下载、校验、staging 和激活；Chrome userscript 由用户显式点击后取得 pinned raw GitHub artifact，校验后交给 userscript runtime；Web 只记录 metadata，执行包需要 Native Host。
5. 更新比较版本后比较 digest；候选版本低于 active 时 fail closed，同版本 digest 不同只能显式 reinstall；激活前保留 `previous-active.json`，回滚必须显式触发。

## 开源优先调查

- [Violentmonkey](https://github.com/violentmonkey/violentmonkey)（MIT）：参考 userscript 元数据、稳定身份、版本发现和执行边界；不复制代码。
- [Open VSX](https://github.com/eclipse-openvsx/openvsx)（EPL-2.0）：参考版本化目录、扩展激活/update indexing 和 artifact integrity；不引入其服务端栈。
- [Obsidian community plugin releases](https://github.com/obsidianmd/obsidian-releases)：参考 manifest、兼容性字段和 GitHub Release asset 组合；不 vendoring 代码。

选择复用现有 Mahayana `ArtifactResolver`/`PluginInstaller` 和 Marketplace release contract，而不是新增一套 updater 依赖。许可证和 provenance 仅作为设计参考，不产生新的第三方运行时义务。

## 取舍与后果

- 优点：来源可审计、安装字节可复验、跨端状态一致、可明确阻止降级并保留回滚路径；用户体验可统一为安装/更新/重新安装/已是最新/阻止降级。
- 代价：每次代码变更必须创建新的不可变 commit、digest 和可比较版本；旧的非 GitHub/损坏 artifact 不能继续走新安装路径，需要重新发布。
- 安全边界：Hosted Web 代码仍由 HTTPS 页面和 Host/WebMCP 沙箱约束；市场不会把任意远程 JS 注入宿主页面。

## 验收与回滚

Node/Rust/Chrome/frontend/mobile/CLI 合同检查、负向测试、PR exact-head CI、protected-main、canonical-main packaged E2E 和必需视觉/trace/report evidence 已在 accepted product SHA `f6a0d99c85a481999298a18cada6a9f10718a360` 上通过。固定 catalog 的三项损坏历史包由 CI 重建为 `1.0.1` 并发布到 [marketplace-v1.0.1-cc23420c56c9](https://github.com/bhrumom/fabushi/releases/tag/marketplace-v1.0.1-cc23420c56c9)；桌面测试版本 [desktop-1.2.65](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.65) 于 `2026-09-14T02:50:58Z` 以同一 SHA 发布，包含 updater metadata、blockmap 和跨平台安装包。回滚优先切换到最后一个 digest/size 与实际字节一致的 GitHub Release；不得用可变 branch 或市场缓存代替回滚 provenance。

Optional old-client updater discovery/download/install/relaunch regression was not run. It remains advisory under the repository completion contract and was not promoted to a required acceptance gate for this task. The public Chrome Web Store submission was not attempted because protected store credentials were unavailable; the exact final Chrome package was produced and retained by CI.
