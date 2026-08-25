# GBF-507 Acceptance Traceability

| Requirement | Source | Implementation | Verification | Evidence | State |
|---|---|---|---|---|---|
| Bot 不能只做单轮对话，必须多步骤工作 | 2026-08-25 user continuation | `ElectronMahayanaHostTransport.execute` normalizes `chat.send` to `mode=agent`; self-hosted Bot submit bridge invokes `feature.execute` | renderer typecheck; Playwright Agent journey | PR #2108; `desktop/e2e/mahayana-agent-workbench.spec.ts` | IMPLEMENTED; main E2E pending |
| 使用现有 Mahayana，不建立第二 runtime | original Grok fusion requirement | all commands use Electron Mahayana edge / Rust AppHost | architecture contract + Host fast E2E | runs `32797695610`, `32797695647` | PASSED on initial head |
| 展示规划、步骤、工具和结果 | 2026-08-25 user continuation | Agent Workbench projects runtime lifecycle, steps, tools, cards and output | selector assertions for run/step/output | `mahayana-agent-workbench.tsx` + spec | IMPLEMENTED; main E2E pending |
| 会话内完成审批并继续 | Grok observable behavior | approval cards invoke `feature.approval.resolve` | approval UI/runtime journey | task record A6 | IMPLEMENTED; E2E pending |
| 子智能体与后台任务可观察 | Grok observable behavior | `subagent.*`, `asyncTask.*`, `agent.background*` projections | reducer/event contract + runtime journey | task record A4 | IMPLEMENTED; E2E pending |
| 动态头像随真实运行状态变化 | original dynamic avatar requirement | runtime events map to `BotMarkState`; active peer/Header/profile share current run state | Playwright result-state assertion and screenshot evidence | `#mahayana-agent-header-avatar [data-agent-state=result]` | IMPLEMENTED; main E2E pending |
| 会话/运行重启后不消失 | 2026-08-25 user continuation | bounded persistent run journal; in-flight runs become interrupted/resumable | close/relaunch same app-data journey | restart section in spec | IMPLEMENTED; main E2E pending |
| 可停止、恢复失败或中断任务 | Grok observable behavior | interrupt and resume actions | `feature.interrupt`/`feature.execute` journey | task record A6 | IMPLEMENTED; E2E pending |
| 视觉接近 Grok 运行工作台，同时保持 Fabushi 所有权 | original UI fusion requirement + provenance policy | new React/CSS UI and existing Fabushi motion engine; no vendor renderer/assets | source/provenance audit + packaged screenshots | `grok-agent-ui-parity.css`, workbench CSS | IMPLEMENTED; visual artifact review pending |
| 最终变更进入 main 并由安装包旅程验证 | repository completion gate | protected PR/merge/main Actions | exact main SHA checks, packaged journeys | evidence/GBF-507 | PENDING |

## Acceptance decision

`GBF-507` is **IN_PROGRESS**. Static/contract evidence has passed on an earlier exact head. The final decision requires final-head required checks, protected merge, canonical-main E2E and packaged visual evidence.
