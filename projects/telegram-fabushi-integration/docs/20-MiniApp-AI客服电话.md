# 20 — MiniApp AI 客服电话

## 1. 产品目标

让任意获得授权的 Fabushi MiniApp 具备“客服电话”交互面：用户可以像拨打 10086 一样按数字逐级选择，也可以直接说出需求让 AI 理解并执行，还可以退出语音后继续在同一聊天里打字。三种交互不是三套系统，而是同一个 MiniApp Service Call 会话的不同输入方式。

## 2. 核心体验

### 2.1 发起

在 MiniApp/其关联服务会话中点击“电话”后：

1. 创建 `MiniAppServiceCallSession`；
2. 绑定现有 `ConversationId`；
3. voice/hybrid 模式请求 `ServiceCall + Microphone` 权限；
4. 进入 connecting → active；
5. UI 可显示拨号盘、静音、免提/音频设备、实时字幕与挂断。

### 2.2 IVR / 数字按键

DTMF `0-9*#` 进入 `RouteDtmf` effect，由 MiniApp 的确定性菜单/状态机解释。例如“1 查余额、2 改套餐”。DTMF 默认不交给 LLM，避免 AI 把确定性菜单变成概率行为。

### 2.3 AI 语音

音频由客户端/host media 层采集并做 streaming STT：

- interim transcript 立即生成 `AppendConversationTranscript(final=false)`，用于聊天 UI 的实时字幕；
- final transcript 同时生成 `AppendConversationTranscript(final=true)` 与 `ResolveIntent`；
- intent resolver 根据 MiniApp 声明的 capabilities 生成结构化 action；
- action executor 再做权限、参数、幂等与高风险确认检查后调用 MiniApp；
- 结果可同时产生 spoken response 和 display response。

模型只负责理解/规划，不能绕过 capability bridge 直接操作宿主。

### 2.4 聊天文字

用户在绑定 Conversation 的现有 composer 输入文字时，MiniApp routing 层将内容归一化为 `ChatText`，进入与 final speech 完全相同的 `ResolveIntent` 管线。因此同一件事可以“说一半后改成打字”，历史和状态保持连续。

## 3. Rust 领域模型

权威实现：`native/mahayana-messaging/src/miniapp_service_call.rs`。

核心对象：

- `MiniAppServiceCallId`
- `MiniAppServiceCallSession`
- `MiniAppServiceCallMode` (`voice|text|hybrid`)
- `MiniAppServiceCallState`
- `MiniAppServiceCallInput` (`dtmf|speechTranscript|chatText`)
- `MiniAppServiceCallEffect`
- `MiniAppServiceActionRequest`
- `MiniAppServiceActionResult`

Session 必须记录 MiniApp、caller、Conversation、可选 service actor、turns、action results 与生命周期时间，保证可审计和跨端恢复。

## 4. 与现有系统的边界

- **Conversation/Message**：唯一聊天与审计载体；不新增客服专用聊天数据库。
- **MiniApp**：manifest/grant/session/capability 权限边界。
- **Realtime / signaling**：复用 M10 的 WebRTC/signaling/ICE/TURN；service call 不再造媒体栈。
- **Bot/Agent**：AI intent resolver/action executor 可复用统一 Agent runtime，但执行对象仍受 MiniApp capability 限制。
- **Payment**：若语音意图触发支付，仍走现有 invoice/order/payment 授权流程，语音识别结果不能自行绕过支付确认。

## 5. 消息投影

本轮核心输出 `AppendConversationTranscript` effect，后续 service adapter 将其投影为统一 Conversation/Message 事件。建议 UI 行为：

- interim：只更新当前临时字幕，不生成大量永久消息；
- final：生成/更新最终 transcript message；
- service/AI 回复：由关联 MiniApp service actor 写入同一 Conversation；
- action result：可附带 intent/action metadata 供审计，但普通用户只看到自然语言结果。

## 6. 安全与隐私

- `ServiceCall` 是独立能力；voice/hybrid 与 speech 输入额外要求 `Microphone`。
- 默认不永久保存原始音频；永久记录以 final transcript 和必要 action audit 为主。
- STT/AI provider 若为外部服务，必须在后续 ADR 明确数据出境、保留策略与可替换接口。
- 高风险动作（支付、删除、账户安全、隐私授权等）必须保留独立确认，不允许“模型理解到意图”直接等价于授权。
- DTMF、chat、speech 都要做速率限制、输入长度限制、session ownership 和 replay/idempotency 保护。

## 7. 后续原子任务

1. `M8-CALL-002`：host-side streaming STT adapter + transcript projection。
2. `M8-CALL-003`：AI intent resolver + MiniApp capability/action executor。
3. `M8-CALL-004`：chat composer → MiniApp service-call text routing。
4. `M10-CALL-001`：WebRTC media session 与 service-call session 绑定；如需真实电话网络再加 SIP/PSTN adapter。
5. `M8-CALL-005`：Electron 拨号盘/实时字幕/通话控制 UI。
6. `M11-CALL-001`：iOS/Android 原生 UI 与 Rust bridge。
7. `M8-CALL-006`：跨端 E2E，覆盖 DTMF、语音 AI、文字切换、权限撤销、失败恢复和高风险确认。

## 8. 本轮完成边界

`M8-CALL-001` 只在 Rust domain + MiniApp bridge 建立稳定契约。实际 STT、LLM/intent provider、动作执行、媒体网络、UI 与 E2E 未有通过证据前，不得宣称“完整客服电话功能已完成”。
