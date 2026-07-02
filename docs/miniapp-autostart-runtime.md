# 小程序启动即运行脚本/程序：Autostart Runtime 设计

## 目标

Fabushi 小程序可以支持一种模式：用户打开小程序后，不需要再点击“开始”，小程序声明的脚本、worker 或本机任务可以直接启动。

但这个能力必须设计成平台能力，而不是让网页随便执行本机命令。

```text
用户打开小程序
  -> 宿主读取 manifest
  -> 校验官方身份、签名、hash、宿主版本、权限
  -> 准备 runtime
  -> 自动执行 onLaunch / autostart 任务
  -> UI 订阅状态、日志、回执
```

核心原则：**可以自动运行，但必须经过宿主 runtime；小程序不能绕过宿主直接拿本机系统权限。**

## 适用场景

- 全球法布施：打开后自动准备内容、恢复上次任务、启动循环 worker；
- 佛经整理：打开后自动扫描 appData 里的待处理内容并开始整理；
- AI 制卡：打开后自动执行本地生成队列；
- 自动发布：打开后自动恢复上次未完成的发布任务；
- 本地知识库：打开后自动启动索引 worker；
- 创意小程序：打开即运行官方脚本/程序，UI 只作为控制台。

## Manifest 新增字段

建议在小程序 manifest 中加入 `launch` 字段。

```json
{
  "schemaVersion": 3,
  "miniAppId": "official.global-dharma",
  "title": "全球法布施",
  "source": "official",
  "reviewStatus": "trusted",
  "entryUrl": "https://fabushi.ombhrum.com/miniapps/global-dharma",
  "launch": {
    "mode": "auto",
    "entrypoint": "onLaunch",
    "runBeforeUiReady": false,
    "resumePreviousJob": true,
    "requiresUserGesture": false,
    "showRunningIndicator": true,
    "failurePolicy": "showErrorAndOpenUi"
  },
  "runtime": {
    "type": "rust-program",
    "programId": "global-dharma-worker",
    "version": "1.0.0",
    "sha256": "<package-sha256>",
    "signature": "<ed25519-signature>"
  },
  "permissions": [
    {
      "name": "rust.program",
      "reason": "打开小程序后自动启动全球法布施 worker"
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
| `manual` | 默认模式，用户点击按钮后运行 | 普通小程序 |
| `auto` | 打开小程序后自动运行 | 官方任务型小程序 |
| `resume-only` | 只恢复上次未完成任务，不创建新任务 | 长任务恢复 |
| `headless` | 可以不打开完整 UI，只运行后台任务入口 | 桌面端、官方小程序、系统托盘任务 |

早期为了快速创新，可以先支持：

```text
manual
auto
resume-only
```

`headless` 等安全模型稳定后再开放。

## 启动顺序

### 标准 UI 启动

```text
1. 用户打开小程序
2. 宿主下载/读取 manifest
3. 校验 source = official、reviewStatus = trusted、signature、sha256
4. 检查 hostVersion、runtime、capabilities
5. 检查用户是否已经同意 autostart 权限
6. 创建 launch session
7. 加载小程序 UI
8. UI bootMiniApp
9. 宿主触发 launch.entrypoint
10. runtime 启动脚本/worker
11. UI 订阅 events/logs/status
```

### 先运行再打开 UI

某些官方小程序可以设置：

```json
{
  "launch": {
    "mode": "auto",
    "runBeforeUiReady": true
  }
}
```

流程变成：

```text
1. 用户打开小程序
2. 宿主先启动 runtime job
3. UI 加载后自动 attach 到 job
4. UI 展示状态、日志、停止按钮
```

这个模式适合“打开就是执行”的任务型小程序，但必须满足：

```text
source = official
reviewStatus = trusted
runtime 已签名
权限已预授权或用户曾经授权
showRunningIndicator = true
job 可停止
```

## Autostart Host API

新增通用能力组：`runtime.launch`。

| 方法 | 作用 |
|---|---|
| `runtime.launch.getPolicy` | 读取当前小程序自动运行策略 |
| `runtime.launch.requestAutostart` | 请求用户允许打开即运行 |
| `runtime.launch.revokeAutostart` | 关闭打开即运行 |
| `runtime.launch.getSession` | 获取当前 launch session |
| `runtime.launch.attachJob` | UI 加载后绑定已启动 job |

与本机代码执行能力配合：

| runtime | 自动运行方式 |
|---|---|
| `script.js` | 宿主内置 JS runtime / WebView 执行 `onLaunch` |
| `script.lua` | 宿主内置 Lua runtime 执行入口 |
| `wasm` | 宿主 WASM runtime 调用 exported `on_launch` |
| `rust-program` | 桌面端启动独立 Rust worker |
| `rust-library` | 移动/桌面调用内置 Rust library 函数 |
| `cloud-worker` | 移动/Web 提交云端任务并订阅状态 |

## 小程序 SDK 入口

小程序侧建议约定生命周期函数。

```ts
export async function onLaunch(ctx: MiniAppLaunchContext) {
  const existing = await ctx.host.invoke("rust.program.listJobs", {
    miniAppId: "official.global-dharma",
    status: ["running", "paused", "queued"]
  });

  if (existing.jobs.length > 0) {
    return ctx.host.invoke("rust.program.resume", {
      jobId: existing.jobs[0].jobId
    });
  }

  return ctx.host.invoke("rust.program.start", {
    programId: "global-dharma-worker",
    args: ctx.launchArgs,
    restartPolicy: {
      mode: "on-failure",
      maxRestarts: 3
    }
  });
}
```

如果是移动端：

```ts
export async function onLaunch(ctx: MiniAppLaunchContext) {
  if (ctx.host.capabilities.includes("rust.globalDharmaCore")) {
    return ctx.host.invoke("rust.globalDharmaCore.start", ctx.launchArgs);
  }

  return ctx.host.invoke("cloudWorker.start", {
    workerId: "global-dharma-worker",
    args: ctx.launchArgs
  });
}
```

## 首次授权与后续自动运行

为了符合用户预期，第一次打开需要展示一次“此小程序会自动运行本地任务”。

授权文案示例：

```text
全球法布施希望在打开小程序时自动启动本地任务。

