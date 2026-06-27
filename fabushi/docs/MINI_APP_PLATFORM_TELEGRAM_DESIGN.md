# Fabushi 小程序平台设计：吸收 Telegram Mini Apps 的好设计

## 背景

Fabushi 已经有一版小程序宿主：`MiniAppHostScreen` 使用 `flutter_inappwebview` 承载网页，并注入 `window.FabushiMiniApp.invoke(method, params)` 作为宿主能力调用入口。当前宿主已能分发登录、支付、AI、法布施、文件、OpenClaw、桌面控制、文件系统、shell、浏览器打开、闪卡等能力。

这份文档的目标不是照搬 Telegram，而是吸收它的成熟边界：

1. 小程序本体是 WebView 中运行的 Web 应用；
2. 宿主只暴露清晰、版本化、可审计的 JS Bridge；
3. 小程序业务数据由小程序/开发者后端保存；
4. 平台侧只提供身份、支付入口、轻量存储、权限、宿主 UI、设备能力；
5. 高风险能力必须走声明、授权、确认、范围限制和审计；
6. 桌面端可以比 Telegram 更强，但不能比系统安全边界更粗糙。

## 从 Telegram 开源代码吸收的设计

### 1. WebView 宿主只做容器和能力代理

Telegram Android 侧 `BotWebViewContainer` 负责打开 WebView、注入/接收 WebApp 事件、维护按钮、主题、返回键、发票状态等宿主 UI 状态。小程序不是直接拿 Telegram 内部对象，而是通过事件协议调用宿主。

Fabushi 应保持同样边界：小程序不得直接拿 Dart/Flutter 内部服务实例，只能通过 Host API 能力名调用。

### 2. 明确事件/方法协议，而不是暴露任意对象

Telegram 用稳定事件名承载能力，例如：

- `web_app_data_send`：小程序发送数据给 bot；
- `web_app_open_invoice`：打开 invoice；
- `web_app_setup_main_button`：控制主按钮；
- `invoice_closed`：发票关闭后回传状态。

Fabushi 已有 `FabushiMiniApp.invoke(method, params)`，应继续强化为版本化 RPC 协议：

```js
await window.FabushiMiniApp.invoke('app.getContext')
await window.FabushiMiniApp.invoke('fs.writeFile', { path: 'notes/a.txt', content: '...' })
```

每个方法都必须有：

- method 名称；
- 所需 permission；
- 支持平台；
- 参数 schema；
- 返回 schema；
- 是否需要用户确认；
- 是否写审计日志；
- 是否可由第三方小程序调用。

### 3. 轻量存储分层

Telegram 侧的设计可以抽象为三层：

- 小程序业务数据：开发者后端保存；
- 云端轻量键值：跟随账号，用于偏好；
- 设备本地/安全存储：跟随设备，用于缓存或敏感本机 token。

Fabushi 建议对应为：

| 层 | Fabushi 能力 | 存储位置 | 适用数据 |
|---|---|---|---|
| 业务数据库 | 小程序后端自行实现 | 小程序/开发者后端 | 订单、会员、课程、任务状态 |
| Host KV | `storage.host.get/set/delete` | Fabushi 用户云端或本地同步库 | 小程序设置、最近入口 |
| Device KV | `storage.device.get/set/delete` | App 私有目录 | 本机缓存、草稿 |
| Secure KV | `storage.secure.get/set/delete` | Keychain/Keystore/系统凭据库 | 小程序 token、密钥片段 |

默认不允许小程序把订单、余额、法币资产等核心业务只存在 Host KV。Host KV 只是平台辅助能力。

### 4. 支付入口和订单归属分离

Telegram 的支付模式值得吸收：宿主提供安全支付入口和支付结果事件，但业务订单仍由 bot/开发者后端保存。

Fabushi 应采用同样结构：

