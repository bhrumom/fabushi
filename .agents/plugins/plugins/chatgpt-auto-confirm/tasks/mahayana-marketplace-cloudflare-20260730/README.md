# 大乘 MCP Apps 小程序市场与可信发布任务

任务 ID：`mahayana-marketplace-cloudflare-20260730`  
目标版本：`goalVersion = 5`  
文档状态：等待产品审核，尚未合并到 `main`，不得启动实施 Action。

## 一句话目标

> 把全部大乘小程序、宿主、插件模板、市场准入和 Cloudflare 运行时一次性迁移到官方 MCP Apps 稳定规范与无状态 MCP SDK v2；生产环境不保留任何旧 MCP 运行通道。

市场和发布系统同时继续遵循：一个插件一个稳定身份和独立 Cloudflare 逻辑服务；一个版本一个不可变发布物；市场负责身份、审核和信任；CLI 直连插件服务下载并验证签名、哈希、权限、来源、撤销和防回退。

## 最高优先级决策

- MCP Apps 稳定规范：`2026-01-26`。
- 扩展标识：`io.modelcontextprotocol/ui`。
- UI：`ui://` + `text/html;profile=mcp-app`。
- Host：官方 AppBridge 或完全符合规范的实现。
- Cloudflare：`createMcpHandler` + SDK v2 server factory。
- Production：`legacy: "reject"`。
- 不保留旧客户端、旧服务器或旧 iframe bridge 的运行期回退。
- `ui/initialize` 属于新 MCP Apps View–Host 协议，必须实现；它不是旧 MCP transport session。

## 明确禁止

- `createLegacyMcpHandler`、`McpAgent`、`WorkerTransport`；
- SDK v1 server；
- `Mcp-Session-Id`、sticky session、transport session store；
- GET/DELETE MCP session 和长期 session SSE；
- `mcp-2025-06-18` fallback；
- 自定义 iframe ready/tool/result 消息方言；
- legacy route 或 production compatibility lane；
- 新 Host 继续运行未迁移的旧插件。

旧客户端只能收到 `MCP_APPS_HOST_UPGRADE_REQUIRED`，不能继续执行插件。

## 必读顺序

1. `MCP_APPS_ONLY.md`：最高优先级协议和硬切换约束。
2. `MCP_APPS_REFERENCES.md`：已核实的官方规范和 Cloudflare 文档。
3. `PRD.md`：产品目标、范围和成功标准。
4. `TECHNICAL_DESIGN.md`：目标架构、宿主、Worker、市场和安装设计。
5. `API_CONTRACT.md`：市场、发布、审核、下载、回滚和撤销 API。
6. `DATA_MODEL.md`：发布者、插件、版本、部署、权限、签名和审计数据。
7. `SECURITY_MODEL.md`：OIDC、签名、provenance、CSP、权限和更新安全。
8. `PUBLISHING_WORKFLOW.md`：托管发布和高级自托管流程。
9. `UI_UX.md`：MCP Apps Host、市场、安装和升级交互。
10. `MIGRATION_PLAN.md`：无运行期双栈的迁移与硬切换步骤。
11. `ACCEPTANCE.md`：全部强制验收和云端证据。
12. `REFERENCES.md`：市场和更新安全参考。

## 当前仓库缺口

当前实现仍包含：

- `mcp-2025-06-18`；
- 服务端 session 初始化与 `Mcp-Session-Id`；
- GET/SSE listener 和 DELETE session；
- 大乘自定义 iframe bridge；
- 旧 SDK/运行时语义；
- 尚未转换为标准 MCP Apps 的官方插件。

实施必须删除这些生产路径，而不是在旁边增加一条新路径。

## 硬切换原则

1. 在隔离环境完成共享 MCP Apps Host core；
2. 迁移所有官方插件和示例第三方插件；
3. 新模板和市场校验器只接受 MCP Apps；
4. 全平台和真实 Cloudflare 验收通过；
5. 一次性切换 production；
6. 删除旧路由、旧依赖、旧 bridge 和旧测试；
7. 旧客户端只显示升级要求。

允许保留旧插件静态分析与迁移工具，但不得保留运行旧插件的代码。

## 任务完成边界

只更新文档、只升级依赖、只增加 MCP Apps UI、只保留兼容层、只写 mock 或只做接口单测均不算完成。必须完成代码、数据库、市场、发布、Cloudflare、Web、桌面、移动、CLI、官方插件、第三方示例插件和真实云端验收。

## 文档更新规则

任务目标发生实质变化时同步更新：

- 本目录文档；
- `actions-inbox.json` prompt；
- `goalVersion`；
- 顶层 `revision`。

动态控制器只会在 Chat 轮次边界读取更新，不会中断正在运行的 Chat。
