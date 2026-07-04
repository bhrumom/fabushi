# 全球法布施 Rust Worker 内存降级与 IPC 通信优化需求与技术总结文档 (PRD & Technical Report)

## 1. 背景与问题定义 (Background & Problem Definition)

### 1.1 问题现象
在全球法布施（Global Dharma）小程序/应用发包运行过程中，本地运行链路频繁出现中断与报错。系统提示诊断信息：“不是 Rust 写不了，而是整个运行链路里有一个致命点 + 你本地环境已经被打断”。

### 1.2 根本原因剖析 (First Principles Thinking)
通过第一性原理深入剖析系统架构与底层逻辑，定位到以下关键技术瓶颈：
1. **磁盘 IO 瓶颈与临时文件泄漏**：在原有的进程间通信 (IPC) 链路中，TS 前端发送调度服务 (`GlobalDharmaSendService.ts`) 每次启动子进程发包前，都会调用 `fbApp.invoke("fs.writeFile")` 将待发送任务序列化后写入本地硬盘 `/runtime/global-dharma-worker/jobs/xxx.json` 临时文件中。
2. **沙盒权限缺失导致磁盘爆满**：小程序/小游戏宿主沙盒环境虽开放了文件读写权限 (`fs.writeFile`/`fs.readFile`)，但未暴露文件删除权限 (`fs.deleteFile` 或 `fs.remove`)。随着法布施任务高频执行，`jobs/` 目录下积攒了数千个旧 JSON 任务文件，无法实现自清理，最终导致系统磁盘与 inode 耗尽，彻底阻塞本地底层发包链路。

---

## 2. 核心架构与技术方案 (Architecture & Technical Solution)

### 2.1 设计理念
严格遵循 **KISS（Keep It Simple, Stupid）** 原则与 **简洁至上** 理念，摈弃传统的“写硬盘 -> 读硬盘”低效 IPC 模式，将数据传递机制全面升级为纯内存 URI 缓冲与流式传输（Memory URI / Stdin Fallback）。

### 2.2 具体实现细节

#### Phase 1: 内存缓冲降级与 Base64 解码器实现 (Completed)
1. **Rust Worker (`main.rs`) 零依赖升级**：
   - 不引入任何外部沉重的第三方 Crate，在 `global-dharma-worker/src/main.rs` 内部实现了精简高效、支持标准与 URL-safe 格式的零依赖 Base64 解码器 (`decode_base64`)。
   - 新增统一任务读取逻辑 `read_job_content()`：自适应支持 `--job-file memory://job:<base64>` URI、标准 `stdin` 管道流及传统的本地文件路径。不仅实现了内存直读，同时也保障了百分之百的向后兼容性。
2. **TS 调度层 (`GlobalDharmaSendService.ts`) 内存首选改造**：
   - 优化 `writeWorkerJob` 方法：在构建完发包任务 JSON 后，优先通过 `bytesToBase64(textBytes(jsonStr))` 将待执行任务构建为 `memory://job:${base64}` 协议参数传给 Rust 命令行进程。
   - 彻底摆脱对本地磁盘文件系统 (`jobs/*.json`) 的依赖，将发包阶段的硬盘 IO 消耗降为 0，从架构源头上永久杜绝了磁盘临时文件堆积的问题。

---

## 3. 验证与回归测试总结 (Verification & Test Results)

在实施上述内存降级方案后，执行了完全自动化全局回归测试：
1. **Rust 单元测试与静态审查**：
   - 针对新增的 Base64 内存编解码逻辑编写了专项单元测试 `tests::test_decode_base64`。
   - 执行 `cargo check` 与 `cargo test`，编译无任何警告，测试用例 100% 成功通过。
2. **Flutter 客户端测试闭环**：
   - 执行 `flutter test`，全部 133 项自动化测试用例均通过（包括闪卡服务、素材提取、搜索解析、UI 渲染等全局链路）。
3. **前端 TypeScript 严密类型审查**：
   - 执行 `pnpm -r typecheck`，各层 SDK、API Client 及 Shared 工具库类型校验全数通过，无任何类型隐患。

---

## 4. 后续演进规划 (Future Roadmap)

- **Phase 2: 常驻守护进程与流式 IPC (Production-Grade Constant Runtime)**：
  - 在后续版本演进中，将进一步把每次发包启动一次 Rust Worker 命令行进程的方式，改造成常驻后台守护进程（Daemon）。
  - 通过标准输入/输出流（stdin/stdout pipe）进行长连接双向 JSON-RPC 通信，实现亚毫秒级的极限响应速率。
