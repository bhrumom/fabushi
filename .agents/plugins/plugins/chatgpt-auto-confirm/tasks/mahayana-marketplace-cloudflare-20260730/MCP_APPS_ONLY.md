# 大乘小程序 MCP Apps 全量新架构

## 文档地位

本文件是任务 `mahayana-marketplace-cloudflare-20260730` 的最高优先级协议约束。任何其他任务文档与本文件冲突时，以本文件为准。

目标不是兼容旧 MCP 小程序，而是把大乘小程序、宿主、插件模板、市场准入和 Cloudflare 运行时全面迁移到官方 MCP Apps 与无状态 MCP SDK v2。生产环境不得保留旧协议运行通道。

## 1. 唯一技术基线

### MCP Apps

采用官方 MCP Apps 稳定规范 `2026-01-26`：

- 扩展标识：`io.modelcontextprotocol/ui`；
- UI 资源使用 `ui://` URI；
- MIME 类型使用 `text/html;profile=mcp-app`；
- Tool 通过 `_meta.ui.resourceUri` 关联 UI；
- View 与 Host 使用标准 MCP JSON-RPC over `postMessage`；
- Host 使用 AppBridge 或完全符合规范的实现；
- iframe 必须 sandbox；
- CSP 必须按资源声明生成并强制执行；
- Tool visibility 必须区分 `model` 与 `app`；
- 支持 host context、display modes、资源 teardown 和可审计工具调用；
- Tool 仍返回有意义的 `content` 与 `structuredContent`，这是 MCP Apps 标准的渐进呈现能力，不是旧协议兼容。

### Cloudflare MCP 服务

每个插件 Worker 使用：

```text
agents/mcp/server createMcpHandler
@modelcontextprotocol/server 2.x SDK v2 server factory
legacy: "reject"
```

实施时按当前 Cloudflare Agents SDK 文档锁定精确兼容版本，不使用浮动 `latest`。

必须：

- 每个 HTTP 请求创建独立 SDK v2 server；
- 任意边缘实例可以处理任意请求；
- 业务状态通过认证后的显式 ID、resource URI、task handle 或数据库主键表达；
- 需要强一致业务状态时可使用 D1、KV、Durable Object、Queue 或 Workflow，但不得用于恢复 MCP transport session；
- 浏览器 Origin、Host、OAuth scope 和插件身份必须校验；
- 生产入口设置 `legacy: "reject"`。

## 2. 明确禁止的旧实现

生产代码、模板、部署、市场准入和验收中禁止：

- `createLegacyMcpHandler`；
- `McpAgent`；
- `@modelcontextprotocol/sdk` v1 server；
- `WorkerTransport`；
- MCP transport session store；
- `Mcp-Session-Id`；
- sticky session；
- 通过 HTTP GET/DELETE 管理 MCP 会话；
- 为旧协议维持长期 SSE session；
- legacy route 或 legacy compatibility lane；
- 旧 `mcp-2025-06-18` 主机版本；
- 大乘自定义 iframe ready/tool/result 消息方言；
- 为旧客户端保留 production fallback；
- 市场继续接受只含旧 MCP manifest 的新版本。

旧客户端访问新服务时必须收到稳定、可诊断的升级错误，例如：

```json
{
  "error": "MCP_APPS_HOST_UPGRADE_REQUIRED",
  "minimumHostVersion": "<required-version>",
  "documentation": "<upgrade-doc-url>"
}
```

## 3. 新架构边界

```text
大乘 App / Web / Desktop / CLI Host
        │
        ├── MCP SDK v2 client
        ├── MCP Apps AppBridge
        ├── sandbox + CSP + permission broker
        └── no legacy session transport
        │
        ▼
每插件独立 Cloudflare Worker
        │
        ├── createMcpHandler({ legacy: "reject" })
        ├── Tools / Resources / Prompts
        ├── ui:// MCP App resources
        ├── OAuth/OIDC authorization
        ├── explicit business-state handles
        └── immutable release resources
```

## 4. Host 全量迁移

必须删除现有 Web、Flutter、桌面和 CLI 中的旧 MCP host 路径，并统一为共享 MCP Apps host core。

Host 必须实现：

