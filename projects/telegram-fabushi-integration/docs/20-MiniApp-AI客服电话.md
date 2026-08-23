# 20 — MiniApp MCP / AI 客服电话

## 1. 产品目标

让任意获得授权的 Fabushi MiniApp 具备“客服电话”交互面：用户可以像拨打 10086 一样按数字逐级选择，也可以直接说出需求让 AI 理解，还可以退出语音后继续在同一聊天里打字。

这些输入不是三套业务系统。它们都进入同一个 `MiniAppServiceCallSession`，并最终受同一个 MiniApp MCP Tool catalog 约束。

**AI 不负责真正执行 MiniApp 功能。所有业务查询/修改都只能通过当前 MiniApp 暴露的 MCP `tools/call` 执行。MiniApp 没有对应 MCP Tool 时，该功能就是不可用。**

## 2. 核心体验

### 2.1 发起

在 MiniApp/其关联服务会话中点击“电话”后：

1. 创建 `MiniAppServiceCallSession`；
2. 绑定现有 `ConversationId`；
3. voice/hybrid 模式请求 `ServiceCall + Microphone` 权限；
4. Host 通过目标 MiniApp 的真实 MCP session 执行 `tools/list`，形成当前 service-call 的 Tool catalog snapshot；
5. 加载该 MiniApp 声明的 DTMF/IVR → MCP Tool route；
6. 进入 connecting → active；
7. UI 可显示拨号盘、静音、免提/音频设备、实时字幕与挂断。

### 2.2 IVR / 数字按键

电话拨号盘 DTMF `0-9*#` 不直接执行本地函数，也不交给 LLM 猜测。它按当前菜单状态确定性映射为：

`digits -> MiniApp MCP Tool + arguments -> tools/call`

例如：

- `1` → `query_allowance`
- `2` → `change_plan`

路由只能引用当前 MiniApp `tools/list` 实际暴露的 Tool。如果 route 指向不存在的 Tool，service-call contract 必须拒绝。

### 2.3 聊天框发送数字

用户在绑定 Conversation 的 composer 发送 `1`、`2`、`0`、`*`、`#` 等纯 DTMF 字符时，不进入自然语言 Agent backend，而是与电话拨号盘完全共用同一 DTMF → MCP route。

因此“按电话上的 1”和“聊天里发 1”必须得到同一个 MCP Tool 调用语义。

### 2.4 AI 语音

音频由客户端/Host media 层采集并做 streaming STT：

- interim transcript 立即生成 `AppendConversationTranscript(final=false)`，用于聊天 UI 的实时字幕；
- final transcript 生成 `AppendConversationTranscript(final=true)`；
- final transcript 进入 `ResolveMcpTool`，resolver 只获得当前 MiniApp 的 Tool catalog；
- resolver 只能从 catalog 中选择 Tool 并构造 arguments；
- Rust domain 再次验证被选 Tool 确实属于该 catalog；
- 验证后才生成 `InvokeMcpTool`，由 Host 走现有 MCP `tools/call` runtime；
- MCP result 再作为 spoken response / display response / audit metadata 回投同一 Conversation。

如果当前 Tool catalog 没有能满足请求的 Tool，则 resolver 必须返回 unavailable，UI 明确告诉用户该 MiniApp 未提供此功能。禁止让通用 AI、宿主 native capability 或其它 MiniApp 代为完成。

### 2.5 聊天自然语言

用户在 composer 输入自然语言时，内容归一化为 `ChatText`，进入与 final speech 完全相同的 `ResolveMcpTool -> InvokeMcpTool -> tools/call` 管线。

这样同一个需求可以在电话中说，也可以在聊天里输入；唯一业务执行面仍然是目标 MiniApp 的 MCP。

## 3. Rust 领域模型

权威实现：`native/mahayana-messaging/src/miniapp_service_call.rs`。

核心对象：

- `MiniAppServiceCallId`
- `MiniAppServiceCallSession`
- `MiniAppServiceCallMode` (`voice|text|hybrid`)
- `MiniAppServiceCallState`
- `MiniAppServiceCallInput` (`dtmf|speechTranscript|chatText`)
- `MiniAppMcpToolCapability`
- `MiniAppMcpDtmfRoute`
- `MiniAppMcpResolveRequest`
- `MiniAppMcpToolResolution`
- `MiniAppMcpInvocationRequest`
- `MiniAppMcpInvocationResult`
- `MiniAppServiceCallEffect`

Session 记录 MiniApp、caller、Conversation、可选 service actor、MCP Tool catalog snapshot、DTMF routes、turns、MCP results 与生命周期时间，保证可审计和跨端恢复。

## 4. MCP 是唯一业务执行面

现有 Fabushi MCP Apps runtime 已使用：

