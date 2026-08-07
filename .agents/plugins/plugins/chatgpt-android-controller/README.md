# ChatGPT Android 自动化

这是一个独立于 `chatgpt-auto-confirm` 的新 Mahayana 小程序。旧 macOS/Electron 版本不修改；本插件专门控制真实 Android 设备或 Android Emulator 上的 ChatGPT App。

## 技术选型

主运行时使用 **TypeScript / Node.js**，设备层使用 **ADB + Appium UiAutomator2**：

- Mahayana/MCP 本身已经运行 Node.js，TypeScript 可以直接复用现有插件协议和部署方式。
- ADB 负责设备发现、启动 App、前台检查、点击回退和 UI hierarchy 读取。
- Appium UiAutomator2 负责可靠的 Android accessibility/UI 自动化，尤其是 Unicode/中文输入。
- 不引入 Rust/JNI；也不需要在手机上长期安装自研 AccessibilityService。

Android 官方 UiAutomator 支持跨进程检查和操作用户 App；Appium 的 UiAutomator2 driver 将这些能力暴露为稳定的 WebDriver 服务。

## 能力

- 多 Android 设备槽位（兼容旧版 `account_*` 命名）
- 自动扫描并点击 `Allow once / 允许一次 / 允許一次`
- watcher：`start / stop / status / scan_once / relaunch_and_confirm`
- 本地脱敏审计日志
- `send_message / add_connector / get_reply / chat_status / send_and_watch`
- 持久化任务队列：入队、依赖、优先级、多设备并行、暂停、恢复、验收、反馈重跑、取消、watchdog
- GitHub Actions/self-hosted runner 模式

### Android 与旧 macOS 版的关键差异

Android 应用沙箱不允许本插件读取 ChatGPT App 的私有 Cookie/Token，因此以下旧工具仍保留以兼容调用方，但会返回明确的 `android_app_sandbox`：

- `account_login_link`
- `account_sync`
- `sync_actions_credentials`
- `login_and_sync_actions`

Android 版不需要复制这些凭据。ChatGPT 登录状态由每台 Android 设备自身保存；CI/Actions 通过 self-hosted runner 连接设备后直接操作 App。

## 环境要求

1. Node.js >= 22.6
2. Android platform-tools (`adb`)
3. 手机开启开发者选项和 USB/Wi-Fi 调试
4. Android ChatGPT App 已安装
5. 推荐 Appium 3 + UiAutomator2 driver

检查设备：

```bash
adb devices -l
```

安装 Appium/UiAutomator2：

```bash
npm run setup:appium
npx appium
```

默认 Appium 地址为 `http://127.0.0.1:4723`。可覆盖：

```bash
export CHATGPT_ANDROID_APPIUM_URL=http://127.0.0.1:4723
```

## 本地 MCP

`.mcp.json` 直接使用 Node 启动本插件，不依赖旧版插件打包的 `fabushi-plugin-cli` 二进制：

```bash
node --experimental-strip-types --import ./runtime/safety-patches.ts server/index.ts
```

也可以直接使用 package script：

```bash
npm start
```

## 常用流程

注册唯一连接的手机：

```json
{"name":"account_add","arguments":{"label":"Pixel 主账号"}}
```

多台手机时指定 serial：

```json
{"name":"account_add","arguments":{"serial":"emulator-5554","label":"模拟器 A"}}
```

启动自动确认：

```json
{"name":"start","arguments":{"intervalMs":750,"approveAll":true}}
```

watcher 只会在 ChatGPT 已经位于 Android 前台时扫描授权卡，不会为了后台扫描抢走用户当前正在使用的其他 App。

发消息并等待：

```json
{
  "name":"send_and_watch",
  "arguments":{
    "message":"检查当前仓库状态并汇报",
    "connector":"GitHub",
    "timeout":21600
  }
}
```

任务队列：

```json
{
  "name":"enqueue_tasks",
  "arguments":{
    "start":true,
    "maxConcurrent":2,
    "tasks":[
      {"id":"task-a","title":"任务 A","prompt":"完成任务 A","accountId":"acct_..."},
      {"id":"task-b","title":"任务 B","prompt":"完成任务 B","accountId":"acct_..."}
    ]
  }
}
```

不同设备可以并行；同一设备同一时间只调度一个任务，避免两个 ChatGPT UI 操作互相覆盖。运行中的任务收到 `cancel_task` 后，会在下一轮轮询中退出并保持 `cancelled` 状态。

## 选择器策略

插件不把屏幕坐标作为主识别方式。每次操作先抓 Android accessibility hierarchy，再按以下语义匹配：

1. `text`
2. `content-description`
3. `resource-id`
4. 控件类型（例如 `EditText`）
5. 找到目标节点后才根据其实时 `bounds` 点击

因此分辨率变化不会直接破坏流程。ChatGPT Android UI 更新后，通常只需要扩展语义标签/selector，而不是重新录坐标。

`send_and_watch` 会记录发送前页面基线，并排除刚发送的用户消息，避免把用户消息误判成 ChatGPT 已完成回复。

## 状态与隐私

默认状态文件：

```text
~/.mahayana/chatgpt-android-controller/state.json
```

默认审计文件：

```text
~/.mahayana/chatgpt-android-controller/audit.log
```

审计只记录动作类型、设备槽位、字符数和错误，不记录消息正文、Cookie 或 Token。

可用环境变量：

- `CHATGPT_ANDROID_CONTROLLER_STATE`
- `CHATGPT_ANDROID_CONTROLLER_AUDIT`
- `CHATGPT_ANDROID_ADB`
- `CHATGPT_ANDROID_APPIUM_URL`
- `CHATGPT_ANDROID_PACKAGE`（默认 `com.openai.chatgpt`）

## GitHub Actions

推荐使用一台长期连接 Android 手机/模拟器的 self-hosted runner：

```text
GitHub Actions
  -> self-hosted runner
  -> Mahayana chatgpt-android-controller
  -> ADB / Appium UiAutomator2
  -> ChatGPT Android App
```

这样登录状态留在设备本身，不需要把 ChatGPT 私有凭据上传 GitHub Secrets。

## 验证边界

仓库内单元测试与契约检查覆盖 MCP 启动、UI hierarchy 解析和选择器基础逻辑。真实 ChatGPT Android UI 的 resource-id、Apps/connector 菜单和回复节点仍需要在连接具体 Android 设备后做一次 smoke 校准；不同 ChatGPT App 版本可能需要补充语义 selector。
