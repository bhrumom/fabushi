# 全球法布施小程序：本地 Rust 程序运行时设计

## 结论

全球法布施不应继续设计成“WebView 里点击一次、调用一次 HTTP/UDP”的普通小程序。它应设计成：

```text
小程序 UI / Bot 面板
  -> 准备任务参数、内容、权限声明、运行配置
  -> 调用宿主 Rust Program Runtime
  -> 宿主在本地受控容器中启动 Rust worker
  -> Rust worker 负责循环发送、队列、重试、回执、日志、暂停/恢复
  -> 小程序只订阅状态和控制生命周期
```

也就是说，复杂逻辑运行在本地 Rust 程序里；Web 小程序只负责交互、配置、展示和生命周期控制。宿主 App 不写全球法布施业务逻辑，只提供“运行 Rust 程序容器 + 能力原语 + 权限审计”。

## 为什么要这样设计

全球法布施和“单次发送”不一样，它天然是长任务：

- 需要循环发送，而不是一次按钮调用；
- 需要跨地区、跨节点、HTTP/UDP/本地场能等多通道调度；
- 需要队列、重试、失败恢复、速率限制、回执记录；
- 需要 Keep Awake、防止电脑休眠；
- 需要本地持久化，App 重启后可以恢复任务；
- 需要运行日志、实时状态和停止控制；
- 未来还会加入素材准备、内容哈希、分片、节点健康检查、风控策略等复杂逻辑。

这些逻辑如果全部写在 React 小程序里，会变成脆弱的前端定时器。一旦 WebView 被挂起、刷新、崩溃或网络闪断，任务就不可靠。因此需要把核心循环调度下沉到本地 Rust worker。

## 角色边界

| 组件 | 负责什么 | 不负责什么 |
|---|---|---|
| 小程序 UI | 输入链接/正文、选择地区、选择循环模式、展示日志、发出 start/stop/status 命令 | 不直接做长循环、不持有底层网络 socket、不直接访问系统 API |
| Rust worker | 内容准备后的任务执行、循环发送、队列、重试、回执、日志、状态机、本地持久化 | 不直接拿宿主账号 token、不绕过宿主权限、不控制 UI |
| 宿主 App | 提供 Rust 程序容器、权限授权、网络/文件/KeepAwake 原语、审计、进程生命周期 | 不写全球法布施业务策略、不把任意系统 API 暴露给小程序 |
| Host Adapter | `rust.program.*`、`runtime.storage.*`、`network.*`、`system.keepAwake` 等能力实现 | 不根据小程序动态安装未知系统能力 |

关键原则：小程序只能声明并调用宿主已经预置的能力。宿主没有内置的 adapter，小程序不能凭空获得新的系统 API。

## 推荐架构

```text
GlobalDharmaApp.tsx
  ├─ 收集输入：链接/正文/素材/地区/循环策略
  ├─ 调用 rust.program.prepare
  ├─ 调用 rust.program.start
  ├─ 订阅 rust.program.events
  └─ 显示 status/logs/receipts

Host MiniApp Bridge
  ├─ 能力协商：app.getCapabilities / app.requestCapabilities
  ├─ 权限校验：MiniAppPermissionManager
  ├─ 审计：MiniAppAuditLogger
  └─ 分发到 RustProgramRuntimeAdapter

RustProgramRuntimeAdapter
  ├─ 校验 manifest、签名、hash、权限、资源限额
  ├─ 创建本地 sandbox/container
  ├─ 启动 worker 进程或 WASI runtime
  ├─ 管理 stdin/stdout/stderr/event channel
  ├─ 管理 stop/pause/resume/restart
  └─ 写入本地 job store

Rust worker: global-dharma-worker
  ├─ prepare_content
  ├─ delivery_queue
  ├─ retry_scheduler
  ├─ http_delivery
  ├─ udp_delivery
  ├─ receipts_store
  ├─ rate_limiter
  └─ event_stream
```

## Rust Program Runtime 能力

新增能力组建议命名为 `rust.program`，只给官方/受信小程序开放，默认桌面端优先。