```text
Mini App
  -> payments.createOrder / payments.open
  -> Fabushi Host 支付面板或 provider SDK
  -> provider / Fabushi backend
  -> payment.closed / payment.succeeded / payment.failed
  -> Mini App backend 确认并发货
```

支付 Host API 不应该变成第三方小程序的账本系统。第三方小程序应自己保存商品、订单、权益；Fabushi 只保存必要的支付凭证、审计记录和平台分成记录。

### 5. 桌面能力必须比移动端更强，但权限模型更细

Telegram 主要暴露移动端可接受的能力。Fabushi 的差异化在桌面端：可以接入本机文件系统、shell、浏览器、OpenClaw、MCP、系统自动化等能力。

因此 Fabushi 不能只用一个 `desktop.control` 大权限。应拆成细粒度、可组合、可撤销的能力：

| 权限 | 说明 | 默认第三方 | 是否需确认 |
|---|---|---:|---:|
| `app.context` | 读取平台、小程序、主题上下文 | 允许 | 否 |
| `auth.session` | 读取脱敏登录态 | 需声明 | 首次确认 |
| `auth.token` | 读取访问 token | 默认拒绝 | 每次或短时授权 |
| `payments.provider` | 发起支付 | 需审核 | 每次确认 |
| `storage.device` | 设备 KV | 需声明 | 首次确认 |
| `storage.secure` | 安全 KV | 需审核 | 首次确认 |
| `files.pick` | 文件选择器 | 需声明 | 系统确认 |
| `fs.appData` | 小程序私有目录读写 | 需声明 | 首次确认 |
| `fs.workspace.read` | 用户授权工作区读 | 需审核 | 首次确认 |
| `fs.workspace.write` | 用户授权工作区写 | 需审核 | 写入前确认或批量确认 |
| `fs.absolute.read` | 任意绝对路径读 | 默认拒绝 | 每次确认 |
| `fs.absolute.write` | 任意绝对路径写 | 默认拒绝 | 每次强确认 |
| `shell.execute` | 执行本地命令 | 默认拒绝 | 每次强确认 |
| `browser.external` | 打开外部 URL | 需声明 | 可按域名记住 |
| `local.loopback` | 访问 localhost | 需审核 | 首次确认 + 端口白名单 |
| `desktop.control` | UI 自动化/系统控制 | 默认拒绝 | 每次强确认 |
| `openclaw.chat` | 调用本机 OpenClaw AI | 官方允许，第三方审核 | 首次确认 |
| `mcp.invoke` | 调用本机 MCP 工具 | 默认拒绝 | 每次强确认 |

## 现状风险点

当前 `MiniAppHostScreen` 的方向是正确的，但有几个需要尽快收敛的风险：

1. `fs.writeFile` / `fs.readFile` 允许绝对路径直接通过 `_resolvePath`，这会把 `fs.readWrite` 变成近似任意文件读写。
2. `shell.execute` 使用 `Process.start(..., runInShell: true)`，如果开放给非官方小程序，风险非常高。
3. `permissions` 目前主要来自 bot 配置，缺少“用户实际 grant”的持久化记录。
4. `trustedOfficial` 只区分官方与非官方，但缺少 method 级策略。
5. 缺少统一审计表：谁、哪个小程序、什么权限、什么时候、参数摘要、结果、耗时、是否用户确认。
6. 缺少 Host API schema 的机器可读定义，`_hostApiSpec()` 目前偏展示用途，不能驱动校验、权限、文档生成和测试。

## 建议目标架构

```text
Mini App WebView
  -> FabushiMiniApp JS SDK
    -> Host RPC Envelope
      -> MiniAppPermissionManager
        -> Policy Engine
          -> User Grant Store
          -> Manifest Registry
          -> Capability Registry
          -> Confirmation UI
        -> Capability Dispatcher
          -> Identity Capability
          -> Payment Capability
          -> Storage Capability
          -> FileSystem Capability
          -> Shell Capability
          -> Desktop Control Capability
          -> OpenClaw / MCP Capability
        -> Audit Logger
```

