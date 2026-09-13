# TFI-USERSCRIPT-RECOVERY-007 — 任务目标图片、视频及文件输入

- Project ID: \`FAB-P0001\`
- Project Key: \`TFI\`
- Task ID: \`TFI-USERSCRIPT-RECOVERY-007\`
- Status: \`IN_PROGRESS\`
- Started: \`2026-09-13T09:30:00+08:00\`
- Updated: \`2026-09-13T10:05:00+08:00\`
- Source: \`source/2026-09-13-userscript-task-file-input.md\`
- Requirements: \`TFI-USR-FILE-R01\`–\`TFI-USR-FILE-R07\`
- Prior dependency: \`TFI-USERSCRIPT-RECOVERY-006\`, source \`main@fbd7b2bd8b549c1fb61acc29dc3a4af99cba1e50\` / userscript \`2.9.10\`
- Parent baseline: \`bhrumom/fabushi main@6b77ac34060e1733dd8d0a900987a5dd2471a0bb\`
- Source branch: \`codex/userscript-task-file-input-20260913\`
- Parent branch: \`codex/tfi-userscript-file-input-20260913\`

## Objective

让油猴工作台的任务目标可以携带图片、视频及其他文件，并在派发到 ChatGPT 时把附件作为真实会话输入；附件上传未被页面确认前不发送目标文字。

## In scope

- 工作台任务目标表单的多文件选择、预览、清空和隐私提示。
- 任务附件元数据与 IndexedDB Blob 的 local-first 持久化。
- ChatGPT 原生文件输入与 Clipboard/DataTransfer 兼容上传路径。
- 上传确认、超时/失败 fail-closed、任务恢复和持续目标轮次衔接。
- userscript 轻量回归、版本发布和 TFI 项目记录/证据索引。

## Out of scope

- ChatGPT 私有 API、access token、服务端媒体协议或 Fabushi 应用媒体 CDN。
- 对视频进行转码、抽帧、OCR、压缩或把二进制转换为 prompt 文本。
- 绕过 ChatGPT 当前账号的文件格式、大小、配额、授权和安全限制。
- 未经用户选择的本地文件读取或自动上传。

## Dependencies

- ChatGPT 页面当前会话的原生文件输入/编辑器事件仍可用。
- 浏览器提供 IndexedDB、File、DataTransfer 和 ClipboardEvent（按能力选择兼容路径）。
- 用户在工作台明确选择文件，并已登录 ChatGPT。
- source \`v2.9.10\` 的 loading/会话身份/发送未知结果保护保持不变。

## Acceptance criteria

- [ ] \`TFI-USR-FILE-A01\`: 任务目标区出现“添加图片/视频/文件”入口，可一次选择多个文件，显示名称/大小，清空后可重新选择。
- [ ] \`TFI-USR-FILE-A02\`: 新建任务后 localStorage 只含附件 id/名称/type/size/lastModified 等元数据；文件内容可从 IndexedDB 取回，任务刷新/暂停恢复后仍保留。
- [ ] \`TFI-USR-FILE-A03\`: 发送前脚本优先向 ChatGPT 原生 \`input[type=file]\` 注入 FileList，必要时对 ChatGPT 编辑器发出带 DataTransfer.files 的 paste 事件；不调用私有上传 API。
- [ ] \`TFI-USR-FILE-A04\`: 只有当前 composer/附件面板确认所有本轮文件后才点击发送；上传加载、失败、缺少本地 Blob、文件输入不兼容时不发送纯文字，并保留可恢复任务。
- [ ] \`TFI-USR-FILE-A05\`: 单次任务、持续目标 Work/验收轮次、页面刷新、暂停/恢复和异常新会话重发都保留附件引用；任务删除时清理对应本地 Blob。
- [ ] \`TFI-USR-FILE-A06\`: 图片、视频、普通文件代表样本覆盖 UI/状态机回归；userscript syntax 与全量轻量回归在 source CI 通过。
- [ ] \`TFI-USR-FILE-A07\`: source 版本单调递增并绑定 source main/CI/Release；父项目记录经 protected main 合并并 canonical readback。
- [ ] \`TFI-USR-FILE-A08\`: 已登录 Chrome 使用无敏感图片、短视频和普通文件完成“选择 → 任务展示 → 上传确认 → 发送”的完整分步截图、完整视频、trace/diagnostics；缺少现场证据时任务保持 \`IN_PROGRESS\`。

## Verification plan

- Lightweight source checks: \`node --check chatgpt-auto-confirm.user.js\`; \`npm test\`; inspect persisted JSON to prove no file payload.
- Source GitHub checks: pull-request CI, exact source-main CI, canonical source readback and monotonic Release asset hash.
- Live browser: read workbench \`data-version\); select three safe test files; verify task chips/metadata; let the script attach files; verify ChatGPT attachment chips/media before the send click; retain step-labelled screenshots, complete journey video, trace/diagnostics and browser version.
- Parent GitHub checks: required PR checks, protected merge queue, canonical \`main\` readback of source/task/evidence/WBS/acceptance/risk/dependency/status/changelog records.
- Fabushi packaged delivery: \`N/A\` because this task changes only the independent ChatGPT userscript repository and TFI records, not application source/build/runtime.

## Open-source-first survey and reuse decision

- [KudoAI/chatgpt.js](https://github.com/KudoAI/chatgpt.js)（MIT，曾长期维护的 DOM library）及其 [USERGUIDE](https://github.com/KudoAI/chatgpt.js/blob/main/docs/USERGUIDE.md)：提供 \`getChatBox()\`、\`isLoaded()\`、\`isIdle()\` 等页面/编辑器抽象，说明加载、生成和编辑器状态应分开等待。采用其“页面能力抽象、就绪后再操作”的设计启发，不引入该运行时依赖。
- KudoAI 的 [multimodal discussion #347](https://github.com/KudoAI/chatgpt.js/discussions/347)（仓库页面显示 2026-08-10 已归档）：社区验证通过 \`File\` + \`DataTransfer\` + \`ClipboardEvent('paste')\` 把文件交给 ChatGPT 编辑器；由于是讨论中的 DOM 兼容技巧而非稳定正式 API，只作为无原生 file input 时的兜底，不复制原文代码。
- [TETRA326/ChatGPT-File-Upload](https://github.com/TETRA326/ChatGPT-File-Upload)（GPL-3.0）：历史扩展只把 txt/js/py/html/css/json/csv 原文插入文本框，明确不支持 docx 等非文本文件；许可证、能力范围和“把文件内容变成 prompt”的模型均不适合本任务，拒绝依赖/复制。
- 结论：保留 Fabushi 单文件、最小权限和现有 DOM 状态机；以原生 \`input[type=file]\` 为首选，DataTransfer 粘贴为兼容回退，IndexedDB 只存用户已选 Blob；不调用私有 API，不引入外部运行时。

## Implementation / evidence state

实现与 source delivery 已完成，parent records 和真实 Chrome 文件输入证据仍在进行中：

- `2.9.11` 在 source branch `codex/userscript-task-file-input-20260913` 实现多文件任务入口、IndexedDB 文件本体存储、元数据任务记录、ChatGPT 原生 `input[type=file]` / `DataTransfer` paste 上传、附件状态确认和 fail-closed 重试。
- source commit `08771783680f6a2fcae6a1abc67be15ea8867800`，PR [#11](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/11) 已合并到 source `main@4e6340e380f5c6c9b22b4a5b4352ad08e8d67ba2`。
- source PR CI run `34731199307` / job `103654186412` 成功；exact source-main CI run `34731259160` / job `103654358161` 成功；source `main` 回读确认目标 SHA 为 `4e6340e380f5c6c9b22b4a5b4352ad08e8d67ba2`。
- Release [v2.9.11](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.11)（release id `387761593`）绑定上述 source main，`.user.js` asset id `560339046`、133694 bytes、SHA-256 `7529a90211ebd969044313ca38fd1d7fca1fba702604794eafe749884a59695a`。
- 本地轻量验证：`node --check chatgpt-auto-confirm.user.js` 通过；`npm test` 84/84 通过。未执行本机 Fabushi 应用构建或重型测试。

## Post-main delivery state

`N/A（父仓库本轮仅提交 TFI 项目记录；独立 userscript 的 source CI/Release 已在上述 source 仓库完成，未改变 Fabushi 应用构建、运行时或安装包。）`

真实 Chrome 现场验收尚未完成：需要在已登录 ChatGPT 的安全样本环境中选择图片、短视频和普通文件，保留选择、任务展示、上传确认、发送前后等分步截图、完整视频、trace/diagnostics，并核对安装版本为 `2.9.11`。在该证据到位前，任务保持 `IN_PROGRESS`。

## Risks and blockers

- ChatGPT DOM 和附件 chip 语义可能变化；选择器必须窄范围、可见、优先语义属性，并在未确认时禁止发送。
- 视频/大文件可能超过账号配额或浏览器内存；不在 userscript 内转码/读取全量文本，把格式/大小决策留给 ChatGPT 页面并保留失败状态。
- IndexedDB 属于当前浏览器 profile/origin 的本地数据，不是跨设备备份；清理站点数据会使附件 Blob 丢失。
- 真实 Chrome 文件上传会向用户登录的 ChatGPT 传输用户选择的文件；现场验收只使用无敏感测试样本并保留用户可见确认。

## Next action

提交并合并 parent records PR，完成 canonical `main` 回读；随后在已登录 Chrome 中完成安全样本附件旅程并上传完整证据包。若 ChatGPT DOM 或账号限制导致附件无法确认，保留 fail-closed 结果并修复后重新走 source CI/Release 与 parent records 门禁。
