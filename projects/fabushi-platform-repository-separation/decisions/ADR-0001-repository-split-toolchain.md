# ADR-0001：平台仓库拆分工具链与历史策略

- 状态：accepted for M0/M3 planning
- 日期：2026-09-18
- Project：`FAB-P0013` / `PRS`

## Context

源仓库包含多个平台、共享 Rust/runtime、CLI 和治理目录。目标是把它们物化为独立 GitHub
仓库，同时保留来源 SHA、路径审计、目标 SHA 和可回滚 refs。拆分期间不能把 secrets、构建
缓存或与目标平台无关的源码带入新仓库。

## Options considered

1. **git-filter-repo**（采用）：成熟的 Git 官方推荐替代方案，支持 fresh clone、安全检查、
   多路径过滤、路径重命名、子目录过滤和空提交清理，适合本项目一个目标包含多个 source root
   的情况。正式导出在 GitHub-hosted fresh mirror 执行，并固定工具版本。
2. **git-subtree split**（辅助）：Git 自带、适合单一 top-level subtree，生成可推送的 synthetic
   history；用于简单单前缀验证或回归，不承担本项目的多根目录全量导出。
3. **Josh**（暂不采用）：MIT licensed 的可逆 projection/proxy，适合持续双向同步，但会引入
   常驻服务和额外 review/运维面；本项目先做一次性、可审计的 GitHub 仓库物化。
4. 手工复制文件（拒绝）：历史、重命名和遗漏不可审计，无法作为默认迁移工具。

## Decision

M3 使用 `git-filter-repo` 在 CI fresh mirror 中导出多路径目标；每次导出保留 source commit、
source refs、target commit、目标路径 manifest、object/tree checksum、工具版本和 workflow run。
单目录目标可用 `git-subtree split` 做交叉校验。所有工具只作为外部工具使用，不复制其源代码；
执行时遵循各自上游许可证和仓库分发条款。

## Consequences

- 导出必须在 CI 执行，本机不运行历史重写。
- Core 和 CLI 必须先确定依赖版本边界，再导出；CLI 的命令行 UX、配置、harness 和 Release
  不与 Core 的共享 crates 混为一个产品仓库。
- 若目标路径跨越多个源根，必须生成逐路径保留/排除清单并由 CI 复核；不能只凭仓库大小判断。
- 若后续需要持续双向同步，另立 ADR 评估 Josh 或其他 projection 服务。