| 方法 | 作用 | 风险 | 说明 |
|---|---|---:|---|
| `rust.program.prepare` | 解析 manifest，准备本地 worker 包、校验 hash/signature | High | 不启动任务，只完成本地准备 |
| `rust.program.start` | 启动一个 worker job | Critical | 返回 `jobId`、`runId` |
| `rust.program.stop` | 停止指定 job | High | 支持 graceful timeout 后强制 kill |
| `rust.program.pause` | 暂停循环调度 | High | 保留队列和状态 |
| `rust.program.resume` | 恢复暂停任务 | High | 继续上一状态 |
| `rust.program.getStatus` | 读取 job 状态 | Medium | UI 轮询/恢复状态 |
| `rust.program.readLogs` | 读取日志片段 | Medium | 支持 cursor |
| `rust.program.listJobs` | 列出当前小程序 jobs | Medium | 只允许看到本小程序 namespace |
| `rust.program.subscribeEvents` | 订阅事件流 | Medium | 用于日志、回执、进度更新 |

后续如果不想暴露通用 Rust 程序能力，也可以收窄成 `globalDharma.worker.*`。但底层仍建议复用同一个 `RustProgramRuntimeAdapter`。

## 小程序 manifest 示例

```json
{
  "schemaVersion": 3,
  "miniAppId": "official.global-dharma",
  "title": "全球法布施",
  "source": "official",
  "reviewStatus": "trusted",
  "entryUrl": "https://fabushi.ombhrum.com/miniapps/global-dharma",
  "runtime": {
    "type": "rust-program",
    "programId": "global-dharma-worker",
    "version": "1.0.0",
    "entry": "bin/global-dharma-worker",
    "packageUrl": "https://fabushi.ombhrum.com/runtime/global-dharma-worker/1.0.0/package.tar.zst",
    "sha256": "<package-sha256>",
    "signature": "<ed25519-signature>",
    "targetTriples": [
      "aarch64-apple-darwin",
      "x86_64-apple-darwin",
      "x86_64-pc-windows-msvc",
      "x86_64-unknown-linux-gnu"
    ]
  },
  "permissions": [
    {
      "name": "rust.program",
      "reason": "在本地受控容器中运行全球法布施循环发送 worker"
    },
    {
      "name": "runtime.storage",
      "reason": "保存任务队列、回执、重试状态和恢复点"
    },
    {
      "name": "network.http",
      "reason": "读取佛法链接正文并向全球法布施节点提交任务"
    },
    {
      "name": "network.udp",
      "reason": "向本地场能节点或转经轮节点发送 UDP 数据包"
    },
    {
      "name": "system.keepAwake",
      "reason": "循环发送期间防止电脑休眠"
    }
  ],
  "resources": {
    "maxMemoryMb": 256,
    "maxCpuPercent": 50,
    "maxLogMb": 50,
    "networkAllowlist": [
      "https://api.ombhrum.com",
      "https://book.bfnn.org",
      "udp://127.0.0.1:9999"
    ]
  }
}
```

## 小程序调用流程

### 1. 打开小程序时协商能力

```ts
const caps = await fbApp.invoke("app.getCapabilities");
await fbApp.invoke("app.requestCapabilities", {
  permissions: [
    "rust.program",
    "runtime.storage",
    "network.http",
    "network.udp",
    "system.keepAwake"
  ]
});
```

### 2. 准备本地 Rust 程序

```ts
const prepared = await fbApp.invoke("rust.program.prepare", {
  miniAppId: "official.global-dharma",
  programId: "global-dharma-worker",
  version: "1.0.0"
});
```

`prepare` 阶段只做：下载/校验/解包/缓存/权限检查。不要开始发送。

### 3. 启动循环发送 job

```ts
const job = await fbApp.invoke("rust.program.start", {
  programId: "global-dharma-worker",
  args: {
    content: {
      title: "金刚般若波罗蜜经",
      sourceUrl: "https://book.bfnn.org/books/0040.htm",
      text: "..."
    },
    region: "global",
    loop: true,
    intervalMs: 30000,
    channels: ["http", "udp"],
    commandId: "cmd_..."
  },
  restartPolicy: {
    mode: "on-failure",
    maxRestarts: 3
  }
});
```

### 4. 订阅状态

```ts
fbApp.on("rust.program.event", (event) => {
  if (event.jobId !== job.jobId) return;
  // event.type: log | progress | receipt | retry | failed | stopped
});
```

### 5. 停止任务

```ts
await fbApp.invoke("rust.program.stop", {
  jobId: job.jobId,
  graceMs: 5000
});
```

## Rust worker 输入输出协议

为了让宿主不用理解全球法布施业务，worker 与宿主之间使用稳定 JSON Lines 事件协议。

