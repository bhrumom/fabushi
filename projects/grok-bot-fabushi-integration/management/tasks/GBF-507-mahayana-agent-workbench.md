# GBF-507 — Mahayana Agent Workbench 与实时动态头像

- **Project:** `grok-bot-fabushi-integration`
- **Stage:** M5 / UI 与可观察 Agent 行为融合
- **Owner:** Fabushi desktop + Mahayana runtime
- **Status:** IN_PROGRESS
- **Branch:** `feat/gbf-mahayana-agent-workbench-v1`
- **Pull request:** `#2108`
- **Source requirement:** `grok-bot融合优化.txt`、`完整telegram融合进fabushi.txt`，以及 2026-08-25 用户要求“Bot 必须调用 Mahayana 多步骤工作、会话保存、动态头像和 Grok 类运行 UI 完整融合”。
- **Reference baseline:** `bhrum/grok-bot-0.18-reconstructed@a9f633e09d49a85829b8236331b9e21f7e612634`

## Objective

把当前“普通聊天气泡 + 粗粒度 busy 状态”升级为 Fabushi 自有实现的 Agent 工作台：所有 Bot 通过单一 Mahayana Runtime 执行，用户能在同一个 Messenger 会话里看到规划、模型路由、步骤、工具、审批、子智能体、后台任务、结果、Usage 与中断/恢复；动态头像必须读取同一条真实运行事件流。

## Scope

1. `chat.send` 统一为 Mahayana `agent` 模式，不增加第二套 Agent runtime。
2. 通过 Electron Mahayana transport 发布命令与 runtime event 总线。
3. 将 `operation.*`、`agent.step`、`model.routed`、`chat.*`、`transcript.card`、`mcp.toolResult`、`approval.*`、`subagent.*`、`asyncTask.*`、background agent 与 `usage.updated` 投影为同一运行日志。
4. 在现有 Messenger 中展示可折叠运行卡、步骤时间线、审批、工具结果、Artifact、最终结果、停止与继续操作。
5. 活跃会话列表、Header、资料页头像读取运行投影状态，而不是仅依赖发送按钮 busy 状态。
6. 本地保存运行日志；应用重启后已完成运行保持可见，未完成运行进入 `interrupted/resumable`。
7. 自建 Bot 与 legacy Mahayana Bot 最终都进入 Mahayana 执行路径。
8. 以 Fabushi 自有 React/CSS/Motion 代码重建可观察行为和视觉，不嵌入供应商生产 renderer、安装包资产或品牌文件。

## Non-goals

- 不把 Grok Bot 的闭源生产 renderer 或安装包资源直接打入 Fabushi。
- 不建立独立于 Mahayana 的第二套工具循环、权限系统或会话权威数据库。
- 本任务的 localStorage journal 是首屏/恢复投影；最终 Rust canonical conversation/run store 仍由 GBF-601/602 完成。

## Architecture

```text
Messenger composer
  -> ElectronMahayanaHostTransport.execute(chat.send, mode=agent)
  -> Electron preload / feature.execute
  -> Rust Mahayana AppHost / Runtime / tools
  -> RuntimeEvent stream
  -> Mahayana Agent Workbench reducer
       -> run/step/tool/approval/output projection
       -> BotMark real activity state
       -> local recovery journal
  -> existing Messenger message area + avatar slots
```

`operationId` 是运行主关联键；发送接受前以 `requestId` 建立临时运行，Host 返回后将其绑定到 `operationId`。会话使用 `conversationId` 或稳定的 Messenger peer key 关联。

## Acceptance criteria

| ID | Criterion | Objective verification | Status |
|---|---|---|---|
| GBF-507-A1 | Legacy Mahayana Bot 的 `chat.send` 必须使用 `mode=agent` | transport contract + renderer typecheck | PASSED |
| GBF-507-A2 | 自建 Bot 提交必须进入 Mahayana，而不是只回普通对话 | Electron journey sends from Bot peer and observes runtime run | IMPLEMENTED; E2E pending |
| GBF-507-A3 | 一次任务至少显示 3 个真实步骤/生命周期节点 | `mahayana-agent-workbench.spec.ts` | IMPLEMENTED; main E2E pending |
| GBF-507-A4 | 模型、工具、审批、子智能体、后台任务、Usage 有独立投影 | reducer event coverage + UI selectors | PASSED by typecheck/contracts; runtime journey pending |
| GBF-507-A5 | 动态头像随 `thinking/searching/working/speaking/result/error/alerting` 等事件变化 | live event state + Playwright result-state assertion | IMPLEMENTED; main E2E pending |
| GBF-507-A6 | 用户可停止可中断任务、批准/拒绝权限、继续失败/中断任务 | UI controls invoke `feature.interrupt` / `feature.approval.resolve` / `feature.execute` | IMPLEMENTED; runtime E2E pending |
| GBF-507-A7 | 应用重启后完整运行日志和结果仍可查看 | same app-data close/relaunch Playwright journey | IMPLEMENTED; main E2E pending |
| GBF-507-A8 | Renderer TypeScript、Messenger、Host fast gates 全绿 | GitHub Actions exact-head evidence | PASSED for initial head; final-head pending |
| GBF-507-A9 | protected-main merge 后主分支运行 E2E、截图/视频和安装包旅程通过 | main GitHub Actions and artifacts | PENDING |

## Implementation evidence

- `frontend/apps/web/src/lib/mahayana-host/electron-transport.ts`
- `desktop/src/mahayana-agent-workbench.tsx`
- `desktop/src/mahayana-agent-workbench.module.css`
- `desktop/src/grok-agent-ui-parity.css`
- `desktop/src/main.tsx`
- `desktop/e2e/mahayana-agent-workbench.spec.ts`
- Draft PR `#2108`
- Initial exact-head checks: Electron desktop quality gate and Host fast E2E succeeded on `9b119a853ddf89223de4cb55ad5b5d98aa2d5f97`; final-head checks remain required.

## Risks and controls

- **R-507-1 — duplicate UI/runtime state:** Workbench is a projection only; Mahayana remains the sole executor and permission authority.
- **R-507-2 — selector/portal drift:** Existing Messenger remains canonical. Playwright selectors and UI contracts must catch layout changes; a later direct component integration may replace the compatibility portal without changing the event model.
- **R-507-3 — local journal is not canonical:** unfinished runs are conservatively marked interrupted on restart; no automatic side-effect replay occurs.
- **R-507-4 — vendor provenance:** only observable behavior and design metrics are reimplemented; no vendor renderer/assets are copied.

## Completion gate

Keep this task `IN_PROGRESS` until:

1. PR final head passes required CI;
2. PR is merged through the repository's protected flow;
3. canonical `main` runs the new Playwright restart journey and packaged Electron journey;
4. screenshot/video artifacts are inspected;
5. WBS, acceptance traceability, append-only status/changelog and evidence index are updated with exact merge/run/artifact references.
