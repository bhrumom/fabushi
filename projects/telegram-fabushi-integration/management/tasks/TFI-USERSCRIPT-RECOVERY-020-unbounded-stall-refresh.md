# TFI-USERSCRIPT-RECOVERY-020：停滞会话无限次三分钟刷新

## 任务身份

- Portfolio Project ID：`FAB-P0001`
- Project Key：`TFI`
- Task ID：`TFI-USERSCRIPT-RECOVERY-020`
- 状态：`IN_PROGRESS / SOURCE_RELEASED / PARENT_DELIVERY_PENDING`
- 开始时间：2026-09-16
- 更新时间：2026-09-16
- 完成时间：N/A；在 source/parent CI、受保护主线、post-main packaged E2E 和 Release 闭合前不得标记完成。

## 目标与范围

让绑定 ChatGPT 会话在连续 3 分钟无可见变化时刷新，并在刷新后仍无变化时无限持续，每次实际刷新至少间隔 3 分钟；保留任务身份和不重复发送保护。

范围包括独立 userscript 2.9.33、Fabushi Chrome 内置 userscript 镜像、Marketplace immutable metadata、Chrome 扩展候选版本 0.6.11、对应静态契约/回归和项目证据记录。

不包括连接中断分支的有限刷新、验收 JSON repair 上限、最终回复按钮判定、当前 Chrome 安装替换、Chrome Web Store 审核处理或本机应用构建。

## 来源与依赖

- 需求记录：[`source/2026-09-16-userscript-unbounded-stall-refresh.md`](../../source/2026-09-16-userscript-unbounded-stall-refresh.md)
- 前序实现：`TFI-USERSCRIPT-RECOVERY-019` / source v2.9.32 / parent Chrome 0.6.10。
- source 基线/当前 canonical main：`userscript/main@e246ea925c4daa2f90cae51d1c8718bcddaa6d47`。
- parent 基线：`codex/tfi-userscript-019-final-reply-stall-refresh-20260915@45ed9da82485d569b4f08d2019096524abb8c2b9`。

## 验收标准

| ID | 验收标准 | 验证方式 | 状态 |
|---|---|---|---|
| `A01` | 停滞刷新无次数上限，第 4 次及以后仍可刷新 | source focused regression，模拟第 1/2/3/4 次 | 已通过 |
| `A02` | 两次实际刷新至少相隔 180 秒；不产生热循环 | source focused regression，覆盖 180000ms 边界；静态审查 | 已通过 |
| `A03` | 刷新保持 URL、token、phase、round、附件、结果和不重复发送语义 | source regression 断言 | 已通过 |
| `A04` | 旧 `stalledRefreshExhausted` 标记迁移后不阻断恢复 | source focused regression | 已通过 |
| `A05` | source/bundled/Marketplace 的版本、commit、size、SHA-256 一致；Chrome 版本严格递增 | source hash、`cmp`、parent 静态契约 | 已实现，待 CI |
| `A06` | source Release、parent protected main、canonical packaged E2E 证据、Release 和线上回读闭合 | GitHub Actions/Release/catalog evidence | 待执行 |

## 开源优先调查与决策

- 参考 [p-retry](https://github.com/sindresorhus/p-retry) 的 `Infinity` retry、延迟和 abort 语义，以及 [TanStack Query retryer](https://github.com/TanStack/query/blob/main/packages/query-core/src/retryer.ts) 的 retryDelay/pause 语义。
- 不采用外部依赖：油猴脚本需要最小安装面，现有 task 持久化和调度器已经能提供同等安全边界。
- 采用方案：移除 `STALLED_REFRESH_LIMIT` 的终态判断；把 `STALLED_REFRESH_COOLDOWN_MS` 与 180 秒停滞阈值对齐；将旧 exhausted 字段降级为一次性迁移标记；保留 route/state/blocker/attempted guards。

## 实现与分支证据

- source 分支：`codex/unbounded-stall-refresh-2.9.33-20260916`
- source implementation commit：`205fc1266c779ea6addfd054ec3fd3df87ed3f4c`
- source PR：[#26](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/26)，已合并。
- source canonical main merge commit：`e246ea925c4daa2f90cae51d1c8718bcddaa6d47`
- source Release：[v2.9.33](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.33)，发布于 2026-09-16T13:06:45Z。
- source 文件：`chatgpt-auto-confirm.user.js`，v2.9.33，235095 bytes，SHA-256 `419a3eacdabe34b439cc71c2c934f5d7dea3a69a6ebaa50e76c7645da40f1986`
- parent 分支：`codex/tfi-userscript-020-unbounded-stall-refresh-20260916`
- parent implementation/initial-record commit：`fd5e3bdbbb423d1a32a12766f577c74adce80f41`
- parent record follow-up commit：`39e376af50df1a8ab3b7d307ee94c5e13efc45f9`
- parent source-release pin commit：`5c8ee77b0bda913536ca8e303c9a372dbb236334`
- parent 候选：Chrome `0.6.11`，内置 userscript v2.9.33；parent PR/CI/主线交付仍待完成。
- source Actions：PR run `35099639206`、merge-to-main run `35099720957` 均成功；Release 资产已公开并绑定上述 canonical main。

## 验证结果

- `node --check chatgpt-auto-confirm.user.js`：通过。
- source focused regression：`13/13` 通过。
- source full lightweight regression：`126/126` 通过。
- `git diff --check`：通过；source 与 parent bundled 文件逐字节一致。
- 未执行本机构建、打包、应用启动、native/mobile/E2E；这些必须由 GitHub Actions 完成。

## 风险、阻塞与下一步

- 风险：无限刷新可能增加 ChatGPT 页面请求。缓解为同一路由、每 180 秒持久化冷却，并在暂停/取消/完成/限流/阻塞/发送歧义时 fail-closed。
- 阻塞：parent CI、protected main、exact-main packaged simulated-user E2E 及其分步截图/全程视频/trace/report/log；Worker 部署与 catalog readback；parent Release。
- Chrome Web Store 现有审核锁定仍独立跟踪，不取消或覆盖。
- 下一步：提交 parent 变更，运行 GitHub Actions post-main 交付闭环；在全部证据闭合前保持 `IN_PROGRESS`。
