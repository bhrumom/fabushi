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
- source 分支：待创建
- host 仓库：`bhrumom/fabushi`
- host 基线：`main@b07ccff486d9c0f2b659460ac3a79a654c9eb3dc`
- host 分支：`codex/tfi-userscript-memory-20260914`
- source PR/CI/merge：待完成
- host PR/CI/merge：待完成
- Release/Chrome Web Store：本轮未授权，待完成门禁及用户明确发布授权
- local heavy build/test：禁止；GitHub Actions 是重型验证权威

## 当前下一步

先完成 source userscript 与 host MV3 消息桥接，再补齐本项目 WBS/验收/风险/依赖/状态/变更和证据索引，提交 source/host PR；通过 protected merge 和 required CI 后再决定是否需要发布/现场验收。