- `tools/list`：获取应用真实 Tool catalog；
- `tools/call`：调用目标 Tool；
- Tool annotations：`readOnlyHint`、`destructiveHint`、`openWorldHint`；
- bridge grants / approval / sensitive-input：用于权限与高风险交互。

MiniApp Service Call 不新增第二套业务 RPC。它只负责把各种输入归一化、选择/路由 MCP Tool，再复用已有 MCP runtime。

### 4.1 AI 的职责

AI 可以：

- 理解用户自然语言；
- 在给定 Tool catalog 内做 tool selection；
- 根据 Tool `inputSchema` 构造参数；
- 当没有匹配 Tool 时解释“当前 MiniApp 不支持此功能”。

AI 不可以：

- 自己创造不存在的 Tool；
- 绕过 MCP 直接调用宿主 native capability；
- 发现 MiniApp 没功能后转而使用通用 Agent 帮用户完成同等业务；
- 把一次自然语言理解视为高风险操作的授权。

### 4.2 Defense in depth

Tool selection 后领域层仍做第二次校验：

1. tool name 必须在该 service-call snapshot 中；
2. DTMF route 必须引用 snapshot 中 Tool；
3. Host executor 必须绑定同一 `mini_app_id` / MCP session；
4. write/destructive/open-world Tool 继续走现有审批/授权；
5. 授权撤销、Tool 移除、MCP 错误或超时都不得 fallback 到非 MCP 路径。

## 5. 与现有系统的边界

- **Conversation/Message**：唯一聊天与审计载体；不新增客服专用聊天数据库。
- **MiniApp**：manifest/grant/session/capability 权限边界。
- **MCP Apps runtime**：唯一 MiniApp 业务执行面，复用 `tools/list` / `tools/call`。
- **Realtime / signaling**：复用 M10 的 WebRTC/signaling/ICE/TURN；service call 不再造媒体栈。
- **Bot/Agent**：仅可作为受约束的 Tool resolver/语言理解 runtime；不能作为 MiniApp 业务 fallback executor。
- **Payment**：若 Tool 涉及支付，仍走现有 invoice/order/payment 授权流程，语音识别或 Tool selection 不能自行绕过支付确认。

## 6. 消息投影

`AppendConversationTranscript` 用于把用户输入实时投影到统一 Conversation；MCP result 后续也必须投影为同一 Conversation/Message。

建议 UI 行为：

- interim speech：只更新当前临时字幕，不生成大量永久消息；
- final speech：生成/更新最终 transcript message；
- DTMF / 聊天数字：以轻量 service event 或可读文本显示用户选择；
- MCP 调用中：可显示“正在办理”；
- MCP result：由关联 MiniApp service actor 写入同一 Conversation；
- unavailable：明确显示“该 MiniApp 未提供对应功能”；
- Tool name/arguments/result metadata 可用于审计，普通用户主要看到自然语言结果。

## 7. 安全与隐私

- `ServiceCall` 是独立能力；voice/hybrid 与 speech 输入额外要求 `Microphone`。
- Tool catalog 必须来自该 MiniApp 的真实 `tools/list`，不能让模型伪造。
- 默认不永久保存原始音频；永久记录以 final transcript、必要 MCP invocation audit 和业务结果为主。
- STT/LLM provider 若为外部服务，必须在后续 ADR 明确数据出境、保留策略与可替换接口。
- 高风险 Tool（支付、删除、账户安全、隐私授权等）必须保留独立确认；“模型理解到意图”不等于授权。
- DTMF、chat、speech、MCP invocation 都要做速率限制、输入长度限制、session ownership、replay/idempotency 和授权撤销检查。

## 8. 后续原子任务

1. `M8-CALL-002`：host-side streaming STT adapter + transcript projection。
2. `M8-CALL-003`：真实 `tools/list` catalog snapshot + constrained AI MCP Tool resolver + `tools/call` Host executor + MCP result → Conversation projection。
3. `M8-CALL-004`：chat composer → service-call routing；纯数字走 DTMF/MCP，自然语言走 MCP resolver。
4. `M10-CALL-001`：WebRTC media session 与 service-call session 绑定；如需真实电话网络再加 SIP/PSTN adapter。
5. `M8-CALL-005`：Electron 拨号盘/实时字幕/MCP 办理状态/通话控制 UI。
6. `M11-CALL-001`：iOS/Android 原生 UI 与 Rust bridge。
7. `M8-CALL-006`：跨端 E2E，覆盖 DTMF→MCP、聊天数字→同 route、语音/文字→MCP、无 Tool 拒绝、权限撤销、MCP 错误恢复和高风险确认。

## 9. 本轮完成边界

`M8-CALL-001` 只在 Rust domain + MiniApp bridge 建立 MCP-only 稳定契约。实际 STT、constrained LLM resolver、生产 MCP Host executor、媒体网络、UI 与 E2E 未有通过证据前，不得宣称“完整客服电话功能已完成”。
