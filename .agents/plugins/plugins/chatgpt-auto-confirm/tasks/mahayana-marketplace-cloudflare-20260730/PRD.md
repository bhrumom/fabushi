# PRD：大乘本地优先 MCP Apps 小程序市场与可信发布

## 1. 产品目标

大乘小程序统一为可安装的官方 MCP Apps：

```text
signed installable package
+ MCP Apps ui:// resources
+ runtime profiles
+ shared Mahayana Host Core
+ local-first execution
+ optional stateless edge runtime
```

MCP Apps 统一 UI、Tool、resource 和 Host 通信；它不要求业务逻辑运行在云端。全球法布施、ChatGPT 自动确认等依赖本机数据、桌面应用或系统能力的小程序必须本地执行。

## 2. 核心原则

- 小程序可以从市场下载安装到本地；
- 已安装小程序在桌面端可以独立窗口运行；
- 桌面/CLI 优先使用本地 stdio MCP Server；
- 移动端使用 App 内置 Rust Mahayana Core 提供本地能力；
- 大乘 App 内的 WebView 加载本地 MCP App UI；
- 普通桌面浏览器通过 Mahayana Local Agent 调用本机 Runtime；
- local-only 插件不需要远程 MCP endpoint；
- Cloudflare 负责市场、签名包、下载更新和可选远程 Runtime；
- 本地 Profile 可用时不得静默转到云端；
- 用户始终能看到执行位置；
- 不保留旧 MCP Session 协议和自定义 iframe bridge。

## 3. 小程序类型

市场支持：

```text
local-only   只在本机/设备执行
local-first  默认本地，部分能力可远程
hybrid       本地和远程能力都属于正式产品功能
remote-only  无本地执行需求
```

不同类型仍使用同一 MCP Apps UI 契约和同一签名发布体系。

## 4. Runtime Profiles

每个版本声明平台绑定，例如：

- `desktop-stdio`：macOS/Windows/Linux/CLI；
- `mobile-embedded`：iOS/Android，调用 Mahayana Core capabilities；
- `web-local-agent`：桌面浏览器连接本地代理；
- `remote-edge`：可选 Cloudflare SDK v2 无状态 Runtime。

Host Runtime Resolver 按本地 stdio、移动嵌入式、Local Agent、可选远程的顺序选择。

## 5. 桌面独立运行

安装后用户可以：

```bash
mahayana plugin run global-dharma
```

系统启动：

```text
Local Runtime Supervisor
→ local MCP stdio server
→ MCP Apps Host Window
→ local ui:// View
```

独立窗口与聊天内嵌模式必须共用同一 UI、Tool、权限、数据目录和审计。

## 6. 移动端产品模型

移动端插件包下载 UI、manifest、Tool schema、工作流、Skills 和静态资源；不下载执行任意第三方原生二进制。

本地系统能力由大乘 App 内置 Core 提供，例如：

- `share.send`；
- `local.queue`；
- `local.database`；
- 通知；
- 账号和会话；
- 已批准网络访问；
- 平台分享入口。

新插件需要新的系统级能力时，先通过大乘 App 更新增加 capability，再由插件声明使用。

## 7. Web 产品模型

### App 内 WebView

`ui://` 资源从本地安装目录加载，Tool 通过 AppBridge 交给本机 Mahayana Core，属于完整本地运行。

### 普通浏览器

桌面 Web 必须安装 Mahayana Local Agent 或浏览器扩展，使用安全 loopback/native messaging 连接本机 Runtime。手机浏览器需要深链打开大乘 App。

没有本地代理时不能假装本地发送、文件或桌面自动化能力可用。

## 8. 全球法布施

- 桌面/CLI：随包 Runtime 在本机处理发送队列、账号状态、日志和数据；
- 桌面独立窗口：使用本地 MCP Apps Shell；
- 移动端：本地 WebView UI 调用内置 Rust Core 的发送能力；
- 桌面 Web：通过 Local Agent；
- Cloudflare：市场、签名包、更新、可选同步，不承载必须本地执行的数据发送。

## 9. ChatGPT 自动确认

该插件是 `desktop-local-only`：

- 本机 Runtime 操作本机 ChatGPT renderer/辅助功能/后台页面；
- MCP App UI 管理启动、停止、任务、日志和授权；
- 移动/Web 只能查看或控制已配对桌面；
- 执行位置必须明确显示为目标桌面设备；
- 不允许宣称在手机或云端直接完成桌面自动确认。

## 10. MCP Apps 契约

所有版本必须：

- `io.modelcontextprotocol/ui`；
- `ui://` resource；
- `text/html;profile=mcp-app`；
- `_meta.ui.resourceUri`；
- AppBridge；
- sandbox 和最小 CSP；
- model/app Tool visibility；
- 有意义的 `content` 和 `structuredContent`；
- 声明 Runtime Profiles、权限和平台支持。

## 11. 市场与发布

市场仍必须实现：

- 稳定插件身份和命名空间；
- 不可变版本+SHA 安装包 URL；
- GitHub Actions OIDC 短期发布凭证；
- provenance 和市场签名；
- 权限、CSP、Runtime Profile、平台支持；
- 审核、撤销、封禁、升级和回滚；
- CLI 直连下载、安全解包和原子安装；
- 禁止 R2；
- 不永久代理安装包字节。

对于 local-only/local-first 插件，市场验证本地 stdio、移动 Capability Contract 和 Local Agent 安全；只有存在 remote-edge Profile 时才要求 Cloudflare MCP Runtime conformance。

## 12. 权限

至少支持：

- 本地文件和数据库；
- 后台进程；
- 桌面辅助功能；
- 浏览器自动化；
- 发送能力；
- 网络域名；
- 命名 Secret；
- 通知；
- 配对设备控制。

默认拒绝，安装时展示，高风险能力首次使用再次确认，权限扩大必须重新确认。

## 13. 硬切换

1. 完成共享 MCP Apps Host Core 和 Runtime Resolver；
2. 完成本地安装/Supervisor、移动 Core Provider 和 Web Local Agent；
3. 迁移全球法布施、ChatGPT 自动确认及所有官方插件；
4. 市场和模板只接受新 MCP Apps Runtime Profiles；
5. 全平台真实验收；
6. 一次性切换 production；
7. 删除旧 SDK、旧 session、旧 bridge 和旧测试。

## 14. 成功标准

- 全球法布施可本地安装、桌面独立运行、移动本地执行、Web 经 Local Agent 执行；
- ChatGPT 自动确认在桌面本机真实运行，移动/Web 正确控制配对设备；
- 第三方 local-first MCP App 发布两个版本并完成安装、升级、回滚和撤销；
- Cloudflare 中断不影响已安装 local-only 插件打开 UI 和读取本地状态；
- 所有官方小程序均完成 MCP Apps 迁移；
- 生产代码不存在旧 MCP Session 和自定义 iframe 运行路径。