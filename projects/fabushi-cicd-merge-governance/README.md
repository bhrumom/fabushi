# Fabushi CI/CD & Merge Governance

## Objective

把 Fabushi 的 CI/CD 和合并链路优化为高吞吐、低等待、可审计的工程体系：文档/治理类变更走极轻量快车道；代码按影响域执行最小必需测试；所有进入 `main` 的 PR 仍通过 merge queue 在最新主干组合上重新验证；生产部署只在对应产品域真实变化时触发。

## Current status

`active`

## Current stage

G0 — diagnose and optimize required CI / merge queue / post-merge CD.

## Canonical source

- Repository: `bhrumom/fabushi`
- Branch after merge: `main`
- Path: `projects/fabushi-cicd-merge-governance/`
- Original requirement: `source/README.md`

## Key acceptance targets

- 文档/项目治理-only PR 不再在 merge queue 强制运行全部产品测试。
- merge queue 仍执行必需 `CI result`，但按 merge-group 实际 diff 分类。
- 未分类的非文档代码默认 fail-safe 为全量 canonical checks，而不是静默放行。
- 自动合并只负责授权/进入 merge queue，不直接绕过主干保护。
- Worker / Fabushi Pay CD 不因纯文档 main push 触发完整生产部署。
- CI/CD 敏感变更继续由 PR + required check + merge queue 进入主干。

## Navigation

- `SOURCE_OF_TRUTH.md`
- `docs/02-enterprise-cicd-model.md`
- `docs/19-完成定义与验收.md`
- `management/01-WBS原子任务.md`
- `management/tasks/FCM-001-fast-safe-ci-merge.md`
