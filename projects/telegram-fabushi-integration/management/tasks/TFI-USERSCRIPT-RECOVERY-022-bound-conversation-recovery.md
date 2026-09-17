# TFI-USERSCRIPT-RECOVERY-022 — 发送歧义时优先恢复绑定会话

## Identity

- Portfolio Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-022`
- Source: `source/2026-09-17-userscript-bound-conversation-recovery.md`
- Parent baseline at intake: `6245420379e6c11a84d23b2e705debe779532d47`
- Source repository: `bhrumom/fabushi-chatgpt-auto-confirm-userscript`

## Objective

修复 ChatGPT 自动确认在发送结果超过 90 秒仍无法确认时的恢复断点：存在本轮绑定会话 URL 时先回到该会话检查最终回复/结束状态并继续既有任务流程；没有绑定 URL 时才每 3 分钟刷新恢复，持续失败后才新开会话原样重发。发布新的 userscript 版本并同步 parent bundled/Marketplace 固定信息。

## Scope

In scope:

- source userscript 的 ambiguous-send 状态机。
- 绑定会话 URL 优先导航、最终回复/结束状态复用现有 inspect/finish 流程。
- 无绑定 URL 的 180 秒恢复冷却和最终 fresh-session resend。
- source v2.9.36 Release 与 parent bundled/Marketplace immutable metadata 同步。
- durable project/evidence 更新和 protected-main 验证。

Out of scope:

- 不改变 ChatGPT 服务端行为或用户账号权限。
- 不在普通设备执行构建/测试。
- 不以自动 E2E 代替正式稳定发布的 Fabushi official MCP exact-candidate 验收。
- 不覆盖正在审核的旧 Chrome Web Store submission；新 candidate 的正式商店推广按当前 release governance 独立处理。

## Acceptance criteria

1. 90 秒发送确认超时且 `task.url` 有效时，任务进入 waiting/inspection，必要时导航到该 URL；不得因为当前页面不是该 URL 而直接 blocked 或重发。
2. 绑定会话已有最终回复/已经结束时，复用现有 `inspect` / `finish` / no-final-reply 状态机继续 work-review-next，不新建重复任务。
3. 无绑定 URL 时保留原派发身份，每 180 秒最多刷新一次并重新判断；冷却期间不能热循环。
4. 无绑定 URL 连续 4 个恢复周期仍无法建立会话身份时，才清理旧派发身份并调用现有 fresh-session retry，附件/目标/阶段保持一致。
5. 已绑定但内容停滞的会话继续沿用无限 180 秒同 URL 刷新语义。
6. source version 为 `2.9.36`；PR exact-head、source main CI 全通过；Release target 精确固定 source canonical merge SHA，asset size/SHA-256 有可核验证据。
7. parent bundled userscript 与 source Release 字节一致；Marketplace metadata 固定 source SHA、release URL、size、SHA-256；需要时单调递增 Chrome manifest/package version。
8. parent 通过 protected PR/merge queue 合并并 canonical-main 回读；正式稳定发布若涉及 Fabushi/Chrome production candidate，仍需 exact candidate Action runner + Fabushi official MCP 验收，未满足时明确保持 blocked 而不得伪报完成。

## Current verified source evidence

- Source PR: `bhrumom/fabushi-chatgpt-auto-confirm-userscript#29`.
- Exact-head PR CI: run `35233282863`, head `30b8d3cc071a478f47032bd95c2af0066df27982`, syntax + full regression passed.
- Source squash merge/canonical main: `2fd43b6ba64a58acbc806ad35a4c48b477ac57f0`.
- Post-main CI: run `35233363949`, success.
- Source Release: `v2.9.36`, release ID `390790284`, target `2fd43b6ba64a58acbc806ad35a4c48b477ac57f0`.
- Release asset: `chatgpt-auto-confirm.user.js`, `237859` bytes, SHA-256 `11784d8eafe788b7d72a99bd191865ba472ccf219561d91302cfadb65a5dae97`.

## Status and next action

- Status: `IN_PROGRESS — SOURCE_RELEASED / PARENT_INTEGRATION_PENDING`.
- Next: copy the exact v2.9.36 source artifact into parent bundled userscript, update Marketplace immutable metadata/project traceability, run allowed parent checks in GitHub Actions, merge through protected governance, and read back canonical main.
- Started: `2026-09-17T22:02:00+08:00`
- Updated: `2026-09-17T22:27:00+08:00`
- Completed: pending parent integration and applicable publication gate.
