# 全球法布施小程序 UI 修复与 Rust 运行发热优化 PRD

## 1. 背景与目标
在近期修改“全球法布施” (`GlobalDharmaApp.tsx`) 小程序时，页面样式由于使用了错误的 CSS 类名前缀 (`.miniapp-*`)，而项目通用样式表 `miniapps.css` 中只定义了 Telegram 风格的 `.ma-*` 样式，导致界面元素呈现裸奔 HTML 状态，缺乏高级卡片布局与美观度。
同时，用户报告桌面端运行小程序提供的 Rust worker 时出现严重的 CPU 高负载与机身发热问题。经定位，当前底层的发包循环每次都在重复拉起 `cargo run` 指令，导致 Cargo 频繁启动依赖扫描、时间戳检测与 rustc 检查，对 CPU 造成不必要的巨大开销。

为了实现优质的 UI 体验与高效、冷静的后台运行，本项目目标为：
1. **彻底对齐界面 UI**：将全球法布施小程序的 DOM 结构与 CSS 类名全面迁移对齐至 `miniapps.css` 规范（`.ma-*` 系列），恢复深色毛玻璃卡片与规范化交互组件。
2. **重构 Rust Worker 执行策略**：在准备阶段（`prepareMiniAppRustWorker`）仅进行一次性 Release 模式构建，后续循环发送或重新发起任务时直接调用构建好的高性能原生二进制执行文件，完全跳过 `cargo` 编译链的重复拉起，彻底消除 CPU 高发热瓶颈。

## 2. 核心功能与技术方案

### 2.1 UI 样式优化 (GlobalDharmaApp.tsx)
- **根容器**：采用 `<div className="ma-panel global-dharma-app ma-fade-in" style={{ "--accent-start": "#10B981", "--accent-end": "#059669", "--accent-rgb": "16, 185, 129" } as any}>`。
- **标题区**：使用 `.ma-title-row` 结合 `.ma-header-title` 与 `.ma-header-subtitle`，右侧展示图标 `.ma-title-icon`。
- **表单区**：输入框采用 `.ma-textarea ma-textarea-tall`，标签采用 `.ma-label`，普通输入及选择下拉框采用 `.ma-input`。
- **按钮区**：发送、停止、素材选择按钮采用 `.ma-action-row ma-action-row-wrap` 配合 `.ma-btn` 和 `.ma-btn-secondary`。
- **状态区**：使用 `hermes-status-grid` 三列卡片布局展示“回执数量”、“真实发送数据(MB)”与“最新状态”。
- **日志区**：采用 `.ma-log-box` 与规范化输出格式。

### 2.2 Rust 运行发热优化 (global-dharma-send-service.ts)
- **一次性预编译**：
  在 `prepareMiniAppRustWorker()` 函数中，在完成 `Cargo.toml` 和 `src/main.rs` 的写入后，通过 `runtime.process.execute` 执行一次 `cargo build --release --quiet --manifest-path <path>`。
- **路径解析与记录**：
  根据操作系统环境（Windows 判断）推导二进制产物路径 `target/release/global-dharma-worker`（或 `.exe`），并在 `PreparedWorker` 返回结果中新增 `binaryPath` 字段。
- **发送循环直接运行二进制**：
  在 `sendViaMiniAppRustWorker()` 函数中，将命令执行逻辑改写为**优先调用 `prepared.binaryPath`**（直接传入 `--job-file jobPath` 参数），不再传入 `cargo run`。如遇特殊异常导致直接运行二进制失败，再降级回退到 `cargo run --release`。
  这一修改将任务启动的开销从数百毫秒/高 CPU 降至 1~5 毫秒/极低 CPU。

## 3. 任务分解与开发计划
1. **任务 1**：修改 `global-dharma-send-service.ts`，扩展 `PreparedWorker` 类型定义，实现 `cargo build --release` 预编译逻辑与直接运行二进制的可执行文件调度机制。
2. **任务 2**：重构 `GlobalDharmaApp.tsx` 结构与样式，将原 `.miniapp-*` 替换并适配至 `.ma-*` 和 `miniapps.css` 规范样式体系。
3. **任务 3**：自动化测试与验证，运行 `npm run build` 或项目检查指令确保没有 TypeScript 和语法错误，更新文档。
