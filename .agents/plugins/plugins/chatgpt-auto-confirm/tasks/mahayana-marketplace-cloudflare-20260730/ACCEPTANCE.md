# 验收标准：本地优先 MCP Apps 大乘小程序市场

任务只有在全部强制项满足并提供真实设备、安装包、GitHub Actions 和市场证据后才能报告 `complete`。

## 1. MCP Apps 全量迁移

- [ ] 所有官方小程序声明 `io.modelcontextprotocol/ui`。
- [ ] 每个插件至少提供一个 `ui://` resource。
- [ ] UI resource MIME 为 `text/html;profile=mcp-app`。
- [ ] Tool 通过 `_meta.ui.resourceUri` 关联 UI。
- [ ] View 使用官方 MCP Apps SDK。
- [ ] Host 使用 AppBridge 或规范一致实现。
- [ ] Web、桌面、移动和 CLI 使用共享 Host Core/统一契约。
- [ ] 自定义 iframe bridge 已删除。
- [ ] 市场不接受非 MCP Apps 新版本。

## 2. 本地可安装包

- [ ] 小程序从市场下载到本地版本目录。
- [ ] 包包含 manifest、Runtime Profiles、permissions、UI resources、provenance 和签名信息。
- [ ] CLI 验证市场签名、版本、撤销、大小、SHA、来源和权限。
- [ ] 解包拒绝路径穿越、链接逃逸、设备文件和压缩炸弹。
- [ ] 安装使用 staging 和原子 current 切换。
- [ ] 插件数据目录与版本目录分离。
- [ ] 升级失败不破坏当前版本和本地数据。
- [ ] 卸载停止后台进程并清理授权。

## 3. Runtime Profiles 与 Resolver

- [ ] 支持 `local-only`、`local-first`、`hybrid`、`remote-only`。
- [ ] 支持 desktop/CLI stdio Profile。
- [ ] 支持 mobile embedded Mahayana Core Profile。
- [ ] 支持 Web Local Agent Profile。
- [ ] 仅有远程能力的插件可声明 remote-edge Profile。
- [ ] Resolver 按本地 stdio、移动内嵌、Local Agent、远程顺序选择。
- [ ] local-only 不允许 remote fallback。
- [ ] 本地可用时不静默切换云端。
- [ ] UI 明确显示本机、移动内核、配对设备或云端执行。
- [ ] Profile 选择与切换写入审计。

## 4. 桌面 stdio 与独立运行

- [ ] Host 从已验证版本目录启动本地 Runtime。
- [ ] command、args 和二进制哈希均在签名 manifest 中。
- [ ] stdout 仅包含 MCP JSON-RPC，stderr 用于脱敏日志。
- [ ] 子进程使用最小环境变量和权限。
- [ ] Tool、resource 和 UI 均来自本地 Server/包。
- [ ] `mahayana plugin run <id>` 可启动独立 MCP Apps Shell。
- [ ] 独立窗口与聊天内嵌共用 UI、Tool、权限和数据。
- [ ] 崩溃、退出、升级、撤销和卸载会正确清理进程。

## 5. 移动端本地运行

- [ ] iOS/Android 插件安装 UI、manifest、schema、工作流、Skills 和静态资源。
- [ ] 移动端不下载执行任意第三方原生二进制。
- [ ] Rust Mahayana Core/Flutter FFI 提供已批准本地 capabilities。
- [ ] 插件通过统一 MCP Tool 契约调用 `share.send`、队列、数据库等能力。
- [ ] 每插件数据、Secret 和权限隔离。
- [ ] 新系统级 capability 缺失时明确要求升级大乘 App，不能静默下载代码。
- [ ] 本地 WebView 从已安装 `ui://` resource 渲染。

## 6. Web Local Agent

- [ ] 普通桌面 Web 通过 Local Agent 或 browser native messaging 调用本机 Runtime。
- [ ] Agent 仅监听 loopback。
- [ ] 配对需要本机用户确认。
- [ ] 每个 origin 独立授权，无通配 CORS。
- [ ] 使用短期 challenge/token 和设备身份。
- [ ] 防 DNS rebinding、CSRF、端口扫描滥用和跨插件调用。
- [ ] Agent 缺失时显示安装/在大乘 App 打开的明确指引。
- [ ] 移动浏览器深链到大乘 App，不伪装拥有本地 CLI。

## 7. 全球法布施真实验收

### 桌面/CLI

- [ ] 从市场安装真实签名包。
- [ ] 使用本地 stdio Runtime。
- [ ] 本地 `ui://` 页面正常渲染。
- [ ] 可通过独立窗口运行。
- [ ] 发送队列、账号状态、日志和数据准备在本机。
- [ ] 真实执行一次本机发送能力。
- [ ] 未授权发送被拒绝。
- [ ] 断开 Cloudflare 后仍可打开 UI、查看本地配置和队列。

### 移动端

- [ ] 同一 Tool 契约由内置 Mahayana Core 实现。
- [ ] 本地 WebView UI 能创建、查看和执行发送任务。
- [ ] 敏感本地数据无需上传到插件 Runtime 服务。
- [ ] 权限拒绝、网络中断和后台恢复有真实测试。

