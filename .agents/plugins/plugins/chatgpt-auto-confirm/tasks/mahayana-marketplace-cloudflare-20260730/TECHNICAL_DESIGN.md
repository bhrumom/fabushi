# 技术设计：MCP Apps-only 大乘小程序市场

## 1. 目标架构

```text
                         大乘市场控制平面
┌───────────────────────────────────────────────────────────┐
│ Identity / Namespace / Review / Trust / Signing / Audit  │
│ OIDC / Provenance / Revocation / Rollback / Permission   │
└──────────────────────────┬────────────────────────────────┘
                           │ signed immutable metadata
                           ▼
┌───────────────────────────────────────────────────────────┐
│ 每插件独立 Cloudflare Worker                              │
│ createMcpHandler + SDK v2 + legacy:"reject"              │
│ Tools / Resources / ui:// MCP Apps / explicit state      │
│ immutable package + homepage + static assets              │
└───────────────┬───────────────────────────────┬───────────┘
                │ MCP Apps protocol             │ direct download
                ▼                               ▼
┌──────────────────────────────┐   ┌────────────────────────┐
│ 大乘共享 MCP Apps Host core  │   │ 大乘 CLI installer     │
│ AppBridge / sandbox / CSP    │   │ signature/hash/source  │
│ Web/Desktop/Mobile/CLI       │   │ permission/atomic      │
└──────────────────────────────┘   └────────────────────────┘
```

## 2. 运行时唯一实现

### 服务端

```ts
import { createMcpHandler } from "agents/mcp/server";
import { McpServer } from "@modelcontextprotocol/server";

const handler = createMcpHandler(createServer, {
  route: "/mcp",
  legacy: "reject",
  responseMode: "json",
  allowedHostnames: ["<plugin-host>"],
  allowedOriginHostnames: ["<approved-host>"],
});
```

要求：

- 使用 SDK v2 factory；
- 每个请求创建独立 server；
- 不使用 global mutable server；
- 不使用 SDK v1 transport；
- 不保存 MCP session；
- 不提供 legacy 路由；
- OAuth/AuthInfo、Host、Origin、scope 和插件身份在 handler 前或 handler context 中验证；
- 业务状态使用显式 ID 和持久层。

### 客户端/宿主

Web、桌面、移动和 CLI 共用同一 Host core：

- MCP Apps extension capability；
- AppBridge；
- sandboxed iframe；
- declarative CSP；
- host context；
- tool visibility；
- standard JSON-RPC over postMessage；
- permission broker；
- audit logger；
- versioned UI resource cache。

旧 session 客户端实现必须删除。

## 3. MCP Apps 资源模型

Tool：

```json
{
  "name": "show_dashboard",
  "inputSchema": {"type":"object"},
  "_meta": {
    "ui": {
      "resourceUri": "ui://io.mahayana.publisher.plugin/dashboard"
    }
  }
}
```

Resource：

```json
{
  "uri": "ui://io.mahayana.publisher.plugin/dashboard",
  "mimeType": "text/html;profile=mcp-app",
  "text": "<!doctype html>..."
}
```

约束：

- UI resource 必须可枚举、可审计、可缓存；
- resource URI 绑定插件 ID、版本和内容哈希；
- CSP 只允许声明的 connect/img/media/font 域名；
- 默认 CSP 保持最小权限；
- app-only tools 只能由同一 server 的 App 调用；
- model-only tools 不向 App 暴露；
- 所有工具返回文本与结构化数据，UI 不承载唯一业务结果。

## 4. Host 安全模型

Host 必须：

- iframe sandbox 默认禁用顶层导航、弹窗、下载和任意 origin；
- 根据资源声明构造 CSP；
- 不允许 UI 自行绕过 Host 调用工具；
- 校验 View 来源、resource identity 和 plugin version；
- 将工具调用映射到安装权限与运行时权限；
- 对 destructive/open-world/write 操作重新确认；
- 审计 `ui/open-link`、tools/call、权限拒绝和 CSP 违规；
- teardown 后撤销 bridge 和事件监听；
- 防止跨插件 tool call 和 resource access。

