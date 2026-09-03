# GBF-507 Acceptance Traceability

| Requirement | Source | Implementation | Verification | Evidence | State |
|---|---|---|---|---|---|
| Bot 不能只做单轮对话，必须多步骤工作 | 2026-08-25 user continuation | Legacy `chat.send` is forced to `mode=agent`; Rust self-hosted messaging emits `botInvocationRequested` and desktop routes it into the single Mahayana runtime | exact-main real Rust Host Playwright; self-hosted Bot Workbench journey >=3 nodes | PR #2112; Electron `32805236227`; Messaging `32805236171` | RELEASED |
| 使用现有 Mahayana，不建立第二 runtime | original Grok fusion requirement | all execution uses Electron Mahayana edge / Rust AppHost; self-hosted Bot projection executes on canonical `mahayana-assistant` | architecture/Feature Host/Messaging gates | `32805007346`, `32805236171`, `32805236227` | RELEASED |
| 展示规划、步骤、工具和结果 | 2026-08-25 user continuation | Agent Workbench projects runtime lifecycle, steps, tools, cards and output | exact-main run/step/output assertions and packaged journeys | `mahayana-agent-workbench.spec.ts`; `32805236227` | RELEASED |
| 会话内完成审批并继续 | Grok observable behavior | approval cards invoke `feature.approval.resolve`; interrupt/resume remain Mahayana Host actions | renderer/Host contracts + exact-main full Electron suite | PR #2108..#2112; `32805236227` | RELEASED |
| 子智能体与后台任务可观察 | Grok observable behavior | `subagent.*`, `asyncTask.*`, `agent.background*` projections | reducer/event contracts + exact-main full suite | Workbench reducer; `32805236227` | RELEASED |
| 动态头像随真实运行状态变化 | original dynamic avatar requirement | runtime events map to shared `BotMarkState`; active peer/Header/profile share current run state | motion contracts + Playwright result-state assertion + packaged visual evidence | `#mahayana-agent-header-avatar [data-agent-state=result]`; `32805236227` | RELEASED |
| 会话/运行重启后不消失 | 2026-08-25 user continuation | bounded run/conversation journals + Host/local reconcile; in-flight runs become interrupted/resumable | close/relaunch same app-data journey on real Host | PR #2111/#2112; `32805236227` | RELEASED |
| 可停止、恢复失败或中断任务 | Grok observable behavior | interrupt and resume actions remain within Mahayana permission/runtime boundary | `feature.interrupt`/`feature.execute` contracts + exact-main suite | task A6; `32805236227` | RELEASED |
| Self-hosted Bot 不得绕过消息身份安全 | current implementation safety requirement | authenticated human message remains in Rust store; Renderer consumes `botInvocationRequested` but never sends as Bot | Rust producer test + existing actor-impersonation rejection + Electron consumer E2E | Messaging `32805007346`; Electron `32805236227` | RELEASED |
| 视觉接近 Grok 运行工作台，同时保持 Fabushi 所有权 | original UI fusion requirement + provenance policy | Fabushi React/CSS/Motion implementation; no vendor renderer/assets | source/provenance audit + packaged screenshots/video/trace | Grok parity CSS/Workbench + Electron artifacts `32805236227` | RELEASED FOR GBF-507 SURFACE |
| 最终变更进入 main 并由安装包旅程验证 | repository completion gate | protected merge + exact-main package/E2E + Release | Linux/Windows/macOS packaged journeys; Android/iOS simulated-user journeys; immutable Release | main `e2332b09475f1032567b27d454c45b3801cbd9c5`; Electron `32805236227`; Native `32805236162`; Release `desktop-1.0.896` | RELEASED |

## Acceptance decision

`GBF-507` is **RELEASED** for product SHA `e2332b09475f1032567b27d454c45b3801cbd9c5`, published as **Fabushi Desktop 1.0.896**.

The acceptance is deliberately scoped: it closes the user-visible Grok-style Mahayana Agent Workbench, self-hosted Bot-to-Mahayana bridge, runtime-state avatar projection, conversation/run restart behavior and this Release. `GBF-601` and `GBF-602` remain `IN_PROGRESS` because the local journals are recovery/first-frame projections rather than the final Rust canonical conversation/run checkpoint store; `GBF-805` remains the broader 0.18 reconstructed observable-parity closure.
