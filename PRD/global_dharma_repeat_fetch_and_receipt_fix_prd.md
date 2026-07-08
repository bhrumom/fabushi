# 全球法布施重复获取内容与回执缺失问题修复需求文档 (PRD)

## 1. 背景与问题概览
在当前“全球法布施”应用中，用户遇到两个明显且严重的异常现象：
1. **无限重复获取内容**：用户在聊天框发给小程序链接（或执行 `/start` 命令）后，一旦本次发包执行结束，小程序会自动无限次重新抓取该网页的正文内容并再次试图发送。
2. **无法获取真实回执**：在日志中提示 `[14:20:23] 发送已提交但暂无真实回执，未计入已发送数量，任务 gd_worker_...`，回执数量恒定为 0。

## 2. 第一性原理深度剖析 (Root Cause Analysis)

### 2.1 为什么会无限重复获取内容？（死循环根因）
通过定位宿主通信层、JS服务层与React前端UI交互逻辑，发现三处缺陷形成了严重的死循环闭环：
- **宿主与后端命令缓存未清空**：在 `ai-backend/src/server.js` 和宿主通信层规范（以及 `mini_app_host_screen.dart` / specs）中，`window.__fabushiLastMiniAppCommand` 缓存了用户发起的最后一条命令（如 `/start https://www.fojingzaixian.com/...`）。当 `queuedCommands()` 提取该命令后，代码没有将其清空置为 `null`。
- **React 组件频繁重绑定监听**：在 `GlobalDharmaApp.tsx` 中，监听宿主命令的 `useEffect` 依赖数组为 `[loopEnabled, selectedRegion, selectedMaterial, text, status.sentCount, status.sentMB, status.isTransferring]`。每当发包结束、UI 更新统计状态（`status.sentCount` 或 `status.sentMB` 发生变化）时，React 都会触发该 effect 重新运行：注销原有的 `onAnyCommand` 监听器并注册一个全新监听器。
- **死循环触发链路**：新注册的 `onAnyCommand` 会创建一个全新为空的去重 `seen` Set，并调用 `drainQueuedCommands()` 检查队列。由于 `window.__fabushiLastMiniAppCommand` 依然存在且新 listener 未见该命令，导致小程序立刻重新接收到 `/start <url>` 命令！于是再次调用 `handleStart` -> 重新 `network.http.fetch` 抓取链接 -> 再次发送 -> 统计状态更新 -> React 再次触发 `useEffect` 重注册 -> 再次触发最后命令……从而形成无限重复网络抓取与投递的死循环。

### 2.2 为什么获取不到真实回执？（回执丢失根因）
通过追踪回执数据从底层 Rust 到前端主界面的传递链路，发现两处关键断裂：
- **Stream IPC 发送层显式丢弃回执**：在 `global-dharma-send-service.ts` 中的 `sendViaMiniAppRustWorker` 方法内部，当检测到 18888 后台守护服务在线并走 HTTP POST 流式通道 `/send` 发包时，代码在第 1215 行直接硬编码了 `receipts: []`，未从响应中解析任何真实送达记录。导致返回给 UI 组件时回执数组始终为空，UI 判定 `receipts.length === 0`，从而输出 `"发送已提交但暂无真实回执，未计入已发送数量"`。
- **Rust Worker 响应 JSON 缺少回执列表**：在底层 `main.rs` (Rust worker) 中，虽然 `/send` 路由内部通过 `execute_job_payload` 逐个向全球目标发包并构建了真实的 `Receipt` 结构体列表，但在最终生成 HTTP 响应 JSON 时，仅序列化了 `{"ok":true,"bytesSent":...,"receiptCount":...}`，未将具体的回执明细字段 (`receipts: [...]`) 包含在内。

---

## 3. 设计方案与改造要点 (Proposed Solution - KISS 原则)

本方案恪守 **KISS (Keep It Simple, Stupid)** 原则，不引入复杂的中转中间件或状态机，通过精准切断死循环与打通数据透明传输，从根本上解决问题。

### 3.1 策略一：切断重复投递死循环
1. **修正宿主最后命令缓存消费逻辑**：
   - 检查 `ai-backend/src/server.js` 及其相关规范引用，确保对 `window.__fabushiLastMiniAppCommand` 的消费在投递处理后即时清空或建立长期去重；在任何类似 `queuedCommands` 逻辑中一旦取出后立即执行 `window.__fabushiLastMiniAppCommand = null;`。
2. **优化小程序 UI 层的事件监听生命周期**：
   - 重构 `GlobalDharmaApp.tsx` 和 `HermesInstallerApp.tsx`，使用 `useRef` 保存最新的状态引用（如 `status`、`text`、`loopEnabled` 等）。
   - 将绑定命令监听器 `onAnyCommand` 的 `useEffect` 依赖数组修改为空数组 `[]`，确保在整个应用加载周期内仅绑定一次监听，不会因发包进度或计数更新发生解绑重绑。
3. **在应用内增加命令去重防线**：
   - 在 `GlobalDharmaApp.tsx` 中引入局部命令处理去重缓冲（`processedCommandKeysRef = useRef(new Set<string>())`），根据命令 ID/时间戳/内容哈希去重，彻底防止任何来源的命令回放。