- MCP Apps extension capability；
- AppBridge；
- `ui/initialize` 与 `ui/notifications/initialized`；
- `tools/call`、`resources/read`、`notifications/message`；
- `ui/open-link`；
- `ui/resource-teardown`；
- host context：主题、locale、timezone、平台、尺寸；
- inline、fullscreen、picture-in-picture 能力；
- model/app tool visibility；
- sandbox、CSP、Origin 和导航策略；
- 安装权限与运行时工具权限的统一确认和审计；
- UI 资源按插件版本与内容哈希缓存。

注意：`ui/initialize` 是 MCP Apps View 与 Host 的标准握手，必须保留；它不等同于旧 MCP 服务端 session 初始化。

必须删除：

- 保存和发送 `Mcp-Session-Id`；
- 旧服务端 `initialize`/session 分支；
- 长期 GET/SSE listener；
- DELETE session；
- 自定义 iframe message schema；
- 旧 hostApiVersion fallback。

## 5. 插件全量迁移

所有官方插件和验收插件必须转换成真正 MCP App：

1. Tool 注册包含 `_meta.ui.resourceUri`；
2. 注册对应 `ui://` resource；
3. resource MIME 为 `text/html;profile=mcp-app`；
4. View 使用官方 `@modelcontextprotocol/ext-apps`；
5. Host 使用 AppBridge；
6. CSP 和外部域名最小化声明；
7. app-only tools 不暴露给模型；
8. model-only tools 不允许 View 调用；
9. Tool 返回文本、结构化数据和 UI 资源关联；
10. 不再打包或发布旧 bridge runtime。

未完成迁移的插件版本：

- 不得进入 `community`、`verified` 或 `official`；
- 不得成为 production；
- 市场详情显示 `migration_required`；
- 用户只能升级到 MCP Apps 版本或卸载，不能在新 Host 中继续运行旧版本。

## 6. 市场准入契约

每个正式版本必须声明：

```json
{
  "runtime": {
    "kind": "mcp-app",
    "mcpSdk": "v2",
    "transport": "stateless-http",
    "legacy": false,
    "extension": "io.modelcontextprotocol/ui"
  },
  "ui": {
    "resources": ["ui://io.mahayana.publisher.plugin/main"],
    "mimeTypes": ["text/html;profile=mcp-app"],
    "displayModes": ["inline", "fullscreen"]
  }
}
```

市场发布校验必须拒绝：

- `legacy: true`；
- SDK v1 server；
- 无 `ui://` 资源；
- 无 MCP Apps extension 声明；
- 不安全或过宽 CSP；
- 自定义 iframe bridge；
- 依赖 MCP session ID；
- production endpoint 允许 legacy 请求。

## 7. 长任务与用户输入

长时间构建、扫描、部署、审核和插件工具工作必须使用新 SDK v2 支持的显式 task/workflow 状态，不使用旧 transport session 保持请求。

需要用户输入或授权时使用无状态多轮请求：

- 返回 `input_required`；
- 携带完整性保护的 `requestState`；
- Host 收集输入后重新提交；
- 任意边缘实例可继续；
- 超时、取消、重复提交和篡改必须可验证处理。

## 8. 硬切换策略

采用“先全部迁移，后一次切换”，而不是运行期双栈：

1. 在隔离环境完成共享 Host core；
2. 迁移所有官方插件；
3. 迁移示例第三方插件；
4. 市场校验器只接受 MCP Apps；
5. 全平台测试通过；
6. Cloudflare preview 验证 `legacy: "reject"`；
7. 一次性切换 production；
8. 删除旧路由、旧 SDK、旧 bridge 和旧测试；
9. 旧客户端只返回升级错误。

可保留数据迁移脚本和静态分析器来识别旧插件，但不得保留运行旧插件的代码。

## 9. 完成定义

任务只有在以下条件全部满足时才算完成：

- 新 Host 不包含旧 session transport；
- 所有官方小程序均为 MCP Apps；
- 新插件模板只生成 MCP Apps；
- 市场拒绝旧 MCP 插件；
- Cloudflare production 使用 `createMcpHandler` 和 `legacy: "reject"`；
- 依赖树不再包含生产用途的 SDK v1；
- 自定义 iframe bridge 已删除；
- 旧 GET/SSE/DELETE session 路由已删除；
- 旧客户端得到明确升级错误；
- Web、桌面、移动和 CLI 均通过真实 MCP Apps E2E；
- 一个 MCP App 能在大乘 Host 和至少一个其他合规 Host 中运行；
- GitHub Actions 和真实 Cloudflare 证据完整。