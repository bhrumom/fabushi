# FPG-005 澄清：允许并行任务，PR 合并是任务完成门禁

日期：2026-08-24
来源：用户对 FPG-005 的明确澄清
项目：FAB-P0002 / FPG / Fabushi Project Governance

## 用户澄清

可以并行处理多个任务。在某个 PR 等待 CI、review 或 merge queue 的过程中，可以继续处理其他任务。要求不是“上一 PR 未合并就不能开始下一任务”，而是：**每一个任务在结束/宣告完成之前，必须回到该任务，把它自己的 PR 推进并合并到 `main`，并确认 `main` 已经包含该结果。**

## 对原 FPG-005 的修正

1. 删除“当前存在未合并 PR 时禁止开始/推进其他独立 PR 任务”的串行限制。
2. 明确允许多个独立任务、分支和 PR 并行推进。
3. 某个 PR 等待 required CI、review、branch protection 或 merge queue 时，可以切换去处理其他任务。
4. 并行不等于遗忘：每个任务必须保持独立 task record、PR/CI/阻塞状态和下一步动作。
5. 在某个任务被标记 `passed` / `completed` 或对用户宣告“已完成”之前，必须主动回到该任务并推进它自己的 PR：处理失败/冲突/review，完成 required checks，进入受保护 merge 流程并合并到 canonical `main`。
6. merge 后必须从 canonical `main` 回读验证关键结果。PR 只是 open/approved/green/queued/pushed 都不能作为任务完成证据。
7. 如果该任务的 PR 仍无法合并，则该任务继续保持 `in-progress` / `blocked` / `failed`；这不阻止其他独立任务继续并行。

## 生效关系

本文件是用户对 `2026-08-24-FPG-005-pr-main-serialization.md` 中“严格串行”解释的后续澄清。按照项目 Source of Truth precedence，最新明确用户要求优先，因此 FPG-005 应实现“parallel execution + strict per-task PR-to-main closure gate”。

## 验收

- 根 `AGENTS.md` 明确允许等待 PR 期间推进其他任务。
- 根 `AGENTS.md` 明确每个任务结束前仍必须将其 PR 推进合并到 `main` 并回读验证。
- FPG-005 task/WBS/acceptance/status/changelog 与此澄清一致。
- 修正 PR 通过 required checks、受保护合并并从 canonical `main` 验证后，FPG-005 才可关闭。