## 5. 插件发布物

```text
/
/mcp
/mahayana/latest/plugin.json
/mahayana/releases/<version>/<sha>/plugin.json
/mahayana/releases/<version>/<sha>/plugin.tar.gz
/mahayana/releases/<version>/<sha>/provenance.json
```

`plugin.json` 必须包含：

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
    "resources": ["ui://..."],
    "mimeTypes": ["text/html;profile=mcp-app"]
  }
}
```

市场必须从 production endpoint 实际探测 legacy 请求被拒绝，而不是只信任声明。

## 6. 市场数据与准入

新增或确认字段：

- `runtime_kind`；
- `mcp_sdk_major`；
- `transport_mode`；
- `legacy_allowed`；
- `mcp_apps_extension`；
- `ui_resources_json`；
- `ui_mime_types_json`；
- `csp_json`；
- `tool_visibility_json`；
- `host_min_version`；
- `migration_state`。

发布校验流程：

1. 验证 plugin ID/version 所有权与不可变性；
2. 验证 OIDC/provenance；
3. 验证 package hash/size；
4. 验证 MCP Apps manifest；
5. 调用 `/mcp` 执行 SDK v2 合规测试；
6. 验证 legacy 请求被拒绝；
7. 读取 `ui://` resources；
8. 验证 MIME、CSP、tool visibility 和 structured result；
9. 运行 sandbox/browser tests；
10. 签署 release metadata；
11. 进入审核。

## 7. 业务状态

允许：

- D1：关系数据、任务、审计；
- KV：可缓存元数据；
- Durable Object：确实需要强一致协调的业务对象；
- Queue/Workflow：长时间构建、扫描、部署；
- 显式 `taskId`、`draftId`、`workspaceId`、`deploymentId`。

禁止：

- 用 Durable Object 模拟 MCP transport session；
- 用 cookie/session ID 隐藏业务连续性；
- 依赖同一 Worker isolate；
- 依赖 sticky routing。

## 8. 硬切换实现顺序

1. 建共享 Host core；
2. 编写旧 bridge 到 MCP Apps 的代码迁移工具；
3. 迁移所有官方插件；
4. 迁移 Flutter/Web/Desktop/CLI Host；
5. 将新模板改为 MCP Apps-only；
6. 将市场准入改为 MCP Apps-only；
7. 在 preview 上验证 `legacy:"reject"`；
8. 全平台 E2E；
9. 一次性切换 production；
10. 删除旧 SDK、旧 session、旧 bridge、旧 route 和旧测试。

不允许在 production 同时提供新旧 endpoint。

## 9. 旧客户端处理

旧客户端连接时返回明确错误：

- 错误码：`MCP_APPS_HOST_UPGRADE_REQUIRED`；
- 最低 Host 版本；
- 升级链接；
- 不创建 session；
- 不执行 Tool；
- 不返回旧 UI。

## 10. 安装和更新安全

CLI 按顺序验证：

1. 市场根信任与签名；
2. metadata version/expiry/revocation；
3. plugin ID/version/anti-rollback；
4. Cloudflare approved hostname；
5. immutable URL；
6. size/SHA/content type；
7. provenance；
8. MCP Apps manifest；
9. permissions/CSP/tool visibility；
10. 安全解包和原子安装。

旧插件包不得因已安装而被新 Host 继续执行；升级后标记 `migration_required` 并阻止启动。

## 11. 可观测性

必须记录：

- plugin ID/version；
- tool/resource URI；
- Host version；
- MCP Apps capability；
- CSP policy/result；
- permission decision；
- Cloudflare request/trace；
- release/provenance/action run；
- legacy rejection count；
- upgrade-required count。

不得记录 access token、Secret 或敏感表单内容。

## 12. 删除完成标准

仓库生产代码搜索不得再出现可执行的：

```text
createLegacyMcpHandler
McpAgent
WorkerTransport
Mcp-Session-Id
mcp-2025-06-18
legacy MCP route
custom iframe bridge
```

允许出现在迁移说明、负向测试和升级错误文案中，但不能存在可运行分支。