### Web

- [ ] 桌面浏览器经 Local Agent 执行本机能力。
- [ ] 未安装/未配对 Agent 时不会调用云端冒充本地发送。

## 8. ChatGPT 自动确认真实验收

- [ ] 插件标记为 `desktop-local-only`。
- [ ] 从市场安装并启动本地后台 Runtime。
- [ ] MCP App UI 控制启动、停止、任务、状态和日志。
- [ ] 自动确认真实作用于本机 ChatGPT 实例。
- [ ] 桌面辅助功能、浏览器自动化和后台进程权限逐项确认。
- [ ] 移动/Web 不直接运行桌面专属能力。
- [ ] 移动/Web 可控制已配对桌面时显示目标设备。
- [ ] 无配对桌面时明确不可执行。
- [ ] 卸载或撤销会停止自动确认进程。

## 9. MCP Apps Host 安全

- [ ] iframe/WebView 使用 sandbox。
- [ ] Host 根据 resource 声明强制 CSP。
- [ ] 未声明 connect/img/media/font 域名被拒绝。
- [ ] UI 不能绕过 Host 直接执行本地命令。
- [ ] `ui/open-link` 经过 Host policy。
- [ ] app-only Tool 不进入模型列表。
- [ ] model-only Tool 不能由 View 调用。
- [ ] 跨插件 Tool/resource 调用被拒绝。
- [ ] teardown 后 bridge、事件和临时权限释放。
- [ ] Tool 调用、执行位置、权限和 CSP 结果可审计。

## 10. 旧路径彻底停止

- [ ] 生产代码不存在旧 MCP runtime 分支。
- [ ] 不使用 `Mcp-Session-Id`。
- [ ] 不使用旧 GET/SSE/DELETE session。
- [ ] 不使用 SDK v1 server、`McpAgent`、`WorkerTransport` 或 `createLegacyMcpHandler`。
- [ ] 不存在 legacy production route。
- [ ] 自定义 iframe message schema 已删除。
- [ ] 旧客户端收到 `MCP_APPS_HOST_UPGRADE_REQUIRED`。
- [ ] 本地 stdio 被验证为新标准 Runtime，不被错误删除。

## 11. 可选远程 Edge Profile

存在 remote-edge Profile 时才要求：

- [ ] 使用 `createMcpHandler` 和 SDK v2 factory。
- [ ] Production 设置 `legacy: "reject"`。
- [ ] 不依赖 transport session、sticky routing 或长期 session SSE。
- [ ] 任意边缘实例可处理相邻请求。
- [ ] 本地专属 Tool 不被远程 Profile 冒充。

local-only/local-first 插件不得因没有远程 MCP endpoint 而发布失败。

## 12. 市场与可信发布

- [ ] 一个发布者可拥有多个稳定 plugin ID。
- [ ] 同一 `pluginId + version` 永远不可覆盖。
- [ ] 包使用版本+SHA 不可变 URL。
- [ ] GitHub Actions OIDC 交换短期发布凭证。
- [ ] provenance 绑定仓库、commit、workflow、run 和构件 SHA。
- [ ] 市场签署 Runtime Profiles、平台、权限、CSP 和安全状态。
- [ ] 支持 private/unlisted/community/verified/official/blocked/migration_required。
- [ ] 权限扩大必须重新确认。
- [ ] 支持撤销、封禁、升级和回滚。
- [ ] 不使用 R2 分发包或静态资源。
- [ ] 市场不永久代理安装包字节。

## 13. 第三方 local-first MCP App

至少创建一个真实第三方插件并发布 `1.0.0` 与 `1.1.0`：

1. 新模板生成 MCP Apps 与多个 Runtime Profiles；
2. Actions 构建签名安装包；
3. 市场 stage、审核和 release；
4. 桌面 stdio 安装运行；
5. 独立窗口运行；
6. 移动 embedded capability 运行；
7. Web Local Agent 运行；
8. 权限差异确认；
9. 升级、回滚、撤销；
10. 篡改包和元数据拒绝；
11. 本地可用时不走远程；
12. Cloudflare 市场中断时基础本地运行仍可用。

## 14. 所有官方插件

- [ ] 每个官方插件声明正确 Runtime kind/Profile。
- [ ] 官方插件迁移率 100%。
- [ ] 本地能力插件有真实本地 E2E。
- [ ] remote-only 插件有真实无状态远程 E2E。
- [ ] 不允许把所有插件简单改成远程 Worker 规避本地需求。

## 15. 最终报告

`verification` 必须列出：

- PR、合并提交和 Actions runs；
- MCP Apps/SDK 精确版本；
- 安装包 URL、SHA、签名和 provenance；
- Runtime Profile schema 与 Resolver 结果；
- 全球法布施桌面、移动和 Web Local Agent 证据；
- ChatGPT 自动确认桌面本机与配对设备证据；
- 独立 App Shell 证据；
- 权限、CSP、隔离和进程清理证据；
- 安装、升级、回滚、撤销和离线基础启动；
- 旧 Session/bridge 删除证据；
- 无 R2、无永久代理、无长期发布 Token。

缺少任一强制项时状态必须为 `incomplete`。