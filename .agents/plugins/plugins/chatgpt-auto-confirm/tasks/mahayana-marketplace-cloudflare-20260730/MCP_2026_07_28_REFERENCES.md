# MCP 2026-07-28 官方参考资料

实施 `MCP_2026_07_28_EDGE.md` 时，以以下官方资料及其当时最新版本为准，不得仅依据二手文章或旧 SDK 示例。

## MCP 正式发布与协议

- MCP 2026-07-28 正式发布：
  - https://blog.modelcontextprotocol.io/tags/release/
- 2026-07-28 主要变化与无状态设计：
  - https://blog.modelcontextprotocol.io/posts/2026-07-28-release-candidate/
- Stateless MCP / `server/discover`：
  - https://modelcontextprotocol.io/seps/2575-stateless-mcp
  - https://modelcontextprotocol.io/specification/2026-07-28/server/discover
- 规范与版本协商：
  - https://modelcontextprotocol.io/specification/2026-07-28
  - https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning

正式发布后的最终规范优先于 RC 博文；若 URL 结构调整，应从 modelcontextprotocol.io 的当前 specification 索引进入。

## MCP Apps

- MCP Apps 概览：
  - https://modelcontextprotocol.io/extensions/apps/overview
- MCP Apps 官方文档和 SDK：
  - https://apps.extensions.modelcontextprotocol.io/
  - https://apps.extensions.modelcontextprotocol.io/api/documents/Overview.html
- MCP Apps 规范仓库：
  - https://github.com/modelcontextprotocol/ext-apps

重点核对：

- `ui://` resource；
- `_meta.ui.resourceUri`；
- AppBridge；
- sandboxed iframe；
- CSP；
- tool visibility；
- host context；
- display modes；
- progressive enhancement 和文本降级。

## Tasks 扩展

- Tasks 扩展入口：
  - https://modelcontextprotocol.io/extensions/tasks/overview
- SDK 实现与迁移说明应从对应官方 SDK 当前文档进入。

重点核对：

- server-directed task creation；
- `tasks/get`；
- `tasks/update`；
- `tasks/cancel`；
- 不使用全局 `tasks/list`；
- task 身份和权限隔离。

## Cloudflare Workers / Agents SDK

- Cloudflare Agents SDK MCP 2026-07-28 支持：
  - https://developers.cloudflare.com/changelog/post/2026-07-27-agents-sdk-v0.20.0-mcp-sdk-v2/
- Remote MCP Server：
  - https://developers.cloudflare.com/agents/model-context-protocol/guides/remote-mcp-server/
- MCP handler API：
  - https://developers.cloudflare.com/agents/model-context-protocol/apis/handler-api/
- MCP SDK v2 迁移：
  - https://developers.cloudflare.com/agents/model-context-protocol/guides/migrate-to-mcp-sdk-v2/
- Cloudflare Worker 版本和部署：
  - https://developers.cloudflare.com/workers/versions-and-deployments/

Cloudflare 当前推荐：

- 新无状态服务使用 `agents/mcp/server` 的 `createMcpHandler()`；
- SDK v2 server factory 使用 `@modelcontextprotocol/server`；
- `McpAgent` 已弃用并进入 feature-frozen；
- 需要旧 sessionful 能力时，只保留临时 legacy lane；
- 普通 tools、prompts、resources 和 elicitation 不应继续依赖 MCP transport session 或 Durable Object。

## 官方 SDK

- TypeScript SDK：
  - https://github.com/modelcontextprotocol/typescript-sdk
  - https://github.com/modelcontextprotocol/typescript-sdk/blob/main/docs/migration/support-2026-07-28.md
- Python SDK：
  - https://github.com/modelcontextprotocol/python-sdk
- Go SDK：
  - https://github.com/modelcontextprotocol/go-sdk

实施时必须锁定经过验证的精确版本。若 SDK v2 仍处于 beta，不得使用浮动 latest；应固定 Cloudflare Agents SDK 文档要求的兼容版本，并通过 conformance 和真实 Workers 部署验证后再升级。

## 当前大乘代码定位

- Web 小程序 MCP 宿主：
  - `frontend/apps/web/src/app/miniapps/[id]/McpPluginApp.tsx`
- 大乘 MCP App SDK：
  - `frontend/packages/mcp-app-sdk/`
- Flutter 小程序模型和协议版本：
  - `fabushi/lib/models/mini_app_model.dart`
- Flutter 小程序 registry：
  - `fabushi/lib/services/mini_app_registry_service.dart`
- 本地插件发现：
  - `fabushi/lib/services/codex_plugin_catalog_io.dart`
- 动态市场服务：
  - `fabushi/web/src/handlers/marketplace.js`

当前审计基线：

- `hostApiVersion` 仍为 `mcp-2025-06-18`；
- Web 客户端仍调用 `initialize` / `notifications/initialized`；
- 仍使用 `Mcp-Session-Id`、GET/SSE 和 DELETE session；
- 仍声明 Roots；
- iframe 协议与 MCP Apps 相似，但尚未完整采用官方 AppBridge 和安全元数据。

后续实现必须以代码实际状态重新核验，不能假设这些缺口在 Action 开始时仍完全相同。