### 启动输入

```json
{
  "runId": "run_20260702_001",
  "miniAppId": "official.global-dharma",
  "jobId": "job_global_dharma_001",
  "args": {
    "content": {
      "title": "金刚般若波罗蜜经",
      "text": "...",
      "sourceUrl": "https://book.bfnn.org/books/0040.htm"
    },
    "loop": true,
    "intervalMs": 30000,
    "region": "global",
    "channels": ["http", "udp"]
  },
  "capabilities": {
    "networkHttp": true,
    "networkUdp": true,
    "storage": true,
    "keepAwake": true
  }
}
```

### 事件输出

```json
{"type":"started","jobId":"job_global_dharma_001","at":"2026-07-02T03:43:41Z"}
{"type":"log","level":"info","message":"已读取链接正文：金刚般若波罗蜜经"}
{"type":"receipt","channel":"http","countryCode":"ALL","bytes":91234,"status":"queued"}
{"type":"retry","attempt":2,"nextAt":"2026-07-02T03:44:11Z","reason":"node_timeout"}
{"type":"progress","sentCount":12,"bytesSent":1094823,"loopRound":4}
{"type":"stopped","reason":"user_stop"}
```

## 本地容器策略

宿主提供的“Rust 程序容器”不是 Docker 依赖，而是跨平台的受控运行环境。桌面端建议分层实现：

1. **进程隔离**：独立子进程，固定 working directory，环境变量白名单；
2. **文件隔离**：只能访问小程序 appData/jobData 目录；
3. **网络隔离**：只允许 manifest 中声明的 domain、protocol、port；
4. **资源限制**：CPU、内存、日志大小、运行时长、并发 job 数限制；
5. **生命周期管理**：start、stop、pause、resume、crash restart；
6. **审计**：记录程序 hash、签名、参数摘要、权限、开始/停止、网络目标、失败原因；
7. **恢复**：App 重启后从 job store 恢复 queued/running/paused 状态。

平台映射：

| 平台 | 建议实现 |
|---|---|
| macOS | 子进程 + app sandbox/appData + hardened runtime；后续可加 seatbelt profile |
| Windows | 子进程 + Job Object + appData 隔离 + 防火墙/网络白名单策略 |
| Linux | 子进程 + cgroup/resource limit；后续可接 bubblewrap/firejail |
| iOS/Android | 默认不运行外部本地二进制，降级为宿主内置 Rust library 或云端 worker |
| Web | 不支持本地 Rust program，降级为 HTTP API |

## 全球法布施 worker 内部状态机

```text
created
  -> prepared
  -> running
     -> sending_round
     -> waiting_interval
     -> retrying
     -> paused
  -> stopping
  -> stopped
  -> failed
  -> completed
```

关键规则：

- `loop=true` 时，任务不以一次发送成功为结束；
- 每轮发送必须产生 round id；
- 回执必须持久化，不能只放 React state；
- 失败必须进入 retry/backoff，不允许静默丢失；
- 用户点击停止必须优先于下一轮循环；
- crash 后如果 restartPolicy 允许，宿主可以重启 worker；
- 所有外部网络目标必须在权限 scope 内。

## 与当前前端实现的迁移关系

当前 `GlobalDharmaApp.tsx` 和 `global-dharma-send-service.ts` 已经能完成真实 HTTP/UDP 发送，但循环依赖 WebView 的 `setInterval`。迁移后应改为：

| 当前逻辑 | 迁移后 |
|---|---|
| React `setInterval` 循环发送 | Rust worker 内部 loop scheduler |
| 前端 `sendViaHttp/sendViaUdp` | Rust worker 调用宿主网络能力或使用受控网络代理 |
| React state 保存回执 | `runtime.storage` 保存 job/receipts |
| 前端日志数组 | worker JSONL event stream + 宿主 log store |
| stop 按钮清 timer | `rust.program.stop(jobId)` |
| keepAwake 在 UI 层开启 | worker job 生命周期绑定 keepAwake lease |

前端仍保留 UI、命令入口、状态展示，但业务执行入口改成 `GlobalDharmaWorkerClient`。

## 最小落地顺序

### Phase 1：协议先落地

