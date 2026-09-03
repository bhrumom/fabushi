# FPG-005 原始需求：PR 必须先合并 main 才能进入下一任务

日期：2026-08-24
来源：用户明确要求
项目：FAB-P0002 / FPG / Fabushi Project Governance

## 用户要求

在根 `AGENTS.md` 中加入仓库级硬性规则：每次任务结束之前，必须先把当前任务对应的 PR 合并到 `main`，确认合并成功之后，才能开始下一个 PR 任务。

## 规范化解释

1. 一个仓库任务在其 PR 尚未合并到 `main` 前，不得被视为完成。
2. 当前任务存在未合并 PR 时，Agent 不得为了另一个独立任务创建或推进新的 PR 工作流。
3. 必须先等待/检查 required CI、review、merge queue 或其他受保护分支门禁，并完成 merge。
4. merge 后必须从 canonical `main` 回读关键结果，确认目标变更确实已进入 `main`。
5. 只有完成上述闭环后，才允许切换到下一个独立 PR 任务。
6. 若当前 PR 因 CI、review、冲突或保护规则无法合并，应把当前任务保持为 `in-progress` / `blocked` / `failed`，而不是绕过它开始下一个 PR。
7. 紧急安全修复等真正需要并行处理的例外，只有在用户明确授权或仓库已有更高优先级紧急流程时才允许，并必须记录原因；默认规则仍是严格串行。

## 验收

- 根 `AGENTS.md` 明确出现 PR-to-main 串行门禁。
- FPG WBS 与验收矩阵登记此规则。
- 本治理变更自身必须通过 PR、required checks、合并 `main`、canonical-main 回读后才可标记 passed。
