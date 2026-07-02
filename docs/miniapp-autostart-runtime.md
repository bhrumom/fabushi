# 小程序启动即运行：本地优先 Autostart Runtime 设计

## 目标

Fabushi 官方小程序支持启动即运行。用户打开小程序后，宿主读取 manifest，选择当前设备可用的本地运行时，自动启动任务，并让 UI 订阅状态、日志和回执。

```text
用户打开小程序
  -> 宿主读取 manifest
  -> 校验官方身份、签名、hash、宿主版本、权限
  -> 选择本地 runtime
  -> 自动执行 onLaunch
  -> UI 订阅状态、日志、回执
```

核心原则：**本地能运行的都本地运行；不使用云端作为默认兜底。**

## 本地优先策略

```json
{
  "mode": "local-first",
  "cloudFallback": false,
  "onUnsupported": "showUpgradeOrSwitchDevice"
}
```

含义：

```text
1. 当前设备能运行的任务，一律在当前设备本地运行。
2. 桌面端优先使用本地 Rust worker、本地工具和本地脚本运行时。
3. 移动端优先使用 JS、WASM、内置 Rust library、内置轻量解释器。
4. Web 端只运行浏览器本地 JS/WASM。
5. 当前设备无法本地执行时，返回 unsupported_local_runtime。
6. 不静默切换到远程执行。
```

## Manifest 示例

```json
{
  "schemaVersion": 3,
  "miniAppId": "official.global-dharma",
  "title": "全球法布施",
  "source": "official",
  "reviewStatus": "trusted",
  "launch": {
    "mode": "auto",
    "entrypoint": "onLaunch",
    "runBeforeUiReady": true,
    "resumePreviousJob": true,
    "showRunningIndicator": true,
    "failurePolicy": "showErrorAndOpenUi"
  },
  "executionPolicy": {
    "mode": "local-first",
    "cloudFallback": false,
    "onUnsupported": "showUpgradeOrSwitchDevice"
  },
  "runtime": {
    "preferred": "rustProgramDesktop",
    "fallback": [
      "rustLibrary",
      "wasm",
      "script.js",
      "script.lua",
      "script.pythonLite"
    ]
  },
  "permissions": [
    {
      "name": "official.localRuntime",
      "reason": "打开小程序后自动在当前设备本地启动全球法布施任务"
    },
    {
      "name": "runtime.storage",
      "reason": "恢复任务队列、状态和回执"
    },
    {
      "name": "network.http",
      "reason": "向全球法布施节点提交任务"
    },
    {
      "name": "system.keepAwake",
      "reason": "循环发送期间防止设备休眠"
    }
  ]
}
```

## launch.mode

| mode | 行为 | 适用场景 |
|---|---|---|
| `manual` | 用户点击后运行 | 普通小程序 |
| `auto` | 打开后自动运行本地任务 | 官方任务型小程序 |
| `resume-only` | 只恢复上次未完成任务 | 长任务恢复 |
| `headless` | 不打开完整 UI，直接进入任务状态 | 桌面端和官方任务 |

第一版先支持 `manual`、`auto`、`resume-only`。

## 启动顺序

```text
1. 用户打开小程序
2. 宿主下载或读取 manifest
3. 校验 source=official、reviewStatus=trusted、signature、sha256
4. 检查 hostVersion、runtime、capabilities
5. 检查 executionPolicy.cloudFallback=false
6. 检查用户是否已允许 autostart
7. 创建 launch session
8. 选择当前平台本地可用 runtime
9. 加载 UI，或先创建本地 job 再让 UI attach
10. 触发 launch.entrypoint
11. UI 订阅 events/logs/status
12. 没有本地可用 runtime 时返回 unsupported_local_runtime
```

## Autostart Host API

| 方法 | 作用 |
|---|---|
| `runtime.launch.getPolicy` | 读取当前小程序自动运行策略 |
| `runtime.launch.requestAutostart` | 请求用户允许打开即运行 |
| `runtime.launch.revokeAutostart` | 关闭打开即运行 |
| `runtime.launch.getSession` | 获取当前 launch session |
| `runtime.launch.attachJob` | UI 加载后绑定已启动 job |

## 本地 runtime 映射

