# 参考资料

本文件保存市场、发布和更新安全设计依据。MCP Apps 与 Cloudflare runtime 的正式依据请优先阅读 `MCP_APPS_REFERENCES.md`。

## 1. 当前仓库

- 动态市场：`fabushi/web/src/handlers/marketplace.js`
- 动态市场测试：`fabushi/web/tests/marketplace.test.js`
- 官方内置市场：`.agents/plugins/marketplace.json`
- 公共发现：`frontend/apps/web/public/.well-known/mahayana/marketplace.json`
- Web 小程序 Host：`frontend/apps/web/src/app/miniapps/[id]/McpPluginApp.tsx`
- 大乘自定义 SDK：`frontend/packages/mcp-app-sdk/`
- Flutter 小程序模型：`fabushi/lib/models/mini_app_model.dart`
- Flutter registry：`fabushi/lib/services/mini_app_registry_service.dart`
- 本地插件发现：`fabushi/lib/services/codex_plugin_catalog_io.dart`

## 2. MCP Apps

- https://github.com/modelcontextprotocol/ext-apps
- https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx
- https://github.com/modelcontextprotocol/ext-apps/blob/main/docs/overview.md

采用：

- `io.modelcontextprotocol/ui`；
- `ui://`；
- `text/html;profile=mcp-app`；
- AppBridge；
- sandbox/CSP；
- model/app visibility；
- JSON-RPC over postMessage。

## 3. Cloudflare stateless MCP

- https://developers.cloudflare.com/agents/model-context-protocol/apis/handler-api/
- https://developers.cloudflare.com/agents/model-context-protocol/guides/migrate-to-mcp-sdk-v2/
- https://developers.cloudflare.com/agents/model-context-protocol/guides/remote-mcp-server/
- https://developers.cloudflare.com/workers/versions-and-deployments/

采用：

- `createMcpHandler`；
- `@modelcontextprotocol/server` SDK v2；
- production `legacy: "reject"`；
- 每请求 server factory；
- 显式业务状态；
- Host/Origin/OAuth 校验。

禁止使用 `createLegacyMcpHandler`、`McpAgent` 和 SDK v1 production server。

## 4. MCP Registry

- https://modelcontextprotocol.io/registry/about
- https://modelcontextprotocol.io/registry/faq
- https://modelcontextprotocol.io/registry/versioning

采用：Registry/Marketplace 负责身份、发现和可信元数据；运行与包字节可以由插件服务承载；版本元数据不可变。

## 5. npm Trusted Publishing 与 provenance

- https://docs.npmjs.com/cli/publish/
- https://docs.npmjs.com/trusted-publishers/
- https://docs.npmjs.com/generating-provenance-statements/
- https://docs.npmjs.com/viewing-package-provenance/

采用：`pluginId + version` 不可复用；GitHub Actions OIDC 短期发布凭证；provenance 绑定源码、commit、workflow 和构件。

## 6. VS Code、Slack、Forge

- https://code.visualstudio.com/api/working-with-extensions/publishing-extension
- https://api.slack.com/distribution/hosting
- https://developer.atlassian.com/developer-guide/cloud-app-hosting/

采用混合市场：中央控制平面 + 每插件独立运行平面；普通用户默认平台托管，高级用户可验证后自托管。

## 7. The Update Framework

- https://theupdateframework.github.io/specification/draft/
- https://theupdateframework.io/

采用：根信任、目标哈希和大小、元数据版本与过期、防回退、防冻结、密钥轮换和撤销。

## 8. 任务设计结论

```text
MCP Apps-only UI/runtime contract
+ Cloudflare stateless SDK v2
+ production legacy rejection
+ plugin stable identity
+ independent service boundary
+ immutable releases
+ central signed metadata
+ OIDC/provenance
+ CLI direct download and safe install
```

不得把 Cloudflare 文档更新时间误写为 MCP Apps 规范版本。当前任务正式采用 MCP Apps stable `2026-01-26`，Cloudflare runtime 使用实施时官方要求的精确 SDK v2 版本。
