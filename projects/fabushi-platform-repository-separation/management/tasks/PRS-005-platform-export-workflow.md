# PRS-005 — Platform export workflow

- Project ID: `FAB-P0013`
- Project Key: `PRS`
- Task ID: `PRS-005`
- Source requirements: `PRS-REQ-002`, `PRS-REQ-003`, `PRS-REQ-009`, `PRS-REQ-010`, `PRS-REQ-011`
- Status: `in-progress`
- Started: `2026-09-18`
- Updated: `2026-09-18`
- Source baseline: `cbe65975f3c4c077fa64af4171ebe3d2900185ad`

## Objective

在 GitHub-hosted runner 中提供可选择目标、默认 dry-run、可审计和可回滚的源码/历史导出流程，
并把 CLI 与 shared Core 的边界作为显式过滤规则执行。

## Scope

- 使用 fresh mirror 和固定 source SHA。
- 使用 `git-filter-repo` 按平台矩阵导出；Core 二次排除 CLI-specific crates。
- 生成 source/target refs、路径清单、fsck、summary 和 90-day artifact。
- 只有 workflow_dispatch 明确关闭 dry-run 时，才使用现有 `OFFICIAL_SITE_RELEASE_PAT` 推送目标仓库。

不包含产品功能重构、依赖边界最终收敛、平台 CI/E2E/Release、源仓库目录删除或本机构建。

## Open-source survey and decision

沿用 PRS-001 的开源优先结论：采用官方 `git-filter-repo` 做多路径导出；用 Git `git-subtree`
做单前缀交叉校验；不采用 Josh 的持续 proxy。工具和取舍记录在
`decisions/ADR-0001-repository-split-toolchain.md`。

## Acceptance criteria

1. workflow 通过治理 CI，target/source SHA 输入可复现，默认不 push。
2. CLI/Core dry-run 产出路径、refs、fsck 和 checksum evidence，且没有 secrets。
3. 受控 push 后目标仓库 `main` 与 evidence 中 target SHA 一致；失败时保留 bootstrap SHA 和回滚 refs。
4. 每个后续目标都能复用同一 workflow，且 CLI 不再落入 Core 过滤结果。

## Verification / evidence

- 当前仅做轻量 YAML/文本审阅和 `git diff --check`；不在本机执行历史重写。
- workflow 合入后记录 run/job、artifact、源/目标 SHA 和路径清单至 `evidence/PRS-005/`。

## Branch / PR / next action

- Branch/PR: pending workflow bootstrap PR。
- Next action: merge workflow, run CLI/Core dry-run, review evidence, then execute explicit push only after
  path audit passes.
