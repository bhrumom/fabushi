# 参考资料

本文件保存市场、发布和软件更新安全方面的任务设计依据。MCP `2026-07-28` 协议与 Cloudflare 边缘迁移的专门官方资料见 `MCP_2026_07_28_REFERENCES.md`。实施时仍应以当前官方文档和仓库实际代码为准。

## 1. 当前仓库

- 现有动态市场发布、浏览和下载：`fabushi/web/src/handlers/marketplace.js`
- 动态市场测试：`fabushi/web/tests/marketplace.test.js`
- 官方内置市场：`.agents/plugins/marketplace.json`
- 公共发现清单：`frontend/apps/web/public/.well-known/mahayana/marketplace.json`
- 市场说明：`docs/plugin-marketplace.md`
- Flutter 小程序 registry：`fabushi/lib/services/mini_app_registry_service.dart`
- 本地插件发现：`fabushi/lib/services/codex_plugin_catalog_io.dart`
- 官方安装脚本：`scripts/install-official-plugin.sh`、`scripts/install-official-plugin.ps1`
- 官方插件打包：`scripts/package-official-plugin-release.py`
- MCP 最新边缘升级设计：`MCP_2026_07_28_EDGE.md`
- MCP 最新官方资料：`MCP_2026_07_28_REFERENCES.md`

## 2. MCP Registry

MCP Registry 是中央元数据目录，记录唯一名称、包位置、远程 URL、执行和配置方法；实际包可位于 npm、PyPI、Docker 等仓库，远程服务由开发者提供。发布后的版本元数据不可变。

- https://modelcontextprotocol.io/registry/about
- https://modelcontextprotocol.io/registry/faq
- https://modelcontextprotocol.io/registry/versioning
- https://modelcontextprotocol.io/registry/package-types
- https://modelcontextprotocol.io/registry/registry-aggregators

大乘采用的启示：

- Registry/Marketplace 负责身份、发现和可信元数据；
- 运行和包字节不必全部托管在中央市场；
- 版本必须唯一且元数据不可变；
- 市场可以在基础 registry 上增加审核、评分和安全状态。

## 3. npm

npm 的包名+版本发布后不可覆盖；Trusted Publishing 使用 CI OIDC 避免长期发布 Token，并可生成 provenance。

- https://docs.npmjs.com/cli/publish/
- https://docs.npmjs.com/policies/unpublish/
- https://docs.npmjs.com/trusted-publishers/
- https://docs.npmjs.com/generating-provenance-statements/
- https://docs.npmjs.com/viewing-package-provenance/

大乘采用的启示：

- `<pluginId, version>` 永久唯一；
- 发布使用短期、工作流限定 OIDC；
- provenance 绑定源码、commit、workflow 和构件；
- 不能把 SHA-256 当作发布者身份验证。

## 4. VS Code Marketplace

VS Code 扩展以 VSIX 包发布，由 Marketplace 承担认证、托管和管理。

- https://code.visualstudio.com/api/working-with-extensions/publishing-extension

大乘采用的启示：

- 本地运行插件适合不可变包和统一安装契约；
- 市场应提供一致的发布和审核体验；
- 大乘同时包含远程服务，因此不能只复制中心包仓库。

## 5. Slack 应用

Slack 应用可以由开发者自托管，Marketplace 负责展示、审核和安装入口。

- https://api.slack.com/distribution/hosting
- https://api.slack.com/docs/slack-apps-mgmt

大乘采用的启示：

- 中央目录与开发者运行平面可以分离；
- 自托管适合远程 MCP 和 SaaS 集成；
- 自托管仍必须经过身份、审核和安装安全控制。

## 6. Atlassian Forge

Forge 由 Atlassian 管理基础设施、扩缩容和安全边界，开发者不需要自己提供运行环境；Connect 自托管属于旧路线。

- https://developer.atlassian.com/developer-guide/cloud-app-hosting/
- https://developer.atlassian.com/platform/forge/introduction/the-forge-platform/
- https://developer.atlassian.com/platform/forge/introduction/why-build-with-forge/

大乘采用的启示：

- 普通发布者默认应使用平台托管模式；
- 平台托管需要承担沙箱、配额、日志、数据隔离和滥用治理；
- 同时保留高级自托管以满足企业控制需求。

## 7. Cloudflare Workers 版本与部署

Cloudflare Worker version 捕获代码、静态资源、bindings 和兼容设置；deployment 决定哪些版本对外服务，并支持渐进部署和回滚。

- https://developers.cloudflare.com/workers/versions-and-deployments/
- https://developers.cloudflare.com/workers/versions-and-deployments/gradual-deployments/
- https://developers.cloudflare.com/workers/versions-and-deployments/rollbacks/

大乘采用的启示：

- 一个插件使用一个稳定 Worker 服务；
- 每个插件版本映射到 Worker version，而不是永久新 Worker 项目；
- production deployment 可以提升、灰度和回滚；
- Cloudflare version 不会自动版本化外部 D1/KV/Durable Object 状态，因此数据迁移必须独立设计。

## 8. The Update Framework

TUF 为软件更新定义 root、targets、snapshot、timestamp 等角色，防止任意安装、回退、冻结、混搭、错误软件和密钥泄露影响扩散。

- https://theupdateframework.github.io/specification/draft/
- https://theupdateframework.io/

大乘本轮采用核心思想：

- 根信任和在线签名密钥分离；
- 目标元数据包含哈希和大小；
- 元数据版本和过期时间；
- consistent snapshot/不可变寻址；
- 防回退、防冻结和防混搭；
- 密钥轮换和撤销；
- 数据格式未来可升级到完整 TUF。

## 9. 任务设计结论

综合以上模型，大乘不应强制所有插件使用同一种物理托管方式，而应统一逻辑契约：

```text
插件稳定身份
+ 独立服务边界
+ 不可变版本发布物
+ 中央签名可信元数据
+ 托管/自托管两种发布模式
+ CLI 直连下载和本地安全验证
+ MCP 2026-07-28 无状态边缘服务
+ 标准 MCP Apps、Tasks 与 MRTR
```

这既适用于网页和远程 MCP，也适用于 CLI 本地 Runtime 和混合插件。