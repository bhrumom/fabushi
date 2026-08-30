# 2026-08-29 — 统一 Web MCP / App MCP / 原生语义电脑控制

## 原始目标

在 GBF-409/410 已有的同账号设备发现、远程 MCP、GitHub Actions Runner、完整 Computer Use 与安全输入能力上做**纯增量扩展**：

1. Fabushi Web 页面主动通过 WebMCP 暴露结构化工具与当前页面状态。
2. Fabushi 桌面与移动应用主动通过 App MCP / Agent Surface 暴露稳定的语义 UI 工具，AI 不必依赖截图识别 Fabushi 自身界面。
3. 同一设备仍保留完整的原生 Computer Use；当目标应用没有 App MCP 时，AI 优先使用浏览器 DOM/Accessibility、macOS AX、Windows UIA、Linux AT-SPI/X11 等语义控制，再在语义不可用的画布/游戏/远程桌面场景使用截图与坐标兜底。
4. 远程 MCP 仍只发现当前 Fabushi 账号授权的在线设备，并动态转发该设备公布的工具 schema；新增 App MCP 不能替换、缩减或绕过现有设备控制、权限、审批、短租约、重连、审计和安全输入边界。
5. AI 探索路径可记录为脱敏 trace，并转换为稳定的 App Agent Surface 回放候选；失败时保留结构化状态、原生语义树、日志和截图证据。

## 目标控制优先级

```text
1. Fabushi/Web 页面主动公布的 App MCP / WebMCP 工具
2. 浏览器 DOM + Accessibility / 原生 App Accessibility 语义树与稳定元素操作
3. 受控键盘、指针、滚动和窗口操作
4. 截图/视觉/坐标（仅语义不可用时兜底）
```

## 不可回归约束

- `list_devices`、`describe_device_tool`、`device_call`、CI 会话工具、secure input 和完整 `computer_*` 工具继续存在。
- 第三方应用没有 App MCP 时仍必须可控；不允许把 Fabushi App MCP 变成唯一入口。
- 不新增通用 `execute_javascript`、任意 Shell、任意内部函数或跨账号设备枚举。
- App MCP 写操作必须带当前 generation，拒绝陈旧元素引用；密码、令牌、cookie、SecretRef 明文不得出现在快照、trace 或 artifact。
- 生产默认仍受本机 AI 电脑控制开关、local tool permission、OS 权限和远程会话授权约束；CI 只能通过显式测试模式开启。

## Open-source-first 调研

- **WebMCP Community Group draft / Chrome implementation**：复用 `document.modelContext.registerTool()`、JSON Schema、页面实时状态、origin isolation、permissions policy、工具取消与显式用户控制设计；WebMCP 仍是 Web 页面 API，因此原生 App 采用兼容工具合同而不是伪装成浏览器 Document。
- **Model Context Protocol TypeScript SDK**：继续使用标准 MCP tool schema、Streamable HTTP 与 stdio，不建立第二套远程协议。
- **Appium / platform accessibility stacks**：保留 context/DOM/native accessibility 分层思路，但不引入 Appium server 作为产品运行时；Fabushi 已有 AX/UIA/AT-SPI/X11/CDP 适配器，直接复用更安全且包体更小。
- **现有 Fabushi MiniApp WebMCP Surface**：桌面、iOS、Android 已有受控 MiniApp WebMCP 与工具审批；新的主应用 Agent Surface 复用其 schema、审批与 origin/bridge 隔离原则，不复制第二套 MiniApp runtime。

## 验收结果定义

- Fabushi 主 Web 页面可在支持 WebMCP 的浏览器注册 `fabushi.app.*` 工具，并在不支持时提供同合同的受控本地 fallback surface。
- 打包桌面应用的私有 `fabushi-computer` MCP 始终公布 App MCP 工具；应用未启动时返回结构化 unavailable，启动后通过 loopback + 0600 discovery credential 读取/操作真实 renderer 语义表面。
- 语义快照包含 screen/route/generation/稳定元素 ID/role/name/state，敏感输入值被拒绝或脱敏。
- 写操作验证 generation、目标稳定 ID、可见/可用状态与动作 allowlist，并产生结构化后置状态。
- Remote MCP 无需改地址；设备工具目录自动出现 App MCP 工具，同时继续出现完整 Computer Use 工具。
- `computer_control_route` 明确推荐 App MCP → browser/native semantic → coordinate fallback；无 App MCP 的应用仍可通过现有语义工具完成控制。
- Desktop/Web 单元、合同、安全、Electron package/Runner live E2E 通过；移动端合同与原生测试 adapter 通过对应 CI。
