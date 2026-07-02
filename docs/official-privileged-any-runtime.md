# 官方小程序本地优先运行时策略

## 目标

Fabushi 官方小程序采用本地优先策略：小程序启动后，宿主在当前设备上选择可用的本地运行时来执行任务。

```text
官方小程序声明任务
  -> 宿主读取 manifest
  -> 宿主校验官方来源、版本、签名、hash、权限
  -> 宿主选择当前平台可用的本地 runtime adapter
  -> 本地启动任务
  -> UI 订阅状态、日志、回执，并提供停止按钮
```

本设计不使用云端作为默认兜底。当前设备能本地运行的部分全部本地运行；当前设备确实不支持的部分，返回明确的 `unsupported_local_runtime`，提示升级 App、安装本地运行组件，或切换到桌面端。

## 本地优先原则

```text
1. 本地能运行的，必须本地运行。
2. 不把长任务默认转交云端。
3. 不把移动端缺失能力静默转交云端。
4. 任务启动、日志、状态、停止、回执都走宿主本地 runtime gateway。
5. 后续即使增加远程能力，也必须是用户显式选择，而不是默认执行路径。
```

## 官方运行权限

早期阶段只面向官方小程序：

```text
source = official
reviewStatus = trusted
```

满足条件的小程序可以申请：

```json
{
  "name": "official.localRuntime",
  "risk": "critical",
  "officialOnly": true,
  "localFirst": true,
  "cloudFallback": false,
  "reason": "官方小程序需要在当前设备本地运行受信任务，用于快速落地复杂创意能力"
}
```

## 本地 runtime adapter

官方小程序可以声明多种本地运行时，由宿主选择当前平台可用的 adapter：

```text
runtime.script.js
runtime.script.lua
runtime.script.pythonLite
runtime.script.nodeDesktop
runtime.wasm
runtime.rustProgramDesktop
runtime.rustLibrary
runtime.localToolDesktop
runtime.agentLocal
runtime.desktopAutomation
```

所有 adapter 都必须接入同一套生命周期：

```text
prepare
start
pause
resume
stop
terminate
getStatus
readLogs
subscribeEvents
listJobs
```

## 统一任务协议

官方小程序只提交任务，不直接接触底层系统能力。

```json
{
  "miniAppId": "official.global-dharma",
  "taskId": "global-dharma-delivery",
  "launchMode": "auto",
  "executionPolicy": {
    "mode": "local-first",
    "cloudFallback": false,
    "onUnsupported": "showUpgradeOrSwitchDevice"
  },
  "preferredRuntime": "rustProgramDesktop",
  "fallbackRuntimes": [
    "rustLibrary",
    "wasm",
    "script.js",
    "script.lua",
    "script.pythonLite"
  ],
  "args": {
    "content": {
      "title": "金刚般若波罗蜜经",
      "text": "..."
    },
    "loop": true,
    "intervalMs": 30000,
    "region": "global"
  }
}
```

宿主成功返回：

```json
{
  "jobId": "job_...",
  "selectedRuntime": "rustLibrary",
  "platform": "ios",
  "executionLocation": "local-device",
  "status": "running"
}
```

宿主不支持时返回：

```json
{
  "ok": false,
  "errorCode": "unsupported_local_runtime",
  "platform": "ios",
  "reason": "当前设备没有可用的本地长循环 runtime",
  "suggestions": [
    "升级 Fabushi App 以获得内置 Rust library",
    "切换到桌面端运行桌面 worker",
    "关闭长循环，仅运行本地 JS/WASM 轻任务"
  ]
}
```

## 各平台本地执行策略

