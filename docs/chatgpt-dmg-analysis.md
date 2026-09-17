# ChatGPT DMG 行为分析记录

这份记录只描述从本机 ChatGPT 安装包观察到的交互行为和组件边界，用来指导 Fabushi 的等价实现。没有把 ChatGPT 安装包中的私有源码、私有资源、密钥或二进制文件复制进 Fabushi，也不把反编译产物当作项目源码。

## 分析范围

- 安装包：/Users/gloriachan/Downloads/ChatGPT.dmg
- 观察对象：Electron/Chromium 容器、渲染层资源、会话页和 Bot/Agent 会话相关模块。
- Fabushi 落点：仓库主线的 desktop/、mobile/android/、mobile/ios/ 和共享 Mahayana Host 事件协议。
- 明确排除：历史 Flutter 客户端及其源码，不恢复、不迁移、不参与本次设计。

## 提炼出的 Bot 会话模型

1. 每个 Bot 是一个稳定的会话身份。切换 Bot 只切换会话投影，不会清空其他 Bot 的消息。
2. 发送消息先显示用户消息，再为同一个 assistant 消息接收增量输出；增量结束后消息从 streaming 状态转为普通消息。
3. 思考、工具调用、模型路由和其他过程状态是独立的时间线条目，不伪装成最终答案。
4. 输入框有独立草稿；会话切换和重新打开不会覆盖其他会话的草稿。
5. 运行期间可以停止；停止后会结束当前运行状态，但保留已经显示的过程和答案。
6. 消息支持复制、编辑后重试、重新生成等局部操作；操作浮层只在需要时出现，不打断阅读。
7. 内容区是连续的文档流：助手消息不使用传统聊天气泡承载长答案，支持 Markdown、代码块、链接和可复制代码。
8. 用户靠近底部时自动跟随新内容；用户向上阅读历史时不强行跳回底部，并提供回到最新位置的入口。
9. 会话、草稿和运行中的消息需要可恢复；渲染层不能把内存中的数组当成唯一数据源。

## 映射到 Fabushi 主线

| DMG 中的行为 | Fabushi 主线实现位置 |
| --- | --- |
| 单 Bot 独立会话文档流 | desktop/src/bot-conversation-view.tsx |
| Markdown、代码块和消息局部操作 | desktop/src/bot-conversation-view.tsx |
| 过程条目、增量输出、可停止 | desktop/src/messaging-shell-v2.tsx 与 Mahayana Host 事件 |
| Electron 会话及消息日志 | frontend/apps/web/src/lib/mahayana-host/electron-transport.ts |
| 原生 Android Bot 会话 | mobile/android/app/src/main/java/com/ombhrum/fabushi/MobileBotViewModel.kt |
| 原生 iOS Bot 会话 | mobile/ios/Fabushi/GrokMobileShell.swift |

本次改造的目标是“行为等价”和“体验一致”，不是把第三方安装包的私有实现直接嵌入 Fabushi。这样可以保持当前 Electron + 原生移动端架构，同时继续使用 Fabushi 自己的 Host、鉴权、路由和数据持久化。