| runtime | 自动运行方式 |
|---|---|
| `script.js` | 宿主内置 JS runtime / WebView 执行 `onLaunch` |
| `script.lua` | 宿主内置 Lua runtime 执行入口 |
| `wasm` | 宿主 WASM runtime 调用 `on_launch` |
| `rustProgramDesktop` | 桌面端启动本地 Rust worker |
| `rustLibrary` | 移动/桌面调用宿主内置 Rust library 函数 |
| `script.pythonLite` | Android/桌面用宿主内置轻量解释器执行受控任务 |
| `localToolDesktop` | 桌面端运行宿主允许的本地任务组件 |

## 小程序 SDK 入口

```ts
export async function onLaunch(ctx: MiniAppLaunchContext) {
  const result = await ctx.host.invoke("runtime.task.start", {
    taskId: "global-dharma-delivery",
    executionPolicy: {
      mode: "local-first",
      cloudFallback: false
    },
    preferredRuntime: "rustProgramDesktop",
    fallbackRuntimes: ["rustLibrary", "wasm", "script.js", "script.lua", "script.pythonLite"],
    args: ctx.launchArgs
  });

  if (result?.errorCode === "unsupported_local_runtime") {
    return {
      ok: false,
      suggestions: ["升级 App", "切换到桌面端", "关闭长循环，仅运行本地轻任务"]
    };
  }

  return result;
}
```

## 首次授权与后续自动运行

第一次打开需要展示一次“此小程序会自动运行本地任务”。

```text
全球法布施希望在打开小程序时自动启动本地任务。

它可能会：
- 在当前设备本地持续运行循环发送任务；
- 访问网络节点；
- 保存任务状态和回执；
- 在运行期间请求保持唤醒。

你可以随时停止任务，或在设置中关闭自动运行。
```

授权记录：

```json
{
  "userId": "...",
  "miniAppId": "official.global-dharma",
  "permission": "runtime.launch.autostart",
  "runtimePolicy": "local-first",
  "cloudFallback": false,
  "decision": "granted",
  "expiresAt": null,
  "createdAt": "2026-07-02T00:00:00Z"
}
```

官方内置小程序可以预授权，但仍要显示运行指示、可停止、可查看日志、可撤销自动运行、写审计日志。

## 移动端规则

移动端也可以“打开小程序就运行”，含义是：**App 前台打开小程序时立即执行本地受控脚本/内置能力**。

| 类型 | 是否推荐 | 说明 |
|---|---:|---|
| Web JS `onLaunch` | 推荐 | UI 和轻逻辑，本地执行 |
| WASM `on_launch` | 推荐 | 算法、解析、hash，本地执行 |
| 内置 Rust library | 推荐 | 宿主 App 已打包的 Rust 能力，本地执行 |
| Lua / pythonLite | 可选 | 宿主内置解释器，本地受控执行 |
| 外部本机运行组件 | 不推荐 | 移动端不作为默认能力 |

移动端启动后可以自动读取 manifest、运行 JS/WASM/onLaunch、调用内置 Rust library、恢复上次本地任务状态、订阅回执和日志。

移动端不承诺系统限制之外的无限后台运行。全球法布施需要持续循环时，先使用内置 Rust library、系统允许的前台任务/后台任务能力；仍无法满足时，明确提示升级 App 或切换桌面端。

## 桌面端规则

桌面端可以支持更强的 autostart：

```text
打开小程序即启动本地 Rust worker
UI 关闭后 worker 可继续运行
系统托盘显示任务状态
用户可从任务管理器停止
App 重启后可恢复 queued/running/paused 任务
```

桌面端必须有 jobId、runId、停止能力、log cursor、receipt store、resource limit、audit log、network allowlist、signature/hash 校验。

## 全球法布施推荐行为

```text
1. 自动检查是否有未完成本地 job
2. 有 job：自动 attach + resume
3. 没有 job，但用户已开启“打开即运行”：自动 start 本地任务
4. 当前设备无本地 runtime：提示升级 App 或切换桌面端
5. 没有授权：打开 UI，并显示一键开启自动运行
6. 运行中：UI 实时展示日志、回执、停止按钮
```

## 最小实现版本

```text
1. manifest 支持 launch.mode = auto
2. 只允许 source=official + reviewStatus=trusted
3. 只支持桌面端 rustProgramDesktop 和移动端 rustLibrary / WASM / JS
4. 明确 cloudFallback=false
5. 打开小程序后自动调用 onLaunch
6. UI 必须展示运行状态和停止按钮
7. 设置页可以关闭自动运行
8. 所有启动、停止、失败写审计日志
9. 当前设备没有本地 runtime 时返回 unsupported_local_runtime
```

这样既满足“打开小程序就直接运行”，又满足“本地能运行的都本地运行，不使用云端默认兜底”。