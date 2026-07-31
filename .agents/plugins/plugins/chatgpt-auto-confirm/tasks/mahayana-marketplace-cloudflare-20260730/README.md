# 大乘本地优先 MCP Apps 小程序市场与可信发布任务

任务 ID：`mahayana-marketplace-cloudflare-20260730`  
目标版本：`goalVersion = 6`  
文档状态：等待产品审核，尚未合并到 `main`，不得启动实施 Action。

## 一句话目标

> 把大乘小程序统一为可下载安装到本地的标准 MCP Apps：桌面/CLI 默认本地 stdio 执行并可独立窗口运行，移动端由内置 Rust Mahayana Core 提供本地能力，普通桌面 Web 通过安全 Local Agent 调用本机 Runtime；Cloudflare 负责市场、签名包、更新和可选远程能力，不强制承载每个插件的业务执行。

## 两个最高优先级文档

1. `LOCAL_FIRST_MCP_APPS.md`：本地安装、Runtime Profiles、桌面独立运行、移动内嵌 Core、Web Local Agent 和两个关键插件的运行要求。
2. `MCP_APPS_ONLY.md`：MCP Apps UI、Host、安全桥接、旧协议删除和硬切换要求。

其他文档与这两份文件冲突时，以它们为准。

## 核心架构

```text
Cloudflare/Marketplace
  → signed immutable package
  → install locally

Installed MCP App
  ├── ui:// View
  ├── permissions
  └── runtime profiles
        ├── desktop/CLI stdio
        ├── mobile embedded Mahayana Core
        ├── desktop Web Local Agent
        └── optional remote-edge
```

MCP Apps 是 UI 与 Host 通信标准，不等于云端 Runtime。

## Runtime 类型

市场支持：

- `local-only`；
- `local-first`；
- `hybrid`；
- `remote-only`。

Host Resolver 优先级：

```text
本地 stdio
→ 移动端内嵌 Core
→ 已配对 Local Agent
→ 插件明确允许的远程 Edge
```

本地 Profile 可用时不得静默切换到云端，用户必须看到执行位置。

## 全球法布施

- 桌面/CLI：本机 stdio Runtime，发送队列、账号、日志和数据在本机；
- 桌面：可通过 `mahayana plugin run global-dharma` 独立窗口运行；
- 移动端：本地 WebView MCP App UI 调用 App 内置 Rust Core 的发送、队列和数据库能力；
- 桌面 Web：通过 Mahayana Local Agent；
- Cloudflare：市场、签名包、更新和可选同步，不替代本地发送执行。

## ChatGPT 自动确认

- 类型：`desktop-local-only`；
- 本机 Runtime 操作本机 ChatGPT renderer/辅助功能/后台页面；
- MCP App UI 管理启动、停止、任务和日志；
- 移动/Web 只能控制已配对桌面并明确显示执行设备；
- 不允许宣称在手机或云端直接完成桌面自动确认。

## MCP Apps 基线

- 稳定规范：`2026-01-26`；
- extension：`io.modelcontextprotocol/ui`；
- UI：`ui://` + `text/html;profile=mcp-app`；
- Tool：`_meta.ui.resourceUri`；
- Host：AppBridge、sandbox、CSP、host context、display modes、tool visibility；
- `ui/initialize` 是新 View–Host 握手，不是旧 MCP Session。

## 明确删除

- `Mcp-Session-Id`；
- 旧 GET/SSE/DELETE MCP Session；
- SDK v1 Server；
- `createLegacyMcpHandler`、`McpAgent`、`WorkerTransport`；
- `mcp-2025-06-18` fallback；
- 大乘自定义 iframe bridge；
- 运行旧插件的兼容路径。

本地 stdio 是标准 MCP transport，不属于旧兼容层。

## 市场和可信发布

继续要求：

- 稳定 plugin ID 和命名空间；
- 版本+SHA 不可变安装包；
- GitHub Actions OIDC 短期发布凭证；
- provenance 和市场签名；
- Runtime Profiles、平台、权限、CSP 和执行位置；
- 审核、撤销、封禁、升级和回滚；
- CLI 直连下载、安全解包和原子安装；
- 禁止 R2；
- 市场不永久代理安装包字节。

local-only 插件不得因没有远程 MCP endpoint 而发布失败。只有声明 remote-edge Profile 时才要求 Cloudflare SDK v2、无状态 Runtime 和 `legacy: "reject"`。

## 必读顺序

1. `LOCAL_FIRST_MCP_APPS.md`
2. `MCP_APPS_ONLY.md`
3. `MCP_APPS_REFERENCES.md`
4. `PRD.md`
5. `TECHNICAL_DESIGN.md`
6. `API_CONTRACT.md`
7. `DATA_MODEL.md`
8. `SECURITY_MODEL.md`
9. `PUBLISHING_WORKFLOW.md`
10. `UI_UX.md`
11. `MIGRATION_PLAN.md`
12. `ACCEPTANCE.md`
13. `REFERENCES.md`

## 硬切换原则

1. 完成共享 MCP Apps Host Core 和 Runtime Resolver；
2. 完成桌面 stdio Supervisor、独立 App Shell、移动 Core Provider 和 Web Local Agent；
3. 迁移全球法布施、ChatGPT 自动确认和全部官方插件；
4. 市场与模板只接受新 MCP Apps Runtime Profiles；
5. 全平台真实验收；
6. 一次性切换 production；
7. 删除旧路由、旧依赖、旧 bridge 和旧测试。

不允许运行旧协议双栈，但允许同一个新 MCP App 声明多个新 Runtime Profile。

## 审核状态

收到明确“审核通过”之前：

- 不合并到 `main`；
- 不启用自动合并；
- 不启动新的持续 Action；
- 不影响当前队列任务。
