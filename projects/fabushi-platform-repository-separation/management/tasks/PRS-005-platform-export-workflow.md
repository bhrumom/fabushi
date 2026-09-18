# PRS-005 — Platform export workflow

- Project ID: `FAB-P0013`
- Project Key: `PRS`
- Task ID: `PRS-005`
- Source requirements: `PRS-REQ-002`, `PRS-REQ-003`, `PRS-REQ-009`, `PRS-REQ-010`, `PRS-REQ-011`
- Status: `in-progress`
- Started: `2026-09-18`
- Updated: `2026-09-18`
- Source baseline for formal export: `7851b689d2fe3fc3893cd9f4363899cc4a03e83b`

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

- 本机仅做轻量 YAML/文本审阅；没有在本机执行历史重写、构建、打包或应用测试。
- workflow 合入 canonical `main`：PR [#2709](https://github.com/bhrumom/fabushi/pull/2709)，合入提交
  `8971a64ebad99dcee4c7dfc43e5e11a843a93e0e`；README 保留修复合入 PR
  [#2710](https://github.com/bhrumom/fabushi/pull/2710)，元数据模板修复合入 PR
  [#2711](https://github.com/bhrumom/fabushi/pull/2711)，当前 workflow 所在 canonical SHA 为
  `7851b689d2fe3fc3893cd9f4363899cc4a03e83b`。
- CLI/Core 的正式 push 运行分别为 [35306247989](https://github.com/bhrumom/fabushi/actions/runs/35306247989)
  和 [35306250392](https://github.com/bhrumom/fabushi/actions/runs/35306250392)；其余 11 个正式 push
  运行及完整目标 SHA/path manifest 见
  [`evidence/PRS-005-platform-export-20260918.md`](../../evidence/PRS-005-platform-export-20260918.md)。
- 所有 13 个目标仓库的 `main` 已完成读回；每个目标的 `MIGRATION_SOURCE.md` 都记录同一源 SHA、目标边界、
  精确 source roots 和 `FAB-P0013 / PRS`。每个目标均保留 `refs/backup/prs-bootstrap-20260918`。
- dry-run 与正式 push 均在 GitHub-hosted runner 完成；目标 fsck 报告为空。未复制 secret、cookie、签名材料、
  `.env` 或测试账户状态。

## Branch / PR / next action

- Branch/PR: workflow 与记录修复已合入 canonical `main`（PR #2709/#2710/#2711）。
- Next action: 为每个独立仓库配置 branch protection、CODEOWNERS、CI、版本和 Release；完成 Core/CLI/平台
  依赖边界收敛后，运行各仓库自己的构建、E2E、打包和发布验收。PRS-005 在这些独立交付门完成前保持
  `in-progress`。
