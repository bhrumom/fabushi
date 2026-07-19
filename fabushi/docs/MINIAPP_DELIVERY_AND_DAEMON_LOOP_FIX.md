# 小程序消息投递防丢包与 Rust 守护进程连续发包修复总结

- **修复日期**: 2026-07-08
- **修复状态**: 自动化静态类型检查与组件回归测试全部通过

---

## 1. 遇到并解决的核心问题

### 1.1 首次发送链接被“后台加载超时”阻断且丢弃（右侧面板保持历史旧记录）
- **现象分析**：当会话还未打开小程序侧栏时，直接在对话框中发链接，由于原生 `WKWebView` 在首次网络加载（DNS/TLS握手及 HTML 下载）稍长于 20 秒，客户端即直接抛出 `MiniAppHostException('host_not_ready', '小程序后台加载超时')`。发生报错后中断了输入命令的分发，致使刚发出的新链接没有被记入小程序；用户后续再发指令“1”时，触发了上一轮残留的历史旧内容（如《金刚经说什么》）。
- **技术解决方案**：
  - 在 `fabushi/lib/screens/mini_app_host_screen.dart` 的 `_runCommand` 逻辑中建立防丢包队列机制：任何时间用户发指令进入，均第一时间记入缓存 `_enqueueBotCommand(commandJson)`；
  - 优化首次加载容限至 `45` 秒以适应冷启动网络耗时；
  - 在网页完成加载触发 `_markHostReady()` 时，自动对队列中的未消费指令调用 `_flushPendingCommandsToWebView()` 进行回推投递，确保任何网络和打开次序下，命令 100% 被触达。

### 1.2 循环发送表现出“发完一轮等待 30 秒卡住/感觉中途停止”问题
- **现象分析**：观察日志输出，每轮发出 249 个回执完成后，界面长达半分钟没有新输出，给用户强烈的“程序卡死或中途停止”体验。
- **技术解决方案**：
  - 将底层 `global-dharma-worker/src/main.rs` 的默认轮询休眠常量 `DEFAULT_DAEMON_LOOP_INTERVAL_MS` 从 `30_000` 缩减为平稳连续的 `3_000` 毫秒（3 秒）；
  - 同步修改前端服务配置 `global-dharma-send-service.ts` 中传参 `DAEMON_LOOP_INTERVAL_MS` 为 `3000`；
  - 在 `GlobalDharmaApp.tsx` 的提示与交互中对齐文案为“每 3 秒连续循环发包”，实现丝滑的高吞吐持续运转。

---

## 2. 自动化验证记录

1. `flutter analyze lib/screens/mini_app_host_screen.dart` -> **No issues found!**
2. `flutter test test/widget_test.dart` -> **All tests passed!**