- [ ] 在 Host API spec 中新增 `rust.program` 能力组；
- [ ] 定义 `RustProgramManifest`、`RustProgramStartRequest`、`RustProgramEvent`；
- [ ] 小程序 manifest 增加 `runtime.type = rust-program`；
- [ ] 前端增加 `GlobalDharmaWorkerClient`，先用 mock adapter 跑通状态流。

### Phase 2：桌面宿主 runtime

- [ ] 实现 `RustProgramRuntimeAdapter.prepare/start/stop/status/logs`；
- [ ] 将 worker 包缓存在 appData；
- [ ] 校验 sha256/signature；
- [ ] 子进程启动并读取 JSONL stdout；
- [ ] job store 持久化 running/paused/stopped/failed 状态。

### Phase 3：全球法布施 worker

- [ ] 新建 `native/global-dharma-worker` Rust crate；
- [ ] 实现内容哈希、HTTP 投递、UDP 投递、回执、重试、循环调度；
- [ ] 将日志和回执全部输出为 JSONL 事件；
- [ ] 将状态保存到 runtime storage；
- [ ] 支持 graceful shutdown。

### Phase 4：安全与生产化

- [ ] 网络 allowlist；
- [ ] CPU/内存/日志限制；
- [ ] crash restart policy；
- [ ] 用户授权页展示“本地 Rust 程序将持续运行”；
- [ ] 设置页可停止/删除 worker/job；
- [ ] 审计页面可查看每轮发送和网络目标。

## 最重要的产品表达

用户看到的仍然是“全球法布施小程序”。技术上，它不是一次网页请求，而是小程序在本地启动一个受控 Rust worker：

> 小程序负责发愿与配置，Rust worker 负责持续运行，宿主负责安全容器和权限。

这样才能支撑循环全球发送和后续复杂调度，而不会把宿主 App 写死成某一个业务工具。

---

## 优化记录与最佳实践：UI 规范对齐与 Rust 运行时降耗优化 (2026-07)

### 1. UI 样式对齐与规范化
在早期开发中，全球法布施小程序页面 (`GlobalDharmaApp.tsx`) 自行使用了 `.miniapp-hero`、`.miniapp-card`、`.miniapp-label` 等前缀样式类，与项目全局统一小程序样式库 `miniapps.css` 脱节，导致组件呈现无 CSS 封装的裸奔状态。
优化后，全面将组件结构与样式绑定对齐至 Telegram 风格的官方样式规范（`.ma-panel`、`.ma-title-row`、`.ma-card`、`.ma-textarea`、`.ma-btn`、`hermes-status-grid`、`.ma-log-box`），确保视觉与所有官方小程序（如单词卡、转经轮安装器）保持高品质统一。

### 2. 彻底解决桌面端 Rust Worker 循环发热与高 CPU 负载
在原始实现中，桌面端发起真实发送（尤其是开启“循环真实发送”）时，底层 `sendViaMiniAppRustWorker()` 每轮调用都以命令行方式直接执行：
```bash
cargo run --quiet --manifest-path <temp-dir>/Cargo.toml -- --job-file <path>
```
**遭遇问题**：
高频定时执行 `cargo run` 会在每次发包时重复拉起 Cargo 进程树。Cargo 在每次唤醒后需要重新扫描依赖图、检查 `src/main.rs` 与 `Cargo.toml` 时间戳并唤起 `rustc` 进行环境依赖校验，对系统 CPU 产生持续剧烈的抖动和不必要的计算开销，直接导致机身发热与风扇狂转。

**优化方案（预编译 + 直接执行二进制）**：
1. **准备阶段预编译**：在 `prepareMiniAppRustWorker()` 初始化写入文件后，立刻通过桌面终端能力一次性执行构建命令：
   ```bash
   cargo build --release --quiet --manifest-path <temp-dir>/Cargo.toml
   ```
2. **路径记录**：根据操作系统类型，自动解析产物路径 `target/release/global-dharma-worker` (或 Windows 下 `.exe`) 并在 `PreparedWorker` 结构体中记录 `binaryPath`；
3. **极速调度**：后续在进行普通发送、真实回执轮询或每 30 秒定时循环时，调度器**优先直接运行已构建的高性能二进制执行文件**，将其执行响应时间缩短至毫秒级，CPU 占用极其轻微，从根本上消除了反复调用工具链造成的发热问题；
4. **降级保障**：在遇到特殊环境或权限限制导致直接执行二进制异常时，自动安全回退至 `cargo run --release`，兼顾性能极速与环境兼容。
