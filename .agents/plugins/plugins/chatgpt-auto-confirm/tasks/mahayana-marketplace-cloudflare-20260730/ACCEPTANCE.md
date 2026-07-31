# 验收标准：可热安装的本地 Web MCP Apps

任务只有在所有“必须”项满足并提供真实平台证据后才能报告 `complete`。

## 1. 同一网页包跨平台

- [ ] 全球法布施使用同一个签名插件包覆盖 iOS、Android、桌面 WebView 和普通 Web/PWA。
- [ ] 四个平台使用相同 `ui/` 资源。
- [ ] 四个平台使用相同 `runtime/web/` Tool 实现。
- [ ] 平台差异仅由 Host 存储、生命周期和安全适配器处理。
- [ ] 不为全球法布施在移动端编写专属原生业务实现。

## 2. 本地安装

- [ ] 插件包从市场不可变 URL 下载。
- [ ] 安装前验证市场签名、SHA、大小、来源、权限、CSP 和撤销状态。
- [ ] 解压到版本化本地目录。
- [ ] 使用安全本地 Origin 加载，不使用不安全 `file://` 通配访问。
- [ ] UI 和 Runtime 在断网时可以打开。
- [ ] 安装失败不破坏当前版本。

## 3. MCP Apps UI

- [ ] 声明 `io.modelcontextprotocol/ui`。
- [ ] 使用 `ui://` Resource。
- [ ] MIME 为 `text/html;profile=mcp-app`。
- [ ] Tool 使用 `_meta.ui.resourceUri`。
- [ ] Host 使用 AppBridge 或规范一致实现。
- [ ] iframe/WebView 有 sandbox、CSP、Origin 和导航策略。
- [ ] model/app Tool visibility 正确。

## 4. Local Web MCP Runtime

- [ ] `runtime/web/` 使用 JavaScript/TypeScript/WASM。
- [ ] Runtime 运行于 Dedicated Worker、MessagePort 或等价隔离环境。
- [ ] UI 与 Runtime 不是同一个高权限执行上下文。
- [ ] Runtime 实现 `tools/list`、`tools/call` 和必要 Resource/Workflow 契约。
- [ ] Runtime 只能访问获批域名和插件私有存储。
- [ ] UI 无法直接读取 Secret。
- [ ] Runtime 崩溃可单独重启，不导致主 App 崩溃。

## 5. 聊天和页面共用 Tool

- [ ] 用户在对话框发送全球法布施指令时，Host 调用正式 MCP Tool。
- [ ] 用户在 MCP App 页面点击发送时，通过 AppBridge 调用同一个 Tool。
- [ ] 两种入口产生相同参数验证、权限确认、队列、状态和结果。
- [ ] 不使用模拟点击、DOM 选择器或向 iframe 注入自然语言代替 Tool 调用。

## 6. 全球法布施

- [ ] 实现 `send`、`status`、`cancel` 和 `logs` 等本地 Web Tool。
- [ ] 发送逻辑运行于本地 Web Runtime。
- [ ] Cloudflare 不代理每次本地 Tool 执行。
- [ ] 无网络时可以查看、编辑和排队任务。
- [ ] 网络恢复后队列继续执行。
- [ ] 插件本地状态与账号/授权隔离。
- [ ] 执行位置显示为“本地网页”。

## 7. 热更新、回滚和撤销

- [ ] 发布 `1.0.0` 和 `1.1.0` 两个网页包版本。
- [ ] 更新 UI 或 Tool 逻辑无需发布新的大乘主 App。
- [ ] 新版本在 staging 沙箱完成 smoke test 后原子切换。
- [ ] 新版本失败时回滚到旧版本。
- [ ] 被撤销版本不能重新安装或运行。
- [ ] 权限、CSP 或网络域名扩大时必须重新确认。

## 8. Android

- [ ] 从 App 私有存储加载网页包。
- [ ] 使用 WebViewAssetLoader/InternalStoragePathHandler 或等价安全实现。
- [ ] 禁用 `file://` 跨域和任意文件访问。
- [ ] 安装、更新和功能在 Play 审核说明中透明可见。
- [ ] 不通过动态代码隐藏审核时未披露的功能。

## 9. iOS

- [ ] 从 App 私有存储加载网页包。
- [ ] 使用 WKURLSchemeHandler、受控 loopback 或等价安全实现。
- [ ] 提供完整小程序索引、元数据和 universal/deep links。
- [ ] 每插件隐私权限逐次明确同意。
- [ ] 不向下载的小程序暴露未经 Apple 允许的任意原生 API。
- [ ] App Review 可访问市场、插件和测试账号。

## 10. 普通 Web/PWA

- [ ] Service Worker 或等价机制提供本地离线资源。
- [ ] Cache Storage、IndexedDB 或 OPFS 保存包和状态。
- [ ] 浏览器清理存储后可从签名版本恢复。
- [ ] 同一 Tool 契约与移动端一致。
- [ ] 浏览器能力不足时明确显示限制，不伪装成功。

## 11. 主 App 更新边界

- [ ] HTML/CSS/JavaScript/WASM、Tool 流程、Skills 和普通 HTTPS 更新无需主 App 更新。
- [ ] 新原生受限能力被正确阻止或要求主 App 更新/平台批准。
- [ ] 主 App 不包含每个插件的专属发送逻辑。
- [ ] Host 只提供通用、最小、可审计能力。

## 12. 其他 Runtime

- [ ] ChatGPT 自动确认继续使用 `desktop-stdio`，未被错误改造成纯网页 Runtime。
- [ ] local-web 插件不被强制提供 Cloudflare MCP endpoint。
- [ ] 存在 remote-edge 时使用 SDK v2、`createMcpHandler` 和 `legacy: "reject"`。

## 13. 旧实现删除

- [ ] 自定义 iframe bridge 已删除。
- [ ] `Mcp-Session-Id` 已删除。
- [ ] 旧 GET/SSE/DELETE Session 已删除。
- [ ] SDK v1 Server 和旧 Host fallback 已删除。
- [ ] 新 Host 不运行未迁移插件。

## 14. 真实证据

最终报告必须列出：

- PR、合并提交和 Actions Run；
- 全球法布施两个签名版本及 SHA；
- iOS、Android、桌面 WebView 和 Web/PWA 的安装与运行证据；
- 聊天 Tool 与页面 Tool 的同一调用证据；
- 本地离线、网络恢复和队列证据；
- 热更新不更新主 App 的证据；
- 原子切换、回滚和撤销证据；
- CSP、Origin、权限和 Secret 隔离证据；
- iOS/Android 审核材料和合规测试；
- 无 R2、无永久市场代理、无旧 MCP 运行路径的证据。

缺少任一强制项时状态必须为 `incomplete`。
