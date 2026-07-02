# 官方小程序任意脚本/程序运行能力设计

## 目标

Fabushi 平台先按“官方小程序可以执行任何脚本/程序，并尽量在任何平台运行”的方向设计。

这里的“任何平台运行”不是要求每个平台都用同一种本机执行方式，而是要求：

```text
官方小程序声明一个任务
  -> 宿主根据当前平台选择可用 runtime
  -> 能本机运行就本机运行
  -> 不能本机运行就用内置解释器 / WASM / Rust library / 云端 worker 承接
  -> 对小程序和用户表现为同一套任务启动、日志、状态、停止、回执协议
```

也就是说，产品目标是：**官方小程序打开后可以直接运行任务，平台负责把脚本/程序映射到当前平台可用的执行器。**

## 顶层原则

早期阶段以官方小程序为主，平台应先保留最大创造力：

```text
source = official
reviewStatus = trusted
```

满足以上条件的小程序可以申请 `official.anyRuntime` 超级能力。

这个能力允许官方小程序声明和运行：

```text
JavaScript 脚本
Lua 脚本
Python 脚本
Node.js 脚本
Shell 命令
Rust worker
Rust library
WASM 模块
本机二进制程序
云端 worker
AI agent / MCP tool / desktop automation 任务
```

但所有运行都必须经过宿主 runtime gateway，不能让小程序直接绕过宿主访问系统。

## 新增能力：official.anyRuntime

```json
{
  "name": "official.anyRuntime",
  "risk": "critical",
  "officialOnly": true,
  "reason": "官方小程序需要在各平台运行脚本、worker、二进制或云端任务，用于快速落地复杂创意能力"
}
```

语义：

```text
官方小程序可以声明任意 runtime。
宿主负责选择当前平台可执行的 adapter。
宿主负责签名、hash、日志、停止、资源限制和审计。
未来开放第三方时，再拆成更细粒度 runtime 权限。
```

## Runtime 类型

```text
runtime.script.js
runtime.script.lua
runtime.script.python
runtime.script.node
runtime.shell
runtime.wasm
runtime.rustProgram
runtime.rustLibrary
runtime.binary
runtime.cloudWorker
runtime.agent
runtime.mcp
runtime.desktopAutomation
```

每一种 runtime 都走同一套生命周期：

```text
prepare
start
pause
resume
stop
kill
getStatus
readLogs
subscribeEvents
listJobs
```

## 统一任务协议

官方小程序不要关心底层到底是 JS、Python、Rust、WASM 还是云端 worker。它只提交一个 task：

```json
{
  "miniAppId": "official.global-dharma",
  "taskId": "global-dharma-delivery",
  "launchMode": "auto",
  "preferredRuntime": "rustProgram",
  "fallbackRuntimes": [
    "rustLibrary",
    "wasm",
    "script.js",
    "cloudWorker"
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

宿主返回：

```json
{
  "jobId": "job_...",
  "selectedRuntime": "cloudWorker",
  "platform": "ios",
  "status": "running"
}
```

这样即使 iOS 不能运行外部本机二进制，官方小程序仍然可以启动任务；宿主只是把执行器切到 `rustLibrary`、`wasm`、`script.js` 或 `cloudWorker`。

## 各平台执行策略

| 平台 | 首选执行器 | 可选执行器 | 兜底执行器 |
|---|---|---|---|
| macOS | `rustProgram` / `binary` / `shell` | `python` / `node` / `wasm` / `js` | `cloudWorker` |
| Windows | `rustProgram` / `binary` / PowerShell | `python` / `node` / `wasm` / `js` | `cloudWorker` |
| Linux | `rustProgram` / `binary` / `shell` | `python` / `node` / `wasm` / `js` | `cloudWorker` |
| iOS | `script.js` / `wasm` / `rustLibrary` | `cloudWorker` | `cloudWorker` |
| Android | `script.js` / `wasm` / `rustLibrary` | `pythonLite` / `cloudWorker` | `cloudWorker` |
| Web | `script.js` / `wasm` | `cloudWorker` | `cloudWorker` |

平台对外保证的是：

```text
官方任务可以启动
状态可以查看
日志可以订阅
任务可以停止
能力可以审计
```

而不是保证每个平台都以同一种本机方式执行。

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
      "name": "official.anyRuntime",
      "reason": "官方全球法布施需要根据平台自动选择 JS/WASM/Rust/云端 worker 执行任务"
    }
  ],
  "taskRuntime": {
    "taskId": "global-dharma-delivery",
    "preferredRuntime": "rustProgram",
    "fallbackRuntimes": [
      "rustLibrary",
      "wasm",
      "script.js",
      "cloudWorker"
    ],
    "packages": [
      {
        "runtime": "rustProgram",
        "platforms": ["macos", "windows", "linux"],
        "packageUrl": "https://fabushi.ombhrum.com/runtime/global-dharma-worker/1.0.0/package.tar.zst",
        "sha256": "<sha256>",
        "signature": "<signature>"
      },
      {
        "runtime": "wasm",
        "platforms": ["ios", "android", "web", "desktop"],
        "moduleUrl": "https://fabushi.ombhrum.com/runtime/global-dharma-mobile/1.0.0/module.wasm",
        "sha256": "<sha256>",
        "signature": "<signature>"
      },
      {
        "runtime": "script.js",
        "platforms": ["ios", "android", "web", "desktop"],
        "entryUrl": "https://fabushi.ombhrum.com/runtime/global-dharma-mobile/1.0.0/onLaunch.js",
        "sha256": "<sha256>",
        "signature": "<signature>"
      },
      {
        "runtime": "cloudWorker",
        "platforms": ["ios", "android", "web"],
        "workerId": "global-dharma-worker-cloud",
        "version": "1.0.0"
      }
    ]
  }
}
```