它可能会：
- 持续运行循环发送任务；
- 访问网络节点；
- 保存任务状态和回执；
- 在运行期间请求保持唤醒。

你可以随时停止任务，或在设置中关闭自动运行。
```

用户同意后，宿主保存 grant：

```json
{
  "userId": "...",
  "miniAppId": "official.global-dharma",
  "permission": "runtime.launch.autostart",
  "runtime": "rust-program",
  "decision": "granted",
  "expiresAt": null,
  "createdAt": "2026-07-02T00:00:00Z"
}
```

官方内置小程序可以预授权，但仍要：

```text
显示运行指示
可停止
可查看日志
可撤销自动运行
写审计日志
```

## 全局和小程序级开关

宿主设置页必须提供两级开关：

```text
全局：允许官方小程序启动时自动运行任务
单个小程序：全球法布施 -> 打开时自动运行
```

如果用户关闭全局开关，小程序只能打开 UI，不能自动运行脚本/worker。

## 移动端规则

移动端也可以“打开小程序就运行脚本”，但含义是：**App 前台打开小程序时立即执行受控脚本/内置能力**。

移动端允许的 autostart 类型：

| 类型 | 是否推荐 | 说明 |
|---|---:|---|
| Web JS `onLaunch` | 推荐 | UI 和轻逻辑 |
| WASM `on_launch` | 推荐 | 算法、解析、hash |
| 内置 Rust library | 推荐 | 宿主 App 已打包的 Rust 能力 |
| 云端 worker | 强烈推荐 | 长任务、循环任务 |
| 外部本机二进制 | 不推荐 | 移动端不要动态下载运行 |
| 任意 shell | 不支持 | 移动端不应开放 |

移动端启动后可以自动：

```text
读取 manifest
运行 JS/WASM/onLaunch
调用内置 Rust library
提交云端 worker
恢复上次任务状态
订阅回执和日志
```

但不要承诺：

```text
App 被系统杀掉后仍一直本地循环
后台无限运行
动态下载原生二进制并执行
```

如果全球法布施需要真正持续循环，移动端应提交给云端 worker；桌面端才运行本地 Rust worker。

## 桌面端规则

桌面端可以支持更强的 autostart：

```text
打开小程序即启动本地 Rust worker
UI 关闭后 worker 可继续运行
系统托盘显示任务状态
用户可从任务管理器停止
App 重启后可恢复 queued/running/paused 任务
```

桌面端必须有：

```text
jobId
runId
stop/kill
log cursor
receipt store
resource limit
audit log
network allowlist
signature/hash 校验
```

## 全球法布施推荐行为

全球法布施小程序打开时建议这样做：

```text
1. 自动检查是否有未完成 job
2. 有 job：自动 attach + resume
3. 没有 job，但用户已开启“打开即运行”：自动 start
4. 没有授权：打开 UI，并显示一键开启自动运行
5. 运行中：UI 实时展示日志、回执、停止按钮
```

伪代码：

```ts
async function globalDharmaOnLaunch(ctx: MiniAppLaunchContext) {
  const policy = await ctx.host.invoke("runtime.launch.getPolicy", {
    miniAppId: "official.global-dharma"
  });

  const jobs = await ctx.host.invoke("rust.program.listJobs", {
    miniAppId: "official.global-dharma",
    status: ["running", "paused", "queued"]
  });

  if (jobs.length > 0) {
    return ctx.host.invoke("runtime.launch.attachJob", {
      jobId: jobs[0].jobId
    });
  }

  if (!policy.autostartAllowed) {
    return { mode: "ui-only", reason: "autostart_not_granted" };
  }

  return ctx.host.invoke("rust.program.start", {
    programId: "global-dharma-worker",
    args: ctx.launchArgs,
    restartPolicy: {
      mode: "on-failure",
      maxRestarts: 3
    }
  });
}
```

## 最小实现版本

第一版可以先做得很简单：

```text
1. manifest 支持 launch.mode = auto
2. 只允许 source=official + reviewStatus=trusted
3. 只支持桌面端 rust-program 和移动端 cloud-worker/rust-library
4. 打开小程序后自动调用 onLaunch
5. UI 必须展示运行状态和停止按钮
6. 设置页可以关闭自动运行
7. 所有启动、停止、失败写审计日志
```

这样既满足“打开小程序就直接运行脚本/程序”，又不会把平台做成不可控的任意代码执行器。
