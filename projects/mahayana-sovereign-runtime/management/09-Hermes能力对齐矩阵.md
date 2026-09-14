# Hermes → Mahayana 能力对齐矩阵

> 基线：Fabushi `387ae731c3677d9d3023d400f1da60d7ac958a4f`；Hermes `09b74dea642782da2bc24ecc3fafd340de8fc982`。
>
> 这张表是完成条件，不是营销清单。`已有` 只表示 Fabushi/Mahayana 已有等价能力；`本轮` 表示 MSR-107 正在把它接到统一 Gateway / transcript；`待办` 表示没有足够实现或证据，禁止声称“已完全融合 Hermes”。

| Hermes 能力域 | Hermes 参考语义 | Mahayana/Fabushi 当前承载 | MSR-107 | 后续完成条件 |
|---|---|---|---|---|
| 单一 Agent Core | Desktop/CLI/API 共用 Agent runtime | Mahayana Runtime/Agent/Tool/MCP 已是单一 Rust core | 保持，不引入 Hermes Python runtime | 持续 source-boundary 审计 |
| stdio JSON-RPC | TUI Gateway dispatcher | Mahayana CLI + FFI runtime | **本轮实现** `mahayana-gateway` bin | CI + 真实 prompt/event smoke |
| WebSocket Gateway | 与 stdio 同 dispatcher/event 语义 | Electron bridge 现有，但不是新 gateway contract | 待办 | Rust WS adapter + 同契约测试 |
| 多客户端 fanout | 一个 session 多连接；慢客户端隔离 | 现有 Electron/runtime channel | 待办 | bounded per-peer mailbox + slow-client E2E |
| seq/replay/replay_epoch | reconnect 精确补事件，截断必须 refetch | 旧 renderer journal/localStorage 非权威 | **本轮实现 Rust replay foundation** | WS/native client 接入 + reconnect E2E |
| session list/history | session.list/history | Mahayana conversation list/history 已有 | **本轮 stdio 暴露** | cross-surface contract |
| resume | 恢复会话 | Mahayana/Codex 已有 resume/history 能力 | 部分已有 | Gateway method + restart E2E |
| interrupt | session/turn interrupt | RuntimeCommand::Interrupt 已有 | **本轮 stdio 暴露** | desktop/mobile client parity |
| branch/fork | 从历史分叉会话 | 未证明等价 | 待办 | Rust canonical session branch + tests |
| rewind | 回退到历史 turn | 未证明等价 | 待办 | Rust store + provider mapping |
| compress | 压缩长会话上下文 | provider 侧存在部分机制 | 待办 | explicit gateway method + history proof |
| steer / queued follow-up | 运行中追加/转向 | 未证明等价 | 待办 | ordered turn command semantics |
| message.start/delta/complete | assistant stream | RuntimeEvent MessageDelta/MessageCompleted | **本轮统一投影** | Desktop 直接消费 gateway contract |
| message.interim | tool 前封口一段 assistant 文本，之后继续同 turn | Workbench messages 有多段能力，但无 canonical interim event | **UI 本轮保留中间 assistant segments** | Rust native interim event + contract/E2E |
| reasoning.delta | reasoning 独立 part | AgentActivity 可携 reasoning/thinking kind | **本轮映射为 reasoning.delta** | backend 真实 reasoning fixture + UI part |
| tool start/progress/complete | stable tool id 原位更新 | AgentActivity + PluginProgress + tool result 已有 | **本轮 gateway 映射** | desktop reducer 按 stable id upsert |
| approvals | request/response | Runtime approval bus 已有 | **本轮 gateway request + response method** | packaged allow-once/session/deny |
| clarify.request/response | 模型向用户澄清 | 未形成统一 RuntimeEvent | 待办 | Rust event + UI input continuation |
| secret.request/response | 安全秘密输入 | Mahayana secrets/vault 已有底座 | 待办 | 不泄露值的 gateway flow + security tests |
| usage/session stats | token/context | ModelUsageUpdated 已有 | **本轮 session.usage** | UI metadata/inspector parity |
| subagents/delegation | start/progress/complete | Mahayana/Codex structured activity 有部分投影 | UI 本轮作为 inline observation | Rust typed subagent events + tree E2E |
| async/background tasks | task lifecycle | Workbench observation/agent activity 部分支持 | UI 本轮保留 | typed gateway lifecycle + persistence |
| terminal/process | process create/output/exit/kill | Tool/command execution 已有 | 作为 tool activity 基础复用 | typed terminal methods/events + PTY E2E |
| MCP | server list/auth/tool call | `mahayana-mcp-runtime` 已有 | 复用，不造第二套 | gateway method parity + auth tests |
| Skills | skill install/use/list | Mahayana CLI Skill 已有 | 复用 | Hermes method/UX matrix验证 |
| Plugins/Mini Apps | app/tool/resource | Mahayana plugin/miniapp 已有且更深 | 复用 | 不回退现有 Marketplace/WebMCP 能力 |
| filesystem | read/write/search | Mahayana tools/workspace 已有 | 复用 | typed rich parts + policy evidence |
| artifacts/preview | 文件/预览作为 turn parts | cards/tool results 已有 | UI 本轮 inline artifact | canonical artifact part/event |
| browser/computer | 浏览器/电脑控制事件与截图 | Mahayana Computer Use / semantic agent 已有 | 复用执行层 | gateway typed events + live/takeover evidence |
| model selection/switch | model/provider configuration | Mahayana model routing 已有 | 隐藏“模型路由”作为聊天正文 | typed settings/method + UI controls |
| voice/wake | voice start/stop/wake | Fabushi 有 ASR/语音底座 | 待办 | Hermes-class event parity + packaged E2E |
| API/SSE | programmatic HTTP stream | 有服务端能力但未与本 gateway 统一 | 待办 | 同一 event contract 的 Rust HTTP/SSE adapter |
| ACP | editor/programmatic agent protocol | 未证明完整 | 待办 | adapter + conformance tests |
| Desktop transcript | Reasoning/Text/Tool 同一 Assistant turn | 旧 Workbench/InlineReport 大卡片 | **本轮改为无卡片 ordered parts + native final assistant message** | direct gateway reducer + packaged visual E2E |
| iOS transcript | 同协议同 turn | 原生 UI 有自己的工作流展示 | 待办 | Swift gateway event reducer + device E2E |
| Android transcript | 同协议同 turn | 原生 UI 有自己的工作流展示 | 待办 | Kotlin gateway event reducer + device E2E |
| Web/Chrome transcript | 同协议同 turn | Web/扩展目前独立消费 | 待办 | shared contract + browser E2E |
| authoritative persistence | session/turn/parts 重启可恢复 | Rust/cloud store + renderer projection 混合迁移中 | 本轮只做 replay foundation | Rust canonical part store + restart proof |
| install-and-use | 安装 App 后无需再装 Hermes/依赖包 | Fabushi 已打包 Mahayana Host/runtime | **硬约束：本轮不引入 Hermes/Python/Node runtime 依赖** | fresh installer/offline startup proof |

## MSR-107 本轮不可越权宣称的事项

本轮即使 PR、CI 和 packaged Desktop 全部通过，也只能证明“Rust Gateway + Desktop 同 turn transcript foundation”完成；以下仍必须保持 pending：WebSocket/fanout、完整 interim canonicalization、branch/rewind/compress、steer/queue、clarify/secret、完整 subagent/terminal typed protocol、browser/voice typed parity、HTTP/SSE、ACP、iOS/Android/Web/Chrome 消费，以及所有 Hermes 功能的最终跨平台矩阵关闭。

只有上表 required 行全部有实现、自动化和真实 packaged/device 证据后，项目状态才允许写“完全融合 Hermes”。