### 1. RPC Envelope

统一请求结构：

```json
{
  "id": "req_...",
  "method": "fs.writeFile",
  "params": {},
  "sdkVersion": "1.3.0",
  "miniAppId": "...",
  "origin": "https://...",
  "userGesture": true
}
```

统一响应结构：

```json
{
  "ok": true,
  "id": "req_...",
  "data": {},
  "auditId": "audit_..."
}
```

失败响应：

```json
{
  "ok": false,
  "id": "req_...",
  "errorCode": "permission_denied",
  "message": "小程序未获得 fs.workspace.write 权限",
  "data": {}
}
```

### 2. Capability Registry

把现在 `_dispatch()` 中的大 switch 拆成注册表：

```dart
class MiniAppCapabilitySpec {
  final String method;
  final String permission;
  final Set<MiniAppSurface> surfaces;
  final bool requiresUserGesture;
  final ConfirmationPolicy confirmationPolicy;
  final AuditLevel auditLevel;
  final bool officialOnly;
  final Future<Map<String, dynamic>> Function(MiniAppInvokeContext ctx) handler;
}
```

这样 `app.getHostApiSpec`、权限校验、测试、文档都从同一个 source of truth 生成。

### 3. Manifest Registry

Manifest 应升级为：

```json
{
  "schemaVersion": 2,
  "miniAppId": "global-dharma",
  "botId": "global-dharma-bot",
  "title": "全球法布施",
  "entryUrl": "https://fabushi.ombhrum.com/miniapps/global-dharma",
  "version": "1.0.0",
  "origins": ["https://fabushi.ombhrum.com"],
  "surfaces": ["mobile", "desktop", "web"],
  "permissions": [
    {
      "name": "dharma.share",
      "reason": "启动全球法布施发送"
    },
    {
      "name": "fs.workspace.write",
      "reason": "把生成结果保存到用户选择的项目目录",
      "scope": {
        "pathMode": "userSelectedDirectory"
      }
    }
  ],
  "reviewStatus": "trusted",
  "source": "official",
  "signature": "..."
}
```

关键点：

- `origins` 必须限制 WebView 加载来源；
- `permissions` 必须带 reason，用于授权弹窗；
- `scope` 用于限制路径、端口、命令、域名；
- `signature` 用于后续做签名校验，避免 registry 被篡改。

### 4. Grant Store

新增用户授权表或本地持久化：

```json
{
  "userId": "...",
  "miniAppId": "...",
  "permission": "fs.workspace.write",
  "scope": {
    "paths": ["/Users/me/Projects/foo"]
  },
  "decision": "granted",
  "expiresAt": "2026-07-27T00:00:00Z",
  "createdAt": "...",
  "lastUsedAt": "..."
}
```

授权原则：

- 官方小程序可以预授权低风险权限，但高风险能力仍记录审计；
- 第三方小程序必须用户授权；
- shell、任意路径写、桌面控制、MCP 调用必须强确认；
- 用户可以在设置页撤销每个小程序的每项权限。

### 5. 桌面本地能力策略

#### 文件系统

拆分成三种路径模式：

1. `appData`：小程序私有目录，默认相对路径只落在这里；
2. `workspace`：用户明确选择的项目目录；
3. `absolute`：任意绝对路径，默认拒绝，每次强确认。

必须防御：

- `..` 路径逃逸；
- symlink 逃逸；
- 覆盖系统敏感目录；
- 超大文件读取；
- 二进制文件误读；
- 静默批量删除或覆盖。

#### Shell

`shell.execute` 不应直接接收任意字符串并 `runInShell: true`。建议改为：

```json
{
  "commandId": "npm.install",
  "args": ["..."],
  "workingDirectory": "workspace://current",
  "stream": true
}
```

第一阶段只允许白名单命令模板：

