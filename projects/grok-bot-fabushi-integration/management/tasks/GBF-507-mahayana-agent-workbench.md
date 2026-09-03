# GBF-507 — Mahayana Agent Workbench 与实时动态头像

- **Project:** `grok-bot-fabushi-integration`
- **Stage:** M5 / UI 与可观察 Agent 行为融合
- **Owner:** Fabushi desktop + Mahayana runtime
- **Status:** RELEASED
- **Implementation PRs:** `#2108`, `#2110`, `#2111`, `#2112`
- **Released product SHA:** `e2332b09475f1032567b27d454c45b3801cbd9c5`
- **Release:** `desktop-1.0.896` / Fabushi Desktop 1.0.896
- **Source requirement:** `grok-bot融合优化.txt`、`完整telegram融合进fabushi.txt`，以及 2026-08-25 用户要求“Bot 必须调用 Mahayana 多步骤工作、会话保存、动态头像和 Grok 类运行 UI 完整融合”。
- **Reference baseline:** `bhrum/grok-bot-0.18-reconstructed@a9f633e09d49a85829b8236331b9e21f7e612634`

## Objective

把当前“普通聊天气泡 + 粗粒度 busy 状态”升级为 Fabushi 自有实现的 Agent 工作台：所有 Bot 通过单一 Mahayana Runtime 执行，用户能在同一个 Messenger 会话里看到规划、模型路由、步骤、工具、审批、子智能体、后台任务、结果、Usage 与中断/恢复；动态头像必须读取同一条真实运行事件流。

## Scope delivered

1. `chat.send` 统一为 Mahayana `agent` 模式，不增加第二套 Agent runtime。
2. Electron Mahayana transport 发布命令与 runtime event 总线。
3. `operation.*`、`agent.step`、`model.routed`、`chat.*`、`transcript.card`、`mcp.toolResult`、`approval.*`、`subagent.*`、`asyncTask.*`、background agent 与 `usage.updated` 投影为同一运行日志。
4. 现有 Messenger 展示可折叠运行卡、步骤时间线、审批、工具结果、Artifact、最终结果、停止与继续操作。
5. 活跃会话列表、Header、资料页头像读取运行投影状态，而不是仅依赖发送按钮 busy 状态。
6. 本地保存运行日志；应用重启后已完成运行保持可见，未完成运行进入 `interrupted/resumable`。
7. Legacy Mahayana Bot 与 self-hosted Bot 都进入 Mahayana 执行路径。self-hosted 路径由 Rust messaging service 产生 `botInvocationRequested`，桌面桥转交唯一 `mahayana-assistant` runtime，同时保留来源 Bot/conversation 投影身份，不伪造 Bot actor。
8. 以 Fabushi 自有 React/CSS/Motion 代码重建可观察行为和视觉，不嵌入供应商生产 renderer、安装包资产或品牌文件。
9. `conversation.opened` 与本地有界 conversation journal 对账，解决 Host 测试/离线恢复为空时普通 Messenger 正文丢失；Rust canonical store 仍为最终权威目标。

## Non-goals / follow-up boundary

- 不把 Grok Bot 的闭源生产 renderer 或安装包资源直接打入 Fabushi。
- 不建立独立于 Mahayana 的第二套工具循环、权限系统或会话权威数据库。
- 本任务的 localStorage conversation/run/invocation journal 是首屏、幂等和恢复投影；最终 Rust canonical conversation/run store 与副作用安全恢复仍由 `GBF-601` / `GBF-602` 承接。两项保持 `IN_PROGRESS`，不得因本任务 RELEASED 而误报完成。

## Architecture

```text
Self-hosted human message
  -> Rust mahayana-messaging canonical store
  -> botInvocationRequested
  -> selfhosted-mahayana-invocation-bridge
  -> canonical Mahayana agent runtime

Legacy/Mahayana composer
  -> ElectronMahayanaHostTransport.execute(chat.send, mode=agent)
  -> Electron preload / feature.execute
  -> Rust Mahayana AppHost / Runtime / tools

Both paths
  -> RuntimeEvent stream
  -> Mahayana Agent Workbench reducer
       -> run/step/tool/approval/output projection
       -> BotMark real activity state
       -> bounded local recovery journal
  -> existing Messenger message area + avatar slots
```

`operationId` 是运行主关联键；发送接受前以 `requestId` 建立临时运行，Host 返回后将其绑定到 `operationId`。会话使用 `conversationId` 或稳定的 Messenger peer key 关联。self-hosted Bot 的消息身份认证仍由 Rust messaging 权限模型控制；Renderer 不具有 Bot impersonation 权限。

## Acceptance criteria

