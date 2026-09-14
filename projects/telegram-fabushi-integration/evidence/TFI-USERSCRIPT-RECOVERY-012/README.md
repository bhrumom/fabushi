# TFI-USERSCRIPT-RECOVERY-012 证据索引

本目录保存任务级暂停、详情和删除修复的持久化证据。当前状态：`IMPLEMENTING`。

## 已确认

- canonical parent project：`FAB-P0001` / `TFI`。
- source baseline：`bhrumom/fabushi-chatgpt-auto-confirm-userscript` `main@579c5204734afe21d366018d4ee16b5c6d3fb6ce`，版本 2.9.20。
- 根因：顶部运行中暂停动作调用全局 `markTasksPaused()`；单项取消也先调用全局暂停；删除只在详情底部对暂停/终态任务显示。
- 开源调查：见 `source/2026-09-14-userscript-task-controls.md`。

## 待补证据

- source branch / commit / PR / review。
- source PR CI 与 exact-main CI run/job。
- 轻量回归报告（含测试总数）。
- source Release tag、target SHA 和 raw-main 版本。
- 登录态 Chrome 中的逐步截图、完整操作视频、trace/diagnostics；这些必须绑定 source main SHA、版本、浏览器时间和任务标识。
- 若用户明确要求发布，补充 Chrome Web Store/安装更新与回滚记录。

## 交付边界

Fabushi packaged build/Electron/mobile post-main delivery 对本轮为 `N/A`；独立 userscript 的 source CI、Release 和现场浏览器证据仍是本任务闭环门禁。


## 本轮实现记录（2026-09-14）

- source PR [#16](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/16) 已创建，head `53102aad173091cd8629caf4a1e761f7ad2d64d7`。
- source branch commit：`53102aad173091cd8629caf4a1e761f7ad2d64d7`，基于 source main `579c5204734afe21d366018d4ee16b5c6d3fb6ce`。
- 本地轻量验证：`node --check chatgpt-auto-confirm.user.js` PASS；`npm test` PASS，108/108。
- 新增回归覆盖：选中任务顶部暂停、设置中的全局暂停、行级详情、行级暂停/继续/恢复、取消隔离、活跃任务删除禁用、暂停/取消后单项删除以及异步暂停不转 blocked。
- source PR CI：待回读；source protected main、Release `v2.9.21`、raw-main、真实 Chrome 视觉/视频/trace：待完成。