| 平台 | 首选本地执行器 | 可选本地执行器 | 不支持时 |
|---|---|---|---|
| macOS | `rustProgramDesktop` / `localToolDesktop` | `nodeDesktop` / `pythonLite` / `wasm` / `js` / `lua` | 提示安装本地组件或升级宿主 |
| Windows | `rustProgramDesktop` / `localToolDesktop` | `nodeDesktop` / `pythonLite` / `wasm` / `js` / `lua` | 提示安装本地组件或升级宿主 |
| Linux | `rustProgramDesktop` / `localToolDesktop` | `nodeDesktop` / `pythonLite` / `wasm` / `js` / `lua` | 提示安装本地组件或升级宿主 |
| iOS | `script.js` / `wasm` / `rustLibrary` | `lua` / 本地任务队列 | 提示升级 App 或切换桌面端 |
| Android | `script.js` / `wasm` / `rustLibrary` | `pythonLite` / `lua` / 受控前台任务 | 提示升级 App 或切换桌面端 |
| Web | `script.js` / `wasm` | 浏览器本地存储和任务状态 | 提示切换 App 或桌面端 |

平台对外保证：

```text
官方任务优先本地启动
状态可以查看
日志可以订阅
任务可以停止
能力可以审计
不会无感转交远程执行
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
    "showRunningIndicator": true
  },
  "permissions": [
    {
      "name": "official.localRuntime",
      "reason": "官方全球法布施需要根据平台自动选择本地 JS/WASM/Rust/脚本 runtime 执行任务"
    }
  ],
  "taskRuntime": {
    "taskId": "global-dharma-delivery",
    "executionPolicy": {
      "mode": "local-first",
      "cloudFallback": false
    },
    "preferredRuntime": "rustProgramDesktop",
    "fallbackRuntimes": [
      "rustLibrary",
      "wasm",
      "script.js",
      "script.lua",
      "script.pythonLite"
    ]
  }
}
```

## 启动即运行

官方小程序启动时，宿主按以下顺序执行：

```text
1. 读取 manifest
2. 判断 source=official 且 reviewStatus=trusted
3. 检查是否拥有 official.localRuntime
4. 读取 taskRuntime.executionPolicy，确认 cloudFallback=false
5. 读取 preferredRuntime 和 fallbackRuntimes
6. 根据当前平台选择本地最优 runtime
7. 加载本地可执行任务包或脚本包
8. 校验 sha256/signature
9. 创建本地 job
10. 自动运行 onLaunch/start
11. UI attach 到 job，展示日志、状态、停止按钮
12. 如果没有本地可用 runtime，返回 unsupported_local_runtime
```

小程序侧：

```ts
export async function onLaunch(ctx) {
  return ctx.host.invoke("runtime.task.start", {
    taskId: "global-dharma-delivery",
    executionPolicy: {
      mode: "local-first",
      cloudFallback: false
    },
    args: ctx.launchArgs
  });
}
```

## 热更新策略

| Runtime | 本地更新策略 |
|---|---|
| `script.js` | 可热更新，校验签名和 hash 后在本地 JS runtime/WebView 运行 |
| `script.lua` | 可热更新，宿主内置 Lua runtime 本地执行 |
| `wasm` | 可热更新，宿主 WASM runtime 本地执行 |
| `pythonLite` | 可热更新受控脚本，由宿主内置轻量解释器本地执行 |
| `nodeDesktop` | 桌面端本地执行 |
| `rustProgramDesktop` | 桌面端本地 worker 包运行 |
| `rustLibrary` | 跟随 App 更新，不能由小程序替换宿主内置库 |
| `localToolDesktop` | 桌面端本地工具运行 |

## 全球法布施最终行为

```text
桌面打开全球法布施：
  自动启动 rustProgramDesktop global-dharma-worker，本机循环运行。

iOS 打开全球法布施：
  自动运行 JS/WASM onLaunch；可本地运行的内容处理、hash、轻任务全部本地执行；
  如果 App 内置 Rust library 支持循环任务，就本地执行；否则提示升级 App 或切换桌面端。

Android 打开全球法布施：
  自动运行 JS/WASM/onLaunch 或内置 Rust library；
  可用 pythonLite/lua/前台任务时本地执行；否则提示升级 App 或切换桌面端。

Web 打开全球法布施：
  自动运行 JS/WASM；无法本地完成的长循环任务提示切换 App 或桌面端。
```

用户感知统一为：

```text
打开全球法布施小程序，它就自动在当前设备本地开始运行能运行的部分。
```

底层由宿主选择最合适的本地 runtime。未来再按生态开放程度逐步收紧权限。