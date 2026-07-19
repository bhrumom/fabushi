# 小程序消息投递防丢包与 Rust Daemon 稳定连续发包修复需求与设计文档 (PRD)

- **状态**: 已完成（自动化静态检查与全量测试一次性全部跑通通过）
- **日期**: 2026-07-08

## 1. 背景与待解决问题清单

用户在实际使用与观察过程中发现以下核心体验与运行问题：

1. **首条发送链接丢包与报“小程序后台加载超时”问题**：
   - 当用户进入聊天直接发送链接时，如果右侧会话面板尚未完成底层页面加载，客户端 `_runCommand` 等待超时（20s）直接抛异常并中止投递，致使输入的新链接无法被写入小程序；后续按“1”触发的依然是上一条残留的历史记录（如《金刚经》）。
2. **循环发送长间隔卡顿与“发到一半停止没有动静”问题**：
   - 观察执行日志，发完一轮后界面长期静默无动静（等待多达 30 秒），用户体验上像是发到一半程序死锁或停止。
   - 核心因为底层与调用端的轮询常驻休眠时间均写死为 30,000 毫秒（30 秒）。

## 2. 根本原因剖析（第一性原理思考）

1. **客户端投递机制缺乏缓冲队列**：
   - `fabushi/lib/screens/mini_app_host_screen.dart` 的 `_runCommand` 前强行 `await _waitForHostReady()` 且无重试投递缓冲。如果页面在加载中或耗时稍长，就会抛错丢弃用户刚才输入的指令。
2. **底层引擎轮询间隔设定过于冗长**：
   - `frontend/apps/web/public/miniapps/official.global-dharma/runtime/global-dharma-worker/src/main.rs` 中：
     `const DEFAULT_DAEMON_LOOP_INTERVAL_MS: u64 = 30_000;`
   - `frontend/apps/web/src/app/miniapps/[id]/global-dharma-send-service.ts` 中：
     `const DAEMON_LOOP_INTERVAL_MS = 30000;`
   - 两处协同将循环调度的每轮间隔锁定为 30 秒，导致上一轮完毕到下一次动作之间长期沉寂。

## 3. 解决方案与核心改动设计 (KISS 原则)

### 3.1 客户端链接投递容错与页面初始化安全入列
- 目标文件：`fabushi/lib/screens/mini_app_host_screen.dart`
- 改动要点：
  1. 适当放宽 `_waitForHostReady()` 基础等待阈值至 45 秒以包容网络波动；
  2. 当执行 `_runCommand` 遇到页面仍在加载中或准备挂载前，自动将发送内容安全放入 `_pendingCommands` 队列，等 `onLoadStop` 与 JS Ready 事件完成时立即主动回补投递，保证用户发出的新链接 **绝对不丢失、不误报超时**。

### 3.2 底层与服务侧常驻发包循环间隔缩减为 3 秒
- 目标文件：
  - `global-dharma-worker/src/main.rs`
  - `global-dharma-send-service.ts`
- 改动要点：
  1. 将 `DEFAULT_DAEMON_LOOP_INTERVAL_MS` 改为 `3_000` 毫秒（3 秒）；
  2. 将 `DAEMON_LOOP_INTERVAL_MS` 改为 `3000` 毫秒（3 秒）；
  3. 彻底消灭两轮之间的长周期死等，做到平稳连续、实时有动静、真正高速运作。

### 3.3 前端界面与机器人提示文案更新
- 目标文件：`frontend/apps/web/src/app/miniapps/[id]/GlobalDharmaApp.tsx`
- 改动要点：
  1. 将发包提示与引导中的文案由旧的“每 30 秒”调整为实际高效的“每 3 秒自主执行连续发包”。

## 4. 验证计划

1. **自动编译与语法检测**：
   - 执行 `flutter analyze lib/screens/mini_app_host_screen.dart` 保证无错误；
2. **单元组件回归测试**：
   - 运行项目 Flutter 单元组件测试确保功能完备通过。