- `git.status`
- `git.diff`
- `npm.install`
- `npm.test`
- `flutter.analyze`
- `flutter.test`
- `open.file`
- `open.url`

真正的 arbitrary shell 只给开发者模式、官方小程序或用户每次强确认。

#### Desktop Control

`desktop.control` 应继续走 `DesktopControlBridge`，但每个 tool 也要变成 capability：

- `desktop.screenshot`
- `desktop.click`
- `desktop.type`
- `desktop.hotkey`
- `desktop.window.focus`
- `desktop.clipboard.read/write`

高风险项例如剪贴板读取、自动输入、点击系统弹窗，必须单独确认。

#### Local Loopback

Telegram 不鼓励小程序直接随便扫 localhost。Fabushi 桌面端可以开放，但要端口白名单：

- OpenClaw Gateway：`127.0.0.1:18789`；
- Fabushi dev server：显式开发模式；
- 用户授权的 MCP server 端口。

禁止默认访问任意 `localhost:*`，防止读取本机其他服务管理面板。

## 分阶段实施计划

### Phase 1：把现有宿主收敛成可维护平台

- [ ] 新增 `mini_app_host_api.dart`，定义 `MiniAppCapabilitySpec`、`MiniAppInvokeContext`、`MiniAppInvokeResult`。
- [ ] 把 `_dispatch()` 中的 switch 拆到 capability registry。
- [ ] `app.getHostApiSpec` 从 registry 自动生成。
- [ ] 为每个 method 标注 permission、surface、audit、confirmation policy。
- [ ] 给 `fs.*`、`shell.*`、`desktopControl.*` 加单元测试。

### Phase 2：权限与授权

- [ ] 新增 `MiniAppPermissionManager`。
- [ ] 新增 `MiniAppGrantStore`，存储用户 grant。
- [ ] 小程序打开时显示权限说明页。
- [ ] 高风险 method 调用时弹出强确认。
- [ ] 设置页新增“小程序权限管理”。

### Phase 3：桌面能力安全化

- [ ] `fs.readWrite` 拆成 `fs.appData`、`fs.workspace.read`、`fs.workspace.write`、`fs.absolute.read`、`fs.absolute.write`。
- [ ] `_resolvePath` 禁止默认接受绝对路径。
- [ ] `shell.execute` 改为 command template + allowlist。
- [ ] `desktopControl.executeTool` 拆成 tool 级 permission。
- [ ] `localLoopback.fetch` 改为端口/服务白名单。

### Phase 4：小程序生态

- [ ] mini app manifest 支持 origins、permission reasons、scopes、signature。
- [ ] registry 支持官方、sandbox、marketplace 三类来源。
- [ ] 加入 review workflow：pending -> approved -> trusted/rejected。
- [ ] 小程序 SDK npm 包或静态 JS 文件：`@fabushi/miniapp-sdk`。
- [ ] 小程序示例：全球法布施、闪卡生成、平台发布、桌面自动化示例。

## 与 Telegram 的关键差异

Telegram 的强项是：稳定 WebView 容器、清晰 JS bridge、支付入口、轻量存储、bot 后端模型。

Fabushi 要强化的是：

1. 桌面本地系统能力；
2. AI/OpenClaw/MCP 代理；
3. 项目文件夹/本地工作区能力；
4. 法布施、闪卡、发布等宿主业务能力；
5. 小程序权限比 Telegram 更细、更可审计。

因此 Fabushi 不能复制 Telegram 的“相对封闭移动端能力模型”，而要做成“Telegram Mini Apps + Desktop Capability Gateway”。

## 立即建议

当前最应该先做三件事：

1. **停止扩大 `MiniAppHostScreen` 的 switch**：先引入 capability registry。
2. **收紧文件和 shell 能力**：绝对路径和任意 shell 不应只靠 `permissions` 字符串放行。
3. **加入授权和审计**：桌面系统能力必须可追踪、可撤销、可解释。
