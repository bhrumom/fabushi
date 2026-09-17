# GBF-806 — ChatGPT DMG Bot 单会话体验融合

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-806
- Stage: M5 UI / M6 transcript continuity
- Requirement IDs: GBR-002, GBR-003, GBR-007, GBR-008, GBR-019
- Status: IN_PROGRESS
- Source refs/files: source/2026-09-09-chatgpt-dmg-bot-session-parity.md；/Users/gloriachan/Downloads/ChatGPT.dmg
- Target branch: codex/chatgpt-bot-parity
- Target architecture: Electron + native iOS + native Android + Mahayana sovereign Rust runtime
- Risk tier: Medium；运行中断、跨会话状态和消息内容渲染需要 CI/E2E 复核
- Started: 2026-09-09
- Updated: 2026-09-09

## Objective

把 ChatGPT 安装包中可观察的 Bot 单会话交互模式，以 Fabushi 自有实现融合到当前 Electron 与原生移动端架构：每个 Bot 有独立 transcript，支持增量回复、运行过程、停止、排队、草稿、消息操作、Markdown 内容和跨次打开保留。

## In scope

- 从 DMG 提炼行为和组件边界，不复制私有源码、资源或二进制。
- Desktop Bot conversation document flow、按 Bot 隔离的 transcript、Markdown/code blocks、streaming cursor、thinking/action rows、copy/edit/regenerate、stop、queue、auto-scroll。
- Android/iOS 在当前原生 Bot 页面中保留每个 Bot 的 draft/transcript，并显示 streaming 状态。
- 将行为分析、开源调查、许可证结论和 Flutter 排除边界写入项目记录。

## Out of scope

- 恢复、迁移或修改历史 Flutter 客户端。
- 复制 ChatGPT.app 的私有 renderer、brand assets、app.asar 或安装包代码。
- 新增第二套 Agent loop、provider、Host、会话权威数据库。
- 在没有 CI/受保护 main/安装包证据时宣称 Released。

## Implementation summary

- 新增 Desktop BotConversationView，使用 Fabushi BotMark、CSS Modules 和安全的 React Markdown 子集；长答案采用文档流，代码块可以复制。
- 统一 Messenger 的 legacy/Mini App Bot 分支接入该 view；Mahayana runtime event 继续驱动 message/delta/action/thinking/operation 生命周期。
- legacy Agent 的发送路径增加乐观用户消息、运行中停止按钮、后续输入队列和自动 drain；Mini App 等待阶段显示 processing 条目。
- Android MobileBotViewModel 增加按 Bot 的 transcript/draft 内存投影、thinking 条目和 streaming 状态。
- iOS MobileBotChat 改为绑定父级按 Bot 保存的 transcript/draft，并增加 streaming 状态。
- 未恢复或修改任何 Flutter 路径。

## Acceptance criteria

- [x] 每个 Bot 切换/重新打开时保留自己的 transcript 和 draft（Desktop peer-key 投影；Android/iOS 父级按 Bot 投影）。
- [x] assistant 增量输出显示在同一条消息中，结束后清除 streaming 状态。
- [x] thinking/action/model/operation 不与最终回答混成一个普通气泡。
- [x] Desktop Agent 可停止；运行中输入可排队并在前一运行结束后发送。
- [x] Bot 消息支持复制、编辑回填和重新生成入口；Markdown/代码块安全渲染。
- [x] 用户阅读旧消息时不强制跳底，并可回到最新位置。
- [x] Flutter 未恢复、未修改、未重新加入当前架构。
- [ ] GitHub CI、受保护 main、Electron packaged E2E 和原生 iOS/Android packaged/simulated-user E2E 通过。
- [ ] 截图、完整视频、trace、原生报告和 exact-SHA Release 证据齐全。

## Verification

- DMG：已确认 Electron/Chromium + app.asar；只做行为分析，不复制安装包文件。
- Open-source-first：assistant-ui MIT、Vercel AI SDK Apache-2.0、LibreChat MIT、Open WebUI 当前许可证均已调查并记录；未新增第三方依赖。
- Desktop renderer：隔离工作副本中执行 renderer typecheck/build，结果通过；不能替代 GitHub Actions 的产品门禁。
- Android：隔离工作副本中执行 compileDebugKotlin，结果通过；存在既有 deprecated warnings，不能替代 CI/device E2E。
- iOS：工程源文件已更新；当前目录只有 XcodeGen project.yml，工程生成和 iOS test 留给 dedicated CI workflow。
- Lightweight diff check：待提交前再次执行。

## Provenance / license

DMG 是第三方产品安装包，私有 renderer/资源没有进入仓库。Desktop 组件为 Fabushi 自有重写。开源参考只采用公开的行为/架构认识；未复制 assistant-ui、Vercel AI SDK、LibreChat 或 Open WebUI 的代码。若未来引入任何依赖，必须单独补 license notice 和 dependency review。

## Rollback

- Desktop 回滚只需移除 BotConversationView 接入，保留原 Messenger view 和 Host event bridge。
- Android/iOS 回滚只需恢复 child-local transcript storage；MobileChatMessage.streaming 是向后兼容的可选字段。
- 不触碰 Mahayana protocol、canonical Host 权限或 Flutter 历史目录。

## Evidence / next action

证据目录：evidence/GBF-806/（当前实现证据待 CI 生成）。

下一步：提交项目记录和实现变更，触发 Electron/native-mobile workflows；根据 CI 的 TypeScript、iOS、Android、E2E 和视觉证据结果修复后，再决定是否进入 TESTED/E2E_VERIFIED。

## 2026-09-09 continuation: local Agent multi-step experience

User now explicitly requests Hermes-style local CLI event integration, Grok Bot-style multi-step presentation and clickable Mini Apps. Preserve previous session work. Fix interrupted vs failed state, operation routing and timeline grouping; expose installed Mini App results through the existing capability-checked opener. Do not create a parallel runtime.

Research: Hermes `acp_adapter/events.py` sends text, tool-call start/complete and plan separately, tracking same-name tool calls with distinct IDs. Grok reconstruction `message-card-seam.ts` separates message projection/actions and `run-step-state-contract.ts` preserves pending calls in checkpoints. Its PROVENANCE.md explicitly does not grant an upstream source license, so use design observations without importing code. ChatGPT `local-conversation-plan-model-*.js` selects plans by turn ID, supporting per-turn projections rather than a global progress widget.

Archive recovery: `/Users/gloriachan/Documents/ChatGPT-recovered-20260909/` contains 7,182 shipped code/assets files and a full 8,930-entry inventory with extraction hashes. This is production bundle recovery, not original authored source. Recovery remains outside the application repository.

Acceptance remains pending: source checks, CI, packaged multi-step/stop/switch/reopen/Mini App journeys and protected-main delivery. Previous checkboxes are implementation claims, not verified product acceptance.
