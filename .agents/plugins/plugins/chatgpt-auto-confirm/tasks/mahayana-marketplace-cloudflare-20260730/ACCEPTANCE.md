# 验收标准：MCP Apps-only 大乘小程序市场

任务只有在所有“必须”项满足并提供真实云端证据后才能报告 `complete`。

## 1. MCP Apps 全量迁移

- [ ] 所有官方小程序均声明 `io.modelcontextprotocol/ui`。
- [ ] 所有官方小程序均至少提供一个 `ui://` resource。
- [ ] UI resource MIME 为 `text/html;profile=mcp-app`。
- [ ] Tool 通过 `_meta.ui.resourceUri` 关联 UI。
- [ ] View 使用官方 MCP Apps SDK。
- [ ] Host 使用 AppBridge 或规范一致实现。
- [ ] Web、桌面、移动和 CLI 共用同一 Host core 或同一契约实现。
- [ ] 自定义 iframe bridge 已删除。
- [ ] 新插件模板只生成 MCP Apps。
- [ ] 市场无法发布非 MCP Apps 新版本。

## 2. 无状态 Cloudflare runtime

- [ ] 每个插件使用 `agents/mcp/server` 的 `createMcpHandler`。
- [ ] 使用 `@modelcontextprotocol/server` SDK v2 factory。
- [ ] Production 明确设置 `legacy: "reject"`。
- [ ] 不使用 `createLegacyMcpHandler`。
- [ ] 不使用 `McpAgent`。
- [ ] 不使用 `WorkerTransport` 或 SDK v1 server。
- [ ] 不生成或接受 `Mcp-Session-Id`。
- [ ] 不依赖 sticky session、transport store 或长期 session SSE。
- [ ] HTTP GET/DELETE 不用于管理 MCP session。
- [ ] 任意两个边缘实例可以处理同一业务流程的相邻请求。
- [ ] 业务连续性使用显式认证句柄。

## 3. 旧路径彻底停止

- [ ] 生产代码不存在旧 MCP runtime 分支。
- [ ] 生产依赖树不存在 SDK v1 server 用途。
- [ ] 不存在 legacy production route。
- [ ] 旧客户端收到 `MCP_APPS_HOST_UPGRADE_REQUIRED`。
- [ ] 旧客户端不能创建会话或调用 Tool。
- [ ] 旧插件标记 `migration_required`。
- [ ] 新 Host 不允许“兼容模式运行”。
- [ ] 允许存在的旧关键词仅限负向测试、迁移检测和升级文案。

## 4. MCP Apps Host 安全

- [ ] iframe 使用 sandbox。
- [ ] Host 根据 resource 声明生成并强制 CSP。
- [ ] 未声明 connect/img/media/font 域名被拒绝。
- [ ] UI 不能自行顶层导航或绕过 Host 调用 Tool。
- [ ] `ui/open-link` 经过 Host policy。
- [ ] app-only Tool 不进入模型工具列表。
- [ ] model-only Tool 不能由 View 调用。
- [ ] 跨插件 Tool 和 resource 调用被拒绝。
- [ ] teardown 后 bridge、事件和权限被释放。
- [ ] CSP、工具调用和权限决策有审计。

## 5. MCP Apps 功能

- [ ] `ui/initialize` 与 initialized 通知正常。
- [ ] host context 提供 theme、locale、timezone、platform 和 viewport。
- [ ] inline 模式正常。
- [ ] 至少一个插件验证 fullscreen。
- [ ] Tool input/result 能通过标准通知传给 View。
- [ ] View 能通过 Host 调用允许的 app-visible Tool。
- [ ] Tool 同时返回有意义的 `content` 和 `structuredContent`。
- [ ] 不支持 UI 呈现的调用方仍能消费同一新 MCP Tool 的文本/结构化结果；这不得通过旧协议实现。

## 6. 插件身份与隔离

- [ ] 一个发布者可以拥有多个插件。
- [ ] plugin ID 使用稳定命名空间且不可被其他账号占用。
- [ ] 同一 `pluginId + version` 永远不可覆盖。
- [ ] 每插件拥有独立 Cloudflare 服务边界。
- [ ] 插件之间不共享写 Secret、数据库、部署凭证或写权限。
- [ ] 不为每版本永久创建新 Worker 项目。

## 7. 不可变发布物

- [ ] 示例插件发布 `1.0.0` 和 `1.1.0`。
- [ ] 包路径包含版本和 SHA。
- [ ] URL 中 SHA 与实际文件一致。
- [ ] 已发布 URL 内容不可覆盖。
- [ ] `latest` 仅作为指针。
- [ ] production 可以提升和回滚到已有版本。
- [ ] 插件包和静态资源未使用 R2。

