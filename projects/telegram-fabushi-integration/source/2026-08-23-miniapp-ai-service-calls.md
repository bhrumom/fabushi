# 2026-08-23 MiniApp AI 客服电话需求

## 用户原始需求

每一个 MiniApp 都可以发起类似 10086 客服电话的服务会话：

1. 支持传统 IVR/DTMF 数字按键，按菜单逐级选择并执行服务。
2. 支持 AI 语音理解：用户可直接口头描述需求，由 AI 识别意图并触发 MiniApp 对应能力。
3. 电话双方的内容需要实时同步到现有聊天界面，形成可持续查看的会话记录。
4. 除语音/按键外，用户也可以直接通过现有聊天输入文字驱动同一个 MiniApp。
5. 该能力必须复用 Fabushi 统一 Conversation/Message、Mini App 权限桥和 realtime call 基础，不新建第二套消息、联系人或 Bot 通道。

## 2026-08-23 用户补充：所有业务驱动必须经过 MCP

用户进一步明确以下强约束，优先级高于本文件较早描述：

1. MiniApp 客服电话中的业务功能**不是由 AI、IVR、聊天输入或宿主代码直接执行**，而是统一通过该 MiniApp 暴露/绑定的 MCP 接口执行。
2. AI 的职责是理解自然语言、在当前 MiniApp 已声明且已授权的 MCP capabilities/tools 中选择目标工具并构造参数，然后由 MCP 执行层真正调用功能。
3. 如果当前 MiniApp 没有暴露与用户需求对应的 MCP capability/tool，则 AI 必须明确返回“该功能不可用/未提供”，不得绕过 MCP、不得臆造功能、不得调用无关宿主能力完成同等动作。
4. DTMF/IVR 数字选择也是 MCP 驱动：菜单项必须确定性映射到当前 MiniApp 的 MCP tool/action；按键本身不直接执行本地业务逻辑。
5. 用户在聊天框发送数字（例如 `1`、`2`、`0`）时，与电话拨号盘输入完全一致，走同一 DTMF/IVR -> MCP 路由。
6. 用户在聊天框发送自然语言、电话中说自然语言时，都走同一个自然语言 -> MCP capability 解析/选择 -> MCP 调用管线。
7. MCP capability 是功能可用性的唯一业务能力边界；MiniApp capability/permission 检查除 Fabushi 宿主权限外，还必须验证目标 MCP tool 确实属于当前 MiniApp 并处于可用/授权状态。
8. 实际 MCP 调用结果需要投影回同一个 Conversation/Message，并可作为语音回复、界面结果和审计记录的来源。

## 规范化约束

- MiniApp 电话是一种 `MiniApp Service Call`，不是传统 PSTN 电话号码系统；后续可通过适配器接 PSTN/SIP，但核心协议保持 Fabushi 自有。
- DTMF、实时语音转写、聊天文字统一归一化为同一组 service-call input。
- **所有会产生业务状态变化或业务查询结果的 MiniApp action 必须通过 MCP 执行层；AI/IVR/聊天层只负责解析、路由和参数准备。**
- AI 意图解析必须严格受当前 MiniApp 已注册 MCP tool catalog 约束，不允许模型绕过 MCP 或授权直接调用宿主能力。
- 实时转写使用统一 Conversation 作为审计与 UI 展示载体；不得维护隐藏的第二份聊天历史作为权威状态。
- 麦克风原始音频、转写内容、MCP tool 选择/参数与调用结果遵循最小化存储和明确授权原则。

## 本轮落地目标

修正 Rust 核心领域契约，使 service-call action 不再抽象为可直接执行的 AI action，而是显式建模为 MiniApp MCP capability/tool selection + MCP invocation request/result；同时建立 DTMF、聊天数字、语音、聊天自然语言四种入口统一进入 MCP 路由的协议基线，并补充“无对应 MCP 功能必须拒绝”的单元/契约测试。后续 Electron/iOS/Android UI、实时 STT、MCP host executor、WebRTC/SIP/PSTN adapter 和 E2E 在此契约上继续落地。
