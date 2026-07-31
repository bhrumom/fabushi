# 大乘可热安装本地 Web MCP Apps 任务

任务 ID：`mahayana-marketplace-cloudflare-20260730`  
目标版本：`goalVersion = 7`  
文档状态：等待产品审核，尚未合并到 `main`，不得启动实施 Action。

## 一句话目标

> 把大乘小程序统一为可签名下载、安装到本地、通过网页热更新、由 MCP Tool 驱动的标准 MCP Apps；移动端、桌面 WebView 和普通 Web/PWA 尽可能复用同一套本地网页包与 Web Runtime，不要求每个插件能力都预编译进主 App。

## 最高优先级设计

1. `LOCAL_WEB_MCP_RUNTIME.md`：移动端和 Web 端共用可下载本地网页包、Local Web MCP Runtime、热安装、热更新和聊天 Tool 调用。
2. `LOCAL_FIRST_MCP_APPS.md`：本地优先、桌面 stdio、独立运行和 Runtime Profiles。
3. `MCP_APPS_ONLY.md`：MCP Apps UI、AppBridge、sandbox、CSP、tool visibility 和旧协议删除。

其他文档与以上文件冲突时，以以上顺序为准。

## 核心结构

```text
签名 MCP App 包
├── ui/                 MCP Apps View
├── runtime/web/        本地 JavaScript/WASM Tool Runtime
├── tools.json
├── permissions
├── skills/workflows
└── provenance/signature
```

移动端安装后，从 App 私有目录通过安全本地 Origin 加载；普通 Web/PWA 从浏览器本地存储和 Service Worker 加载。同一 Tool 逻辑在不同网页宿主复用。

## 聊天与页面统一调用

聊天输入：

```text
用户指令 → Host 选择 MCP Tool → Local Web Runtime 执行 → UI 显示结果
```

页面按钮：

```text
MCP Apps View → AppBridge tools/call → Local Web Runtime
```

禁止依赖模拟点击网页按钮。

## 全球法布施

如果现有网页已能通过标准 Web API 完成发送，则全球法布施采用 `local-web`：

- 同一网页包安装到 iOS、Android、桌面和 Web；
- 本地 Worker 执行 `send/status/cancel/logs` Tool；
- 本地保存队列和状态；
- Cloudflare 只负责市场、签名包、更新和网页需要调用的可选远程 API；
- 更新网页 Runtime 不要求发布新的大乘主 App。

## 主 App 更新边界

HTML/CSS/JavaScript/WASM、Tool 流程、表单、规则、Skills 和普通 HTTPS 能力可以随插件更新。

新增相机、蓝牙、通讯录、短信、辅助功能、长期后台任务或其他受限原生能力时，仍可能需要主 App 更新或平台批准。

## 商店合规

热更新必须是受管理的 HTML5/JavaScript 小程序市场，而不是任意代码下载器：

- 完整市场索引、插件元数据和深链；
- 签名、来源、权限、隐私、内容和恶意代码审核；
- 用户逐插件安装与授权；
- 商店说明和审核账号完整；
- 不向下载的小程序任意暴露原生平台 API。

## 仍须删除

- 大乘自定义 iframe bridge；
- `mcp-2025-06-18` fallback；
- `Mcp-Session-Id`；
- 旧 GET/SSE/DELETE session；
- SDK v1 server；
- 运行旧插件的兼容路径。

## 队列配置

- revision：`2026-07-31.7`
- goalVersion：`7`
- 标题：`全面迁移大乘小程序至可热安装的本地 Web MCP Apps 运行架构`

## 审核状态

收到明确“审核通过”之前：

- 不合并到 `main`；
- 不启用自动合并；
- 不启动新的持续 Action；
- 不影响当前运行中的任务。