## 启动即运行

官方小程序启动时，宿主按以下顺序执行：

```text
1. 读取 manifest
2. 判断 source=official 且 reviewStatus=trusted
3. 检查是否拥有 official.anyRuntime
4. 读取 taskRuntime.preferredRuntime
5. 根据当前平台选择最优 runtime
6. 下载/加载任务包
7. 校验 sha256/signature
8. 创建 job
9. 自动运行 onLaunch/start
10. UI attach 到 job，展示日志、状态、停止按钮
```

小程序侧只需要：

```ts
export async function onLaunch(ctx) {
  return ctx.host.invoke("runtime.task.start", {
    taskId: "global-dharma-delivery",
    args: ctx.launchArgs
  });
}
```

## 热更新策略

官方小程序的脚本程序可以热更新，但按 runtime 分类处理：

| Runtime | 热更新策略 |
|---|---|
| `script.js` | 可热更新，校验签名和 hash 后运行 |
| `script.lua` | 可热更新，宿主内置 Lua runtime 执行 |
| `wasm` | 可热更新，宿主 WASM runtime 执行 |
| `python` | 桌面可热更新，移动端只允许宿主内置 pythonLite 或云端 |
| `node` | 桌面可热更新，移动端不作为默认本地执行器 |
| `shell` | 仅桌面官方小程序可用 |
| `rustProgram` | 桌面可热更新 worker 包 |
| `rustLibrary` | 跟随 App 更新，不能由小程序替换宿主内置库 |
| `binary` | 桌面可热更新，移动端默认不执行外部本机二进制 |
| `cloudWorker` | 服务端热更新 |

所以“官方任何平台运行”的实现方式是：

```text
桌面：尽量本机运行任何脚本/程序
移动：JS/WASM/内置 library 本地运行，重任务/受限任务云端运行
Web：JS/WASM 本地运行，重任务云端运行
```

## 安全底线

虽然官方阶段可以给最大权限，但仍然必须保留未来收紧入口：

```text
全局开关：允许官方小程序运行脚本/程序
小程序级开关：允许某个官方小程序运行任务
任务级停止：每个 job 都必须能 stop/kill
日志审计：记录 runtime、版本、hash、参数摘要、退出码
网络记录：记录访问 host/port
文件记录：记录读写 appData/workspace 范围
资源限制：最大运行时间、最大日志、最大并发 job
版本回滚：远程禁用某个 runtime package
Kill switch：平台可立即停止某个官方任务
```

早期不要因为这些控制点拖慢能力开放，但字段和入口要先设计进去。

## 全球法布施最终行为

```text
桌面打开全球法布施：
  自动启动 rustProgram global-dharma-worker，本机循环运行。

iOS 打开全球法布施：
  自动运行 JS/WASM onLaunch；如果只是轻任务就本地执行；循环全球发送交给 cloudWorker。

Android 打开全球法布施：
  自动运行 JS/WASM/onLaunch 或内置 Rust library；长循环任务交给 cloudWorker 或受控前台服务策略。

Web 打开全球法布施：
  自动运行 JS/WASM；长循环任务交给 cloudWorker。
```

用户感知统一为：

```text
打开全球法布施小程序，它就自动开始运行。
```

底层由宿主选择最合适 runtime，未来再按生态开放程度逐步收紧权限。
