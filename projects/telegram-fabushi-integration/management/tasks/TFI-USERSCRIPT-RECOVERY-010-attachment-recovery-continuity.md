# TFI-USERSCRIPT-RECOVERY-010 — 恢复/继续任务保持附件连续性

## Identity

- Portfolio Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-010`
- Started: `2026-09-13T23:15:00+08:00`
- Updated: `2026-09-13T23:45:00+08:00`
- Status: `IN_PROGRESS`

## Objective

修复 ChatGPT userscript 在首次发送带附件后，恢复/继续/异常重发或跨轮次发送时丢失附件的问题。附件必须继续作为真实会话输入；任何附件未确认的发送都必须保持阻塞。

## Source requirements

规范化来源记录：`projects/telegram-fabushi-integration/source/2026-09-13-userscript-attachment-recovery-continuity.md`。

- `TFI-USR-ATTACH-R01`：任务级附件元数据与 IndexedDB Blob 连续保留。
- `TFI-USR-ATTACH-R02`：每次新 composer/document 的 Work、验收和下一轮发送前重新注入/确认。
- `TFI-USR-ATTACH-R03`：旧 token/route/composer 的确认不可复用，禁止纯文字降级。
- `TFI-USR-ATTACH-R04`：缺 Blob、上传控件、确认、成功回调或超时均 fail-closed。
- `TFI-USR-ATTACH-R05`：暂停、取消恢复、连续轮次保留附件，删除任务才清理 Blob。

## Scope

### In scope

- userscript dispatch context 与附件确认生命周期。
- Work→验收、验收→下一轮 Work、暂停/取消恢复和失败重试的附件保持。
- 源仓库回归测试、版本发布和 Fabushi parent project records。

### Out of scope

- ChatGPT 私有上传 API、文件转码或绕过平台大小/账号限制。
- Fabushi Electron、Android、iOS、服务端和 Marketplace 产品构建。

## Dependencies

- Source baseline `v2.9.18` / `main@07d9a4be2c514cc094234f5e66e656095ce6cd4a`。
- GitHub source repository `bhrumom/fabushi-chatgpt-auto-confirm-userscript`。
- 已登录 Chrome 的真实附件恢复旅程证据仍待补齐。

## Acceptance criteria

- [ ] A01：同一任务的每次 Work/验收发送都使用任务原附件元数据和同一 IndexedDB Blob，并在当前 composer 确认后才发送。
- [ ] A02：composer、document、route 或 dispatch token 变化会使旧确认失效，并触发当前页面重新注入。
- [ ] A03：Work→验收、验收→下一轮 Work、暂停/恢复、取消恢复、异常重发均保持附件；不能出现 text-only 目标。
- [ ] A04：缺 Blob、控件、确认或上传失败/超时均 fail-closed，保留任务供重试。
- [ ] A05：源仓库语法与回归测试通过，覆盖连续轮次、暂停/取消恢复、DOM/document 重建和失败重试。
- [ ] A06：source PR、exact-main CI、Release 与安装资产可追溯到同一 source main SHA。
- [ ] A07：parent records 经 protected main 合并并回读，且已登录 Chrome 取得带标签的截图、完整视频和 trace/diagnostics。

## Open-source-first survey and decision

已检查 `KudoAI/chatgpt.js`（MIT）、`Violentmonkey/violentmonkey`（MIT）和 `TETRA326/ChatGPT-File-Upload`（GPL-3.0）。采用前两者的 DOM readiness、File/DataTransfer 和版本可追溯设计启发；拒绝 GPL text-only 实现；不复制代码、不增加依赖。

## Implementation summary

`v2.9.19` 增加按 task/token/route/composer 绑定的 attachment dispatch context。context 变化时清除旧的短期上传标记，保留任务附件和 IndexedDB Blob；重新发送前按当前 composer 重新注入并确认，确认失败不发送。

## Source delivery evidence

- Source branch: `codex/attachment-recovery-continuity-20260913`
- Source PR: [#14](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/14)
- PR head: `9d021826a42ef7fb6807ab69f067f6535daac63e`
- Source main after merge: `5cbbb4e099f8404982ea621a4ab8464f4b2b959e`
- PR CI: run `34766140772` / job `103747328591` — success
- Exact source-main CI: run `34766208786` — success
- Source Release: [v2.9.19](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.19)
- Release asset: `chatgpt-auto-confirm.user.js`, asset `561460868`, 159166 bytes
- Release asset SHA-256: `1c412e333ff5b9702db037fa091daef94a9ca4a45b9acf90ed2f65b782c48265`
- Lightweight verification: `node --check` PASS; `npm test` 98/98 PASS

## Parent/release evidence

- Parent branch: `codex/tfi-userscript-attachment-recovery-20260913`
- Parent PR / merge / canonical readback: pending.
- Live Chrome evidence: pending; source tests and source Release do not substitute for the required real-browser evidence.
- Post-main packaged Fabushi build/E2E: `N/A` — this task changes only the independently released userscript and project records, not a Fabushi packaged product.

## Risks and next action

- Risk: ChatGPT may change attachment DOM or upload behavior; retain current-composer scoped confirmation and fail-closed behavior.
- Risk: IndexedDB data may be unavailable after profile/storage changes; retain task metadata and require reselect/retry rather than sending without attachments.
- Next: merge parent records through protected main, read back canonical state, then run the authenticated Chrome attachment recovery journey and attach complete evidence.
