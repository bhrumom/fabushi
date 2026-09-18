# PRS-001 — Platform repository separation bootstrap

- Project ID: `FAB-P0013`
- Project Key: `PRS`
- Task ID: `PRS-001`
- Source requirement: `source/2026-09-18-platform-repository-separation.md`
- Status: `in-progress`
- Started: `2026-09-18`
- Updated: `2026-09-18`
- Branch: `codex/platform-repository-split-bootstrap`
- Source baseline: `cbe65975f3c4c077fa64af4171ebe3d2900185ad`

## Objective

建立按平台拆分 Fabushi GitHub 仓库的可执行项目边界、目标仓库矩阵、迁移顺序和可回滚门禁，
并为后续 Core/CLI/平台导出和独立交付提供 durable record。

## In scope / out of scope

范围是项目注册、实时 main 基线、平台路径盘点、目标 repo 命名、shared Core/CLI 边界、开源调研、
迁移架构、验收和回滚规则。范围外是本轮直接删除源代码、业务功能重构、本机构建/测试和把
secrets 复制到新仓库。

## Acceptance criteria

1. `FAB-P0013` / `PRS` 在 registry、`PROJECT.yaml` 和 portfolio index 中保持一致。
2. 目标矩阵覆盖 Web、Desktop、Android、iOS、WeChat、Browser、Backend、CLI、Forum、Commerce、
   Marketplace、shared Core 和 governance control plane；现有 Userscript repo 被明确复用。
3. 记录开源方案的架构、许可证、适配性和取舍。
4. 记录源 SHA、仓库可见性假设、边界耦合、禁止的本地重型验证和 post-main 交付门。
5. 项目记录进入 PR；在 PR/CI/merge/main readback 完成前不标记项目完成。

## Open-source survey and decision

- `newren/git-filter-repo`：官方实现支持 `--subdirectory-filter`、多路径过滤、路径重命名、
  empty commit pruning、fresh clone safety，适合多平台的历史导出；只使用其工具，不复制源代码。
  其仓库同时提供 MIT/GPL 授权文件，执行时遵循工具发布许可。
- `git/git` 的 `git-subtree`：内置、成熟，`split` 生成适合导出为独立 repo 的 synthetic history，
  对单一 top-level subtree 很合适；本项目存在多根路径、shared Core、CLI 和边界重构，因此只作为
  简单子树/回归方案，不作为全量迁移工具。
- `josh-project/josh`：MIT，提供可逆的 Git projection 和持续多仓库 workspace/proxy；适合
  大规模持续同步，但引入常驻服务和新的 review/运维面。当前目标是一次性、可审计地物化目标
  GitHub repos，故暂不采用；后续若需要持续双向同步再单独评估。
- GitHub 官方“Splitting a subfolder out into a new repository”文档：验证了 fresh clone +
  `git-filter-repo` 的标准迁移路径。

结论：边界确定和单前缀导出可使用 git-subtree 做轻量验证；正式多路径历史导出在 GitHub-hosted
fresh mirror 使用 git-filter-repo，并保存 source/target ref/path/checksum evidence。本机不运行
历史重写、构建或测试。

## Verification plan

- 读取 GitHub API 的 source repo、canonical main、portfolio registry、目标 repo 列表。
- `git diff --check`、YAML/JSON 结构审阅和路径矩阵一致性检查。
- PR 阶段运行 `Project portfolio governance`；后续每个平台在自己的 CI 验证。

## Evidence / branch / PR

- Branch: `codex/platform-repository-split-bootstrap`。
- Local bootstrap commit: `baf8d02f6`。
- PR: [#2705](https://github.com/bhrumom/fabushi/pull/2705)。
- Remote PR head: `595bd0d0d0954a97e307ea9bcade5ab692da19a4`。
- Target repository creation, extraction, CI, E2E and Release evidence are not yet complete.

## Blockers / risks / next action

- Main risk is shared Desktop/Web/Rust dependency coupling; next action is import-graph and package
  boundary work after registration.
- Legacy `fabushi/` ownership is not yet resolved; retain it in source repo.
- Next action: complete portfolio validation/review and merge PR #2705; create target repos only after
  the registry registration is accepted on canonical `main`.
