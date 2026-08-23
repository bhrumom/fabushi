# 2026-08-23 MiniApp AI 客服电话需求

## 用户原始需求

每一个 MiniApp 都可以发起类似 10086 客服电话的服务会话：

1. 支持传统 IVR/DTMF 数字按键，按菜单逐级选择并执行服务。
2. 支持 AI 语音理解：用户可直接口头描述需求，由 AI 识别意图并触发 MiniApp 对应能力。
3. 电话双方的内容需要实时同步到现有聊天界面，形成可持续查看的会话记录。
4. 除语音/按键外，用户也可以直接通过现有聊天输入文字驱动同一个 MiniApp。
5. 该能力必须复用 Fabushi 统一 Conversation/Message、Mini App 权限桥和 realtime call 基础，不新建第二套消息、联系人或 Bot 通道。

## 规范化约束

- MiniApp 电话是一种 `MiniApp Service Call`，不是传统 PSTN 电话号码系统；后续可通过适配器接 PSTN/SIP，但核心协议保持 Fabushi 自有。
- DTMF、实时语音转写、聊天文字统一归一化为同一组 service-call input。
- AI 意图解析与动作执行必须经过 MiniApp capability/permission 检查，不允许模型绕过授权直接调用宿主能力。
- 实时转写使用统一 Conversation 作为审计与 UI 展示载体；不得维护隐藏的第二份聊天历史作为权威状态。
- 麦克风原始音频、转写内容、意图与动作结果遵循最小化存储和明确授权原则。

## 本轮落地目标

先完成 Rust 核心领域契约、MiniApp bridge 请求类型、权限边界、状态机与单元测试，并为后续 Electron/iOS/Android UI、实时 STT、AI intent resolver、WebRTC/SIP/PSTN adapter 和 E2E 建立稳定协议基线。