### 3.2 策略二：打通真实回执透明传输
1. **增强 Rust Worker 的 `/send` 响应负载**：
   - 修改 `native/global-dharma-worker` / `main.rs` 中的 `/send` 接口与 `execute_job_payload` 函数，使其将收集到的所有 `Receipt` 对齐 JSON 结构并放入响应返回：`{"ok":true,"bytesSent":...,"receiptCount":...,"receipts":[{...}]}`。
   - 增加 `/shutdown` / `/exit` 后台管理端点，支持在重构及新版发布时优雅终止旧的守护进程。
2. **修正前端发送服务的响应解析逻辑**：
   - 修改 `global-dharma-send-service.ts` 中的流式发包代码（原第 1215 行处），将硬编码的 `receipts: []` 更改为从 `resData.receipts` 中解析并映射为规范的 `DharmaDeliveryReceipt[]` 数组。
   - 在重新编译或构建 Rust Worker 前，调用新添加的 `/shutdown` 接口确保旧版本 18888 守护进程退出，使新编译的二进制程序生效。

---

## 4. 任务分解与实施步调 (Task Breakdown)
1. **任务一：清理命令队列与事件重绑定缺陷**
   - 修正 `ai-backend/src/server.js` 中 `__fabushiLastMiniAppCommand` 消费逻辑。
   - 改造 `GlobalDharmaApp.tsx` 与 `HermesInstallerApp.tsx` 的 `useEffect` 监听逻辑，借助 `useRef` 解除监听对动态状态的依赖。
2. **任务二：打通底层 Rust 到 UI 的回执返回**
   - 修改 Rust worker 的 `main.rs`，在 `/send` 接口和单元测试中完整返回 `receipts` 列表，并实现 `/shutdown` 端点。
   - 修改 `global-dharma-send-service.ts`，正确解析并传递流式发包下的真实回执，同时整合新版本守护进程重启机制。
3. **任务三：自动化测试与验证**
   - 运行项目内部的自动化测试验证发包逻辑正常。
   - 验证发送后拥有正确的真实回执个数及流量计算，且不再触发重复的内容抓取。

---

## 5. 实施记录与问题解决记录 (Implementation & Problem Resolution Log)

> **状态：已完成（100% Verified & Passed）**  
> **实施日期**：2026-07-07

### 5.1 实施过程总结
1. **任务一（清理命令队列与事件重绑定缺陷）**：
   - 修改了 `fabushi/lib/screens/mini_app_host_screen.dart`，在 `queuedCommands()` 中消费 `window.__fabushiLastMiniAppCommand` 后立即置空为 `null`；并在 `onAnyCommand` 中采用全局共享 `window.__fabushiSeenCommandKeys` 集合防止事件监听器重注册时漏过或重复处理历史命令。
   - 修改了 `ai-backend/src/server.js`，在小程序初始化脚本的微任务分发后立即清理 `window.__fabushiLastMiniAppCommand`。
   - 重构了 `GlobalDharmaApp.tsx` 和 `HermesInstallerApp.tsx`，利用 `useRef` 隔离状态依赖，将绑定 `onAnyCommand` 的 `useEffect` 依赖数组精简为 `[]`，并在应用层增设 `processedCommandIdsRef` 防重放机制。彻底斩断了“状态更新 -> 触发组件重新绑定 -> 重新消费全局未清空命令 -> 触发新一轮发包与抓取”的死循环链条。
2. **任务二（打通底层 Rust 到 UI 的回执返回）**：
   - 升级了 `global-dharma-worker` (`main.rs`)，增设了 `/shutdown` / `/exit` 优雅退出路由；将 `/send` 接口和 `execute_job_payload` 的结构改为返回完整的 `receipts: [{ nodeId, endpointId, channel, status, bytesSent, deliveredAt }]` 数组。
   - 修改了 `global-dharma-send-service.ts`，在构建新版 worker 之前主动遍历端口调用 `/shutdown` 指令关闭旧版后台；并将原硬编码的 `receipts: []` 替换为从响应负载中真实解析、映射的 `DharmaDeliveryReceipt[]`。

### 5.2 遇到的主要问题与解决方案
- **问题 1：全局作用域命令未及时销毁导致的事件回放缺陷**  
  *现象*：移动端及小程序容器页面中，一旦触发发包状态更新，UI 重新注册回调，原先把保留在全局 `window.__fabushiLastMiniAppCommand` 的指令重复注入，不断引发网页内容重复获取和发包请求。  
  *解决方案*：遵循“消费即销毁”原则，在核心分发通道中将变量置为 `null`；同时在前端组件的监听回调中通过 `useRef(new Set())` 对命令 ID 与内容哈希进行最近 100 条的去重拦截。
- **问题 2：Rust 守护进程常驻内存导致旧版二进制无法被热重载**  
  *现象*：更新了底层 Rust Worker 后，原先启动于 18888 端口的守护进程继续接收 `/send` 请求，导致新编译的对齐接口未生效。  
  *解决方案*：为 Rust Daemon 增设 `/shutdown` 路由，在 TypeScript 的 `buildMiniAppRustWorker` 编译升级前首先给所有潜在运行端口发送关闭指令，优雅释放端口并确保新进程正常启动。

### 5.3 自动化测试与结果验证
- 执行了底层 Rust 发包 worker 的完整单元测试与集成测试 (`cargo test`)。
- 测试结果：4 个测试套件（包括 `test_execute_job_payload` 真实发包负载验证、`test_daemon_http_server` HTTP 接口校验）全部一次性通过 (`4 passed; 0 failed`)。
- 确认 `/send` 正确返回了完整可解析的 `receipts` JSON 数据，且客户端上层发送服务成功将其转换为界面层展示的回执个数及发包流量。
