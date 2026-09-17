# TFI-USERSCRIPT-RECOVERY-006 — 页面加载态识别与等待

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-006`
- Status: `IN_PROGRESS`
- Started: `2026-09-12T22:45:00+08:00`
- Updated: `2026-09-12T23:12:00+08:00`
- Source: `source/2026-09-12-userscript-loading-state-wait.md`
- Requirements: `TFI-USR-LD-R01`–`TFI-USR-LD-R06`
- Source baseline: userscript `main@76856ab7c0c4aa6edd94cb0941dc112bf7db2516` (`2.9.9`)
- Parent baseline: `bhrumom/fabushi main@75d9105549a8cd99fb5b691bb36b5817d04e5579`
- Source branch: `codex/userscript-loading-state-20260912`
- Parent branch: `codex/tfi-userscript-loading-state-20260912`
- Source implementation commit: `f3c6d4e098741b3baac703891f4207a2eadfeff6`
- Source PR: [#10](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/10), merged to source `main`
- Source main readback: `fbd7b2bd8b549c1fb61acc29dc3a4af99cba1e50`
- Source PR CI: run `34701330510` / job `103573506968` — `success`
- Exact source-main CI: run `34701374228` / job `103573628135` — `success`
- Source Release: `v2.9.10`, release `387608537`, target `fbd7b2bd8b549c1fb61acc29dc3a4af99cba1e50`
- Source Release asset: `chatgpt-auto-confirm.user.js`, asset `559456795`, 112931 bytes, SHA-256 `3cc9c4e0a223440fd2c7a21d670fee88c3f9af0a8d4e806421fcb2ba30c4b4dd`

## Objective

让油猴脚本区分“ChatGPT 会话页面还在加载/水合”和“已停止生成但没有最终回复”，在加载完成前原地等待，避免误启动异常会话恢复或重复派发。

## Implementation summary

- 在独立 userscript `2.9.10` 中新增主内容区加载检测：可见 spinner、`aria-busy="true"`、progress/loading 语义，以及文档尚未完成且会话内容尚未出现的保守 fallback。
- 新增可恢复的 `loading` 任务状态并让它保持当前会话调度占用；加载期不启动 `no-final-reply` 观察或重发路径。
- 加载信号消失后将观察恢复为新的 clear 周期，既有 Stop、授权卡、ownership、最终控件/显式完成标记与稳定窗口保护不变。
- 检测范围限制在当前 `/c/<conversation-id>` 的主内容区，并排除消息正文、输入框、侧栏、隐藏节点和 Fabushi 工作台。
- 未修改 Fabushi 应用、桌面/移动构建、原生 E2E 或服务端协议。

## In scope

- 主内容区加载/水合信号识别。
- 加载态进入现有任务状态机并保留会话身份、派发意图和安全边界。
- 加载结束后的稳定窗口衔接。
- 代表截图的轻量回归、版本递增、source/parent 项目记录与证据索引。

## Out of scope

- ChatGPT 页面 DOM 的大规模重构或服务端协议读取。
- Fabushi 应用、桌面/移动端构建、原生 E2E 和应用发布。
- 未确认发送结果的自动重发。

## Acceptance criteria

- [x] `TFI-USR-LD-A01`: 中央加载指示器/主内容区水合信号被识别为 `loading`，而不是 `no-final-reply`。
- [x] `TFI-USR-LD-A02`: 加载期间不启动 15 秒异常结束计时，不创建新会话、不重复点击发送、不清除当前 URL/token。
- [x] `TFI-USR-LD-A03`: 加载信号消失后仍要求既有最终控件/显式完成标记与稳定窗口；局部加载控件不绕过 Stop/card/ownership 保护。
- [x] `TFI-USR-LD-A04`: 工作台、消息正文、侧栏、输入框和隐藏加载元素不会触发加载态。
- [x] `TFI-USR-LD-A05`: userscript syntax 与全量轻量回归在 source CI 通过；本机只做允许的轻量检查，不运行 Fabushi 应用构建或重型测试。
- [ ] `TFI-USR-LD-A06`: source 发布版本单调递增并绑定 source main SHA、CI 和 Release；父仓库记录经 protected main 合并并 canonical readback。
- [ ] `TFI-USR-LD-A07`: 真实 Chrome/ChatGPT 安装新版本后，保留“加载中 → 完全加载 → 继续监督”的分步截图、完整视频、trace/diagnostics；真实证据缺失时保持 `IN_PROGRESS`。

## Verification method

- 轻量：`node --check chatgpt-auto-confirm.user.js`；`npm test`（仅独立 userscript 的 jsdom 回归）。
- GitHub：source PR CI、exact source-main CI、source Release provenance。
- 现场：先读页面 root `data-version`，构造/观察已绑定会话的加载态，确认任务不被标成异常结束或自动重发；加载结束后继续既有完成判定，并保留截图/视频/trace/diagnostics。

## Verification results

- Local lightweight checks: `node --check chatgpt-auto-confirm.user.js` — PASS; `npm test` — 81/81 PASS.
- Source PR #10 CI run `34701330510` / job `103573506968` — PASS.
- Exact source-main CI run `34701374228` / job `103573628135` — PASS; canonical source `main` read back at `fbd7b2bd8b549c1fb61acc29dc3a4af99cba1e50`.
- Release `v2.9.10` is published from that source main SHA; downloaded release asset hash matches the recorded SHA-256.
- Fabushi application post-main product delivery: `N/A` — this change is isolated to the independent ChatGPT userscript repository and does not alter the packaged Fabushi application. The userscript's own Release gate is recorded above.

## Open-source-first survey and decision

- `KudoAI/chatgpt.js`（MIT，活跃维护）：DOM API 明确提供 `isLoaded()`、`isIdle()`、`getStopButton()` 等页面就绪/生成状态抽象；其 API/文档表明加载完成应是独立等待条件。Fabushi 采用同一“就绪优先、完成后稳定确认”的原则，但不引入远程运行时依赖，也未复制代码。
- `kkonstantin08/chatgpt-done-notifier`（公开仓库，页面未声明可复用许可证，因此不复制代码）：采用 per-tab 状态机，把真实生成周期、Stop、助手活动、稳定窗口和错误状态分开，并明确初始加载/简单重渲染不能触发完成。Fabushi 复用其保守状态机思路；本脚本仍保持单文件、local-first、最小权限和现有 Web Locks 边界。
- 结论：没有必要引入新的自动化框架或协议。实现沿用现有 DOM 轮询与状态机，增加窄范围的主内容加载信号，并在加载态清除异常计时；不会把外部选择器或代码直接复制进产品。

## Implementation / evidence state

- 已在 userscript `2.9.9` 基线上完成 `2.9.10` 加载状态检测、任务状态接入和回归夹具；source PR、source CI、exact-main CI、canonical readback 与 Release 已绑定实际 SHA。
- Parent record PR、protected parent-main merge/readback 和真实 Chrome 分步视觉/诊断证据尚未完成，不能关闭任务。

## Risks and blockers

- ChatGPT DOM 选择器会随 UI 变化；优先使用 `aria-busy`/`role=progressbar` 等语义信号，并把通用 spinner 选择器限制在可见主内容区。
- 把生成中的局部加载动画误作页面水合可能延迟任务，但应优先保守等待；Stop/授权卡仍优先处理。
- 当前已知现场证据仍需在登录 Chrome 中安装发布版本后获取；该门禁未关闭。

## Next action

提交并推进父仓库 TFI 记录 PR，完成 protected parent-main merge/readback；随后在已登录 Chrome 安装 `v2.9.10`，保留“加载中 → 完全加载 → 继续监督”的分步截图、完整视频、trace/diagnostics，并据此关闭剩余 A06/A07 门禁。
