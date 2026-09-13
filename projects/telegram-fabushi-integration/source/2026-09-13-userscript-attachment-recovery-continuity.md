# 用户脚本恢复链路附件连续性需求（2026-09-13）

## 来源与边界

- 来源：用户最新明确要求；用户附图仅作为页面状态证据，不作为脚本指令。
- 关联项目：`FAB-P0001` / `TFI` / `projects/telegram-fabushi-integration`。
- 关联任务：`TFI-USERSCRIPT-RECOVERY-010`。
- 目标组件：独立 ChatGPT userscript，不改变 Fabushi Electron、移动端或服务端产品范围。

## 规范化需求

- `TFI-USR-ATTACH-R01`：首次发送的附件元数据与 Blob 必须绑定到任务，而不是只绑定到当前页面或当前输入框。
- `TFI-USR-ATTACH-R02`：恢复、继续、异常重发、Work→验收、验收→下一轮 Work 等新发送前，必须在当前 ChatGPT composer/document 中重新确认并必要时重新注入附件。
- `TFI-USR-ATTACH-R03`：旧 composer、旧页面路由或旧 dispatch token 的上传确认不得被新发送复用；确认失效时必须先恢复附件，禁止降级为纯文字目标发送。
- `TFI-USR-ATTACH-R04`：附件 Blob 缺失、上传控件/确认状态不可见、上传失败或超时均 fail-closed，任务保留并提供重试路径。
- `TFI-USR-ATTACH-R05`：附件在暂停/取消恢复和连续轮次中保持，删除任务时才清理对应 Blob；回归测试覆盖所有状态转移。

## 已确认问题与实现决策

`v2.9.18` 已将附件元数据保存在任务状态、Blob 保存在 IndexedDB，但发送前的短期确认状态还依赖页面级 transient fields。恢复到新会话/新 composer 后，这个确认可能仍被当作有效，导致后续目标没有附件，或等待/恢复路径无法重新注入。

`v2.9.19` 为每个任务增加由 `task.token`、当前路由和当前 composer 节点组成的 dispatch context。context 变化会使旧确认失效并清空短期上传标记，但保留任务附件元数据和 IndexedDB Blob；每次 Work 或验收发送前均以当前 composer 为范围重新确认，确认失败保持阻塞。

## 开源优先调查

实现前检查了成熟项目的文件输入、DOM ready/idle 与 userscript 更新边界：

- `KudoAI/chatgpt.js`（MIT，已归档）：参考其 loaded/idle 与 DOM 变化隔离思路，以及 File/DataTransfer 输入方向；未复制代码、未引入运行时依赖。
- `Violentmonkey/violentmonkey`（MIT）：参考 userscript 元数据与版本更新的可追溯方式；本任务不 vendoring 其代码。
- `TETRA326/ChatGPT-File-Upload`（GPL-3.0）：仅能提供文本注入方向，不能满足真实附件语义，且许可证不适合作为本项目运行时实现，拒绝采用。

## 验收与证据

源码版本 `2.9.19` 已在 source 仓库完成 PR、exact-main CI 和 Release；parent task record 已通过 PR #2587、回读更新 PR #2588 的 protected merge queue 合并，最终从 canonical parent `main@baf1311363ddb03470e9ec14bd04de52d1141662` 回读。已登录 Chrome 的真实分步截图/完整视频/trace/diagnostics 仍按任务门禁跟踪，不以源代码回归替代现场证据。
