# 2026-08-27 MiniApp 自定义 Bot 通话与口播小程序需求

## 用户原始目标

每一个 MiniApp 都拥有其对应 Bot；该 Bot 顶部的“语音通话 / 视频通话”不是 Fabushi 写死的业务流程，而必须成为 **由该 MiniApp 自己声明和设计的入口**。

### 1. MiniApp 完全定义自己的 Bot 通话程序

- MiniApp 可以分别定义点击语音通话、视频通话后启动什么流程、什么界面、什么默认功能。
- 语音通话可以像 10086 一样使用固定 IVR：播报提示、等待 `0-9*#`、按数字进入下一菜单、调用能力、返回上级或退出。
- MiniApp 可以把按钮、数字、菜单、退出、默认动作和界面组件组合成自己的固定程序。
- Fabushi 不应把某一种客服电话流程写死到宿主；宿主只提供统一的媒体、权限、AI、MCP、Conversation/Message、存储与安全边界。
- 没有为某个 MiniApp 声明通话程序时，不得凭空构造该应用的业务流程。

### 2. AI 是平台增强层，固定流程必须可脱离 AI 工作

- AI 语音能力由 Fabushi 提供，可以动态理解用户自然语言。
- AI 只能在当前 MiniApp 已声明且已授权的 MCP Tool catalog 中选择能力与参数；真正业务执行继续统一走该 MiniApp 的 MCP `tools/call`，不得绕过 MCP。
- 当用户有 AI 额度/AI 可用时，可以直接说“我要办理什么”，AI 将意图映射为该 MiniApp 已存在的 MCP 功能。
- 当 AI 无额度、不可用或被用户关闭时，MiniApp 的固定 IVR/按钮流程必须仍能完整运行；用户通过听提示和输入数字一步步完成服务。
- AI 不可用不能让固定业务流程失效；固定流程也不能成为绕过权限、审批、支付确认或 MCP 的第二业务执行通道。

### 3. 同一 Bot / 同一 Conversation

- 通话、DTMF、聊天数字、聊天自然语言、实时转写、MCP 结果继续绑定该 MiniApp Bot 的同一个 `ConversationId`。
- 退出通话后仍可在同一个聊天页继续查看记录并用文字驱动 MiniApp。
- 通话产生的最终媒体（例如录制视频）也应成为这个 Conversation 中可查看/播放的消息，而不是隐藏在另一套数据库或临时页面。

## 独立口播 MiniApp

新增一个可安装、可搜索、可独立分发的“口播 / 提词器录制” MiniApp，并为它创建所属 Bot。

### Bot 视频通话体验

1. 用户进入口播 MiniApp Bot 会话，点击“视频通话”。
2. 视频通话打开摄像头与麦克风；视频画面是主舞台。
3. 摄像头画面周围/上方显示由口播 MiniApp 自己提供的通话 UI，而不是宿主固定 UI。
4. 用户可粘贴、编辑或选择口播提示词；提示词以提词器形式覆盖在自拍视频前方。
5. 提供适合口播的字体大小、滚动速度、开始/暂停滚动、回到开头等本地控制。
6. 点击“开始录制”后，以摄像头 + 麦克风进行录制，同时继续显示提词器供用户朗读。
7. 点击“结束录制”后停止媒体轨道、生成视频文件并自动保存。
8. 保存成功后，把视频作为该 MiniApp Bot Conversation 的视频消息插入聊天；用户在对话页可直接看到并播放。
9. 录制必须有明确 Camera/Microphone 权限；保存到会话应使用 Fabushi 统一媒体/消息通道，不把任意本地路径或未授权文件暴露给 MiniApp。

## 兼容与非目标

- 普通联系人之间现有 1:1 WebRTC 语音/视频通话行为保持不变；只有关联 MiniApp Bot 且声明了 call program 时由 MiniApp 接管对应通话入口。
- 本轮不要求接入真实 PSTN 号码；10086 只作为固定 IVR 用户体验参考。未来 SIP/PSTN 仍作为 adapter。
- 不把 Asterisk 等 GPL 电话服务器源码复制到 Fabushi；可学习成熟 IVR 状态机和 DTMF 设计。
- 不为口播引入不必要的第三方录制依赖；优先使用平台标准媒体能力并通过 Fabushi Host 安全桥保存。

## 验收底线

- MiniApp manifest 能明确声明 voice/video call program，并在 Marketplace -> Bot projection -> Messenger 中不丢失。
- MiniApp Bot 的语音/视频按钮根据 manifest 选择 MiniApp 程序；普通联系人仍走原 WebRTC。
- 固定 IVR 在 AI 不可用时仍能确定性地路由到当前 MiniApp MCP Tool。
- AI 路由只能选择当前 MiniApp MCP catalog 中的 Tool；无 Tool 时明确 unavailable。
- 口播 MiniApp 的视频通话可打开摄像头、显示/滚动提词、开始/结束录制、保存并把视频回投同一 Conversation。
- 权限拒绝、无摄像头、MediaRecorder 不支持、录制失败、保存失败必须可恢复并向用户显示明确状态。
- canonical-main packaged E2E 必须保留完整截图、视频、trace/report，并最终从同一 main SHA 发布 Release 后才可宣称完成。