| ID | Criterion | Objective verification | Status |
|---|---|---|---|
| GBF-507-A1 | Legacy Mahayana Bot 的 `chat.send` 必须使用 `mode=agent` | transport contract + renderer typecheck + exact-main real Host journey | PASSED |
| GBF-507-A2 | 自建 Bot 提交必须进入 Mahayana，而不是只回普通对话 | Rust `human_group_message_requests_bot_execution_inside_messaging_service` + Electron self-hosted Bot Workbench journey | PASSED |
| GBF-507-A3 | 一次任务至少显示 3 个真实步骤/生命周期节点 | `mahayana-agent-workbench.spec.ts` on exact-main real Rust Host | PASSED |
| GBF-507-A4 | 模型、工具、审批、子智能体、后台任务、Usage 有独立投影 | reducer/event contracts + exact-main full Electron suite | PASSED |
| GBF-507-A5 | 动态头像随 `thinking/searching/working/speaking/result/error/alerting` 等事件变化 | motion contracts + Playwright result-state assertion + packaged visual evidence | PASSED |
| GBF-507-A6 | 用户可停止/中断任务、批准/拒绝权限、继续失败/中断任务 | UI/Host contracts for `feature.interrupt`, `feature.approval.resolve`, `feature.execute` + exact-main full suite | PASSED |
| GBF-507-A7 | 应用重启后完整运行日志和结果仍可查看 | same app-data close/relaunch Playwright journey + conversation journal reconciliation | PASSED |
| GBF-507-A8 | Renderer TypeScript、Messenger、Host gates 全绿 | final-head PR gates + exact-main Messaging Product Gate | PASSED |
| GBF-507-A9 | protected-main merge 后主分支运行 E2E、截图/视频和安装包旅程通过并发布 | exact-main Electron + native mobile + post-main Release delivery | PASSED / RELEASED |

## Final implementation and release evidence

### PR and merge history

- PR `#2108`: initial Agent Workbench / multi-step / live avatar implementation.
- PR `#2110`: stabilize Agent transcript semantics and restart E2E; merged as `75a7d5e94e6ffcff8dcac3af09febfbfe9f6781b`.
- PR `#2111`: conversation recovery and duplicate projected-text repair; merged as `7fb1cd1f5749bb206dd3cf04da5c78612d6e6d25`.
- Exact-main Electron run `32803828364` then correctly failed before release, exposing an invalid direct-Node browser fixture and triggering the final repair loop.
- PR `#2112`: repaired the fixture and added the protocol-level self-hosted Bot -> `botInvocationRequested` -> Mahayana bridge; merge queue result `e2332b09475f1032567b27d454c45b3801cbd9c5`.

### Final-head and merge-queue gates

- Electron desktop PR gate: `32805007332` — success.
- CI: `32805007394` — success.
- Messaging Product Gate: `32805007346` — success; includes Rust messaging producer tests, Clippy/media queue, Electron Messenger type/architecture and production Feature Host bridge.
- Merge-group verification: `32805134081` — success.

### Exact-main product gates

- Exact-main Messaging Product Gate: `32805236171` — success.
- Exact-main Electron desktop quality gate: `32805236227` — success.
  - real Linux Rust Host complete user journey: success.
  - packaged Linux complete user journey: success.
  - packaged Windows complete user journey: success.
  - signed/notarized/stapled macOS package and packaged macOS complete user journey: success.
  - screenshots/video/trace/diagnostics and packages uploaded by the workflow.
- Exact-main Native mobile quality gate: `32805236162` — success.
  - Android unit/lint/debug package + Pixel 7 Compose simulated-user journey: success.
  - iOS SwiftUI unit + simulated-user UI journey + `.xcresult`: success.

### Release

- Post-main delivery run: `32805840960` — success.
  - bound desktop and mobile gates to the same main SHA.
  - downloaded only tested macOS/Windows/Linux artifacts.
  - exact-SHA manifests and updater assets validated.
  - immutable Release creation passed.
  - post-main delivery ledger persisted.
- GitHub Release: `desktop-1.0.896` / **Fabushi Desktop 1.0.896**.
- Release target: `e2332b09475f1032567b27d454c45b3801cbd9c5`.
- Updater/install assets include macOS DMG + ZIP + blockmaps + `latest-mac.yml`, Windows installer + blockmap + `latest.yml`, Linux AppImage/DEB + `latest-linux.yml`, delivery manifests and `SHA256SUMS.txt`.

## Risks and controls

- **R-507-1 — duplicate UI/runtime state:** Workbench is a projection only; Mahayana remains the sole executor and permission authority.
- **R-507-2 — selector/portal drift:** Existing Messenger remains canonical. Exact-main packaged Playwright journeys cover Linux/macOS/Windows.
- **R-507-3 — local journal is not canonical:** unfinished runs are conservatively marked interrupted on restart; no automatic side-effect replay occurs. `GBF-601/602` remain open for Rust canonical persistence/recovery.
- **R-507-4 — vendor provenance:** only observable behavior and design metrics are reimplemented; no vendor renderer/assets are copied.
- **R-507-5 — actor impersonation:** self-hosted bridge invokes Mahayana without granting Renderer authority to send as a Bot; existing Host impersonation rejection remains intact.

## Completion decision

`GBF-507` is **RELEASED**. Implementation, protected merge, canonical-main readback, real Rust Host execution, packaged Linux/Windows/macOS journeys, Android/iOS simulated-user journeys, evidence upload, updater metadata validation and immutable GitHub Release are all present for the same product SHA `e2332b09475f1032567b27d454c45b3801cbd9c5`.

This decision closes the Grok-style Agent Workbench/Bot-to-Mahayana/restart/release task only. It does not close the broader `FAB-P0004` program or `GBF-601/602/805`.
