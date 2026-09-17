# TFI-USERSCRIPT-RECOVERY-012 — 任务级暂停、详情与删除

- 项目：`FAB-P0001` / `TFI`
- 任务 ID：`TFI-USERSCRIPT-RECOVERY-012`
- 来源：`source/2026-09-14-userscript-task-controls.md`
- 状态：`IN_PROGRESS`
- 开始时间：2026-09-14（Asia/Shanghai）
- 最近更新：2026-09-14

## 目标

修复工作台顶部暂停动作误把当前标签页全部任务改为暂停的问题；增加清晰的任务级详情、暂停/继续/恢复和安全删除入口，同时保持“暂停全部任务”作为显式的全局操作。

## 范围

包含独立 userscript 的状态转换、任务行/详情面板 UI、轻量回归测试、版本与 README、source PR 和 source-main CI 证据。

不包含 Fabushi 应用源码、移动端、Worker、安装包、Chrome Web Store 发布或真实登录态 Chrome 视觉验收；这些是后续发布/现场验收门禁。

## 依赖与风险

- 依赖现有 `pausedState`、`restorePausedTasks`、`data.autoResume`、Web Lock 与任务归属逻辑。
- 异步发送/导航过程中暂停可能已发生不可撤回的页面动作；实现必须在下一次副作用前检查任务状态，并将人为暂停从 `blocked` 捕获路径排除。
- 删除是破坏性动作：运行中任务只显示禁用的删除按钮，必须先暂停或取消；暂停/取消/终态任务才执行已有附件 Blob 清理。
- source main 当前为 2.9.20；本轮目标版本为单调递增的 2.9.21。

## 验收标准与验证

1. 对任务 A 执行暂停后，A 为 `paused`，任务 B/C 状态和调度继续性不变；全局 `autoResume` 不因单项暂停变为 `false`。验证：workbench jsdom 回归与代码审查。
2. 对暂停任务执行继续只恢复该任务；“继续全部任务”才恢复同标签页所有全局暂停任务。验证：状态转换回归。
3. 运行中选中任务的顶部按钮文案/行为为“暂停当前任务”；设置区域提供“暂停全部任务/继续全部任务”。验证：DOM 文案与点击回归。
4. 每条当前任务行可点击“详情”，详情显示该任务目标、状态、轮次、日志、会话与附件；行上有暂停/继续/恢复和删除操作。验证：DOM 回归与现场 Chrome 验收。
5. 活跃任务的删除按钮明确禁用并提示先暂停/取消；暂停、取消、完成、阻塞任务可删除且只删除自身记录和附件。验证：删除隔离回归。
6. 单项暂停导致异步检查抛出时，任务保持 `paused`，不会被转换为 `blocked`；其他任务仍可调度。验证：状态/捕获路径回归。
7. `node --test test/*.test.mjs` 通过；版本/README/source PR 可追溯。重型 Fabushi 构建不在本机执行，CI 为构建/集成验证权威。

## 开源优先调查与决策

已在实现前调查并记录于来源文件：XState（MIT，显式事件/状态边界）、p-queue（MIT，队列执行与 autoStart 分离）以及本 userscript 主仓库。两者只提供设计参考，本轮不引入运行时依赖，保持单文件、localStorage/IndexedDB 及现有锁模型；GPL 文件上传实现不适合作为本任务依赖。

## 实现与交付记录

- 源仓库：`bhrumom/fabushi-chatgpt-auto-confirm-userscript`
- 基线：`main@579c5204734afe21d366018d4ee16b5c6d3fb6ce`（2.9.20）
- 分支：`codex/task-controls-2.9.21`
- source PR [#16](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/16) 已合并；合并后的 source main：`a6a8a74b339176d044d2a8090ae996ec9c17b739`
- source PR CI：workflow run `34807761856` / job `103862862189`，`userscript` PASS；source main 已回读为 `a6a8a74b339176d044d2a8090ae996ec9c17b739`，raw-main 版本 `2.9.21`
- Release：用户尚未要求本轮公开发布，待明确发布后执行；不得把未发布状态写成已上线。
- Chrome 现场截图/完整视频/trace：待 source Release 后安装现场验收。
- Fabushi packaged delivery：`N/A`，原因是本轮只改独立 userscript，不改变 Fabushi 可打包应用。

## 当前下一步

代码、source PR/CI 和 source main 回读已完成；下一步是获得明确发布授权后创建 `v2.9.21` Release，并进行真实 Chrome 现场验收。


## 实现结果（2026-09-14）

- 已完成 2.9.21 状态/UI 改造：单任务暂停、单任务继续、单任务取消、任务行详情、可发现的安全删除按钮，以及独立的暂停全部/继续全部入口。
- 已完成防回归：暂停/取消中的异步检查不再继续副作用，也不会把人为暂停误写为 blocked；单任务继续不会恢复其他暂停任务。
- source branch：codex/task-controls-2.9.21；source PR：#16；commit：53102aad173091cd8629caf4a1e761f7ad2d64d7。
- 轻量验证：node --check 通过；npm test 108/108 通过。
- 当前状态仍为 IN_PROGRESS：source PR #16 已合并，source Release 和真实 Chrome 证据尚未闭合；公开发布未获本轮单独授权。


## 合并后 source-main 回读（2026-09-14）

- source PR [#16](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/16) 已通过检查并以 squash merge 合并。
- canonical source main：`a6a8a74b339176d044d2a8090ae996ec9c17b739`；userscript raw-main header 已确认版本 `2.9.21`。
- PR CI：run `34807761856` / job `103862862189`，`userscript` conclusion=`success`。
- 仍待完成：用户明确授权后的 GitHub Release `v2.9.21`、Release/raw-main 资产回读，以及登录态 Chrome 的截图/完整视频/trace。Fabushi packaged delivery 继续为 `N/A`。
