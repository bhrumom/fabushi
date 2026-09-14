# TFI-USERSCRIPT-RECOVERY-013 — 用户脚本内存压力感知与宿主标签页回收

- 项目：`FAB-P0001` / `TFI`
- 任务 ID：`TFI-USERSCRIPT-RECOVERY-013`
- 来源：`source/2026-09-14-userscript-memory-pressure.md`
- 状态：`IN_PROGRESS`
- 开始时间：2026-09-14（Asia/Shanghai）
- 最近更新：2026-09-14

## 目标

降低独立 ChatGPT userscript 自身的长期内存增长；感知可观测 JS heap 压力；在不打断发送/上传/审批/导航和未保存输入的前提下，请求 Fabushi MV3 宿主回收非活动 ChatGPT 标签页；回收后依靠现有任务持久化和恢复机制继续运行。

## 范围

包含 userscript 的有界日志/瞬态资源清理、内存指标诊断、压力监测与宿主消息桥接；Chrome 宿主扩展的消息验证、危险状态拒绝、冷却和 `chrome.tabs.discard`；source/host 轻量回归、项目记录和发布证据。

不包含：从网页直接读取标签页进程 RSS、强制 V8 GC、清理 ChatGPT 自身 React/媒体缓存、强制 discard 活动标签页、在发送/上传中进行页面重载，以及本轮未经确认的公开 Release/Chrome Web Store 发布。

## 依赖与风险

- 依赖现有任务 localStorage/IndexedDB、Web Lock、pagehide/pageshow、tab-recovery 恢复租约和宿主 MV3 userscript runner。
- `performance.memory` 是 Chromium 非标准 JS heap 估算，不能代表标签页总内存；指标缺失时必须降级。
- `tabs.discard` 会卸载后台标签页并在激活时重新加载；自动请求必须限于页面隐藏、任务非危险阶段、无未保存草稿并通过宿主冷却。
- 用户当前标签页可能正是高内存标签页；活动标签页必须返回可操作提示，而不是自动刷新/丢失当前界面。
- 频繁 discard/reload 可能形成循环；采用连续样本、最小间隔、单标签冷却和既有恢复票据。

## 验收标准与验证

1. 代码审查/轻量测试证明 messages、preview、attachment context、Blob URL、监听器和监测定时器均有有界或 shutdown 清理路径。
2. JS heap 诊断只报告 `performance.memory` 的 used/total/limit/ratio，并清楚显示“网页 JS 堆估算”，不宣称获得 Chrome 进程 RSS。
3. 达到压力阈值且连续采样后，脚本先做本地有界清理，再向宿主发送最小消息；消息不包含 goal、prompt、附件字节、session token 或会话正文。
4. 宿主只接受已安装且启用的 `chatgpt-auto-confirm` userscript，使用 `sender.tab.id` 而非页面传入 tab id；只在 ChatGPT URL、非活动、非 discarded、安全状态且不在冷却时调用 `chrome.tabs.discard`。
5. 宿主对 active/in-flight/unsaved/unsupported/cooldown/error 返回结构化原因；脚本将结果呈现在工作台，不改变任务状态，不误触发全局暂停。
6. 本地回归覆盖指标、日志压缩、资源释放、请求脱敏、宿主契约和高压保护；source `node --check` 与 `npm test` 通过，宿主窄测试通过。
7. source PR/host PR、protected merge、canonical-main readback、必要的 Chrome packaged/现场证据和 Release 状态可追溯；未获单独发布授权时不得宣称已上线。

## 开源优先调查与决策

调查范围包括 Chromium 官方 `tabs.discard`、Page Lifecycle 文档；MIT Drowzy 的保护/冷却策略；BSD DevTools 前端 Memory 面板架构；GPL Great Suspender 的挂起方式。采用原则但不复制代码、不新增 runtime dependency。由于 userscript/宿主需保持现有安装协议、持久化任务与附件恢复边界，定制专用桥接最小且更安全；GPL/旧维护项目拒绝作为依赖。

## 实现与交付记录

- source 仓库：`bhrumom/fabushi-chatgpt-auto-confirm-userscript`
- source 基线：`main@a6a8a74b339176d044d2a8090ae996ec9c17b739`（2.9.21）
- source 分支：`codex/memory-pressure-2.9.22`
- source PR：[#17](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/17)，head `3d23d8cc78931dceecb4d647706766470224f81b`，当前 OPEN
- host 仓库：`bhrumom/fabushi`
- host 基线：`main@b07ccff486d9c0f2b659460ac3a79a654c9eb3dc`
- host 分支：`codex/tfi-userscript-memory-20260914`
- source PR/CI/merge：PR #17 已通过 CI 并合并；source main `882cadf0cc35d00a29b93450990d758b4034a5c0`，版本 2.9.22
- host PR/CI/merge：PR #2607 已合并至 main（merge `f7f9871b153efbe26d040e68e8d28eea46af2130`）；follow-up PR #2608 head `025cf0c04077ebd1affd5c25fa1f12a8489a1040` 待 CI/protected merge
- Release/Chrome Web Store：本轮未授权，待完成门禁及用户明确发布授权
- local heavy build/test：禁止；GitHub Actions 是重型验证权威

## 当前下一步

source userscript 与 host MV3 消息桥接已完成，项目 WBS/验收/风险/依赖/状态/变更和证据索引已补齐；下一步是通过 source/host protected merge 和 required CI，随后执行 exact-main packaged/Chrome 现场验收，再按用户授权决定是否发布。

## 本轮实现摘要

- 脚本端：任务消息限制为 80 条/条 12,000 字符/总计约 320,000 字符；附件 dispatch input 改为 WeakRef；统一生命周期监听并释放 idle preview URL/观察上下文。
- 诊断端：优先读取 Chromium `performance.memory`；连续两次 high pressure 才请求宿主；手动按钮与 `memory_status` / `cleanup_memory` 工具复用同一安全链路。
- 宿主端：新增 `tab-memory.request` 能力；只接受已启用的 ChatGPT 自动确认脚本，使用 `sender.tab.id` 再读取真实标签页；活动页、草稿、待上传附件、发送/上传/导航/授权任务和冷却期均拒绝 discard。
- 交付端：本轮没有公开 Release/Chrome Web Store 授权；host/application 重型构建与 E2E 必须走 GitHub Actions。

## 最新状态

首轮 host PR 已合并，但后续验证发现两个交付问题：Chrome release validator/packager/E2E 仍固定版本 `0.6.0`，以及 runner 只定义了内存清理函数却未在 `chrome.runtime.onMessage` 分发 `fabushi.userscript.memory.request`。两项均已在 follow-up PR #2608 修复，任务保持 IN_PROGRESS，等待该 PR 的 CI/protected merge 与 post-main 交付门禁。