## 8. 托管发布与 OIDC

- [ ] 普通发布者不输入 Cloudflare Token。
- [ ] GitHub Actions 使用 OIDC 交换短期发布凭证。
- [ ] 凭证绑定发布者、plugin ID、仓库、workflow、commit、stage 和有效期。
- [ ] 错误 claims、过期 token 和 nonce 重放被拒绝。
- [ ] 正式发布不依赖长期测试账号或长期市场写 Token。
- [ ] provenance 记录仓库、commit、workflow、run、构建者、构件 SHA 和部署地址。

## 9. 市场 MCP Apps 准入

- [ ] release 元数据包含 runtime kind、SDK major、transport、legacy、extension、ui resources、MIME、CSP 和 visibility。
- [ ] 市场实际探测 production endpoint 拒绝 legacy。
- [ ] 无 `ui://` resource 被拒绝。
- [ ] MIME 错误被拒绝。
- [ ] SDK v1/legacy handler 被拒绝。
- [ ] 自定义 bridge 被拒绝。
- [ ] CSP 过宽或与实际访问不一致被拒绝。
- [ ] 未迁移版本不能进入 `community`、`verified`、`official` 或 production。

## 10. 签名、权限和安装

- [ ] 市场签署规范化版本元数据。
- [ ] CLI 验证签名、过期、撤销和 anti-rollback。
- [ ] CLI 验证 Cloudflare 域名、不可变路径、大小、SHA 和 provenance。
- [ ] 包内 MCP Apps manifest 与市场元数据一致。
- [ ] 首次安装展示权限、CSP 域名和 tool visibility。
- [ ] `1.1.0` 引入受控权限变化。
- [ ] 权限扩大不能静默升级。
- [ ] 安全解包和原子安装通过。
- [ ] 失败不破坏当前版本。

## 11. 真实 MCP App E2E

必须创建真实第三方插件：

```text
io.mahayana.test.hello
```

必须完成：

1. `plugin init` 生成 MCP Apps-only 模板；
2. 本地和 Actions conformance；
3. stage 发布；
4. Cloudflare preview；
5. 验证 `legacy:"reject"`；
6. 正式 release；
7. 审核批准；
8. 市场搜索与详情；
9. CLI 直连下载和完整校验；
10. 安装并在大乘 Host 渲染；
11. app/model visibility；
12. CSP 允许和拒绝路径；
13. 多轮输入或长任务；
14. 跨边缘实例调用；
15. 在至少一个其他合规 MCP Apps Host 中运行；
16. 发布 `1.1.0`；
17. 权限差异确认；
18. 升级、回滚和撤销；
19. 篡改包/元数据拒绝；
20. 旧客户端升级错误。

## 12. 所有官方插件

- [ ] 官方插件清单中每个插件都有迁移记录。
- [ ] 官方插件迁移率 100%。
- [ ] 每个官方插件至少完成 Tool、resource、AppBridge 和 sandbox smoke test。
- [ ] 不允许以“后续再迁移”跳过任何 production 官方插件。

## 13. 删除验证

CI 必须检查生产代码不存在可执行的：

```text
createLegacyMcpHandler
McpAgent
WorkerTransport
Mcp-Session-Id
mcp-2025-06-18
legacy route
custom iframe bridge
```

负向测试和文档可出现这些词，但检查必须证明没有运行分支和生产 import。

## 14. GitHub Actions 与云端证据

- [ ] 单元、契约、浏览器、安全和迁移测试全部通过。
- [ ] Actions 完成真实 Cloudflare stage 与 production。
- [ ] 至少两个地理/隔离请求证明无 session affinity。
- [ ] 日志保留 plugin ID、version、SHA、deployment、run ID 和 trace。
- [ ] AppBridge、CSP、visibility、legacy rejection 有可复核证据。
- [ ] 外部合规 Host 运行证据可复核。

## 15. 最终报告

`verification` 必须列出：

- PR、合并提交和 Actions runs；
- MCP Apps 规范/SDK 精确版本；
- 全部官方插件迁移清单；
- Cloudflare project/version/production；
- `legacy:"reject"` 证据；
- 旧依赖和路由删除证据；
- 示例插件两个版本；
- ui resources、CSP、visibility 和 AppBridge；
- 大乘 Host 与外部 Host 运行证据；
- OIDC/provenance/signature；
- 安装、升级、回滚、撤销与篡改拒绝；
- 无 R2、无永久市场代理、无长期发布 Token。

缺少任一强制项时状态必须为 `incomplete`。
