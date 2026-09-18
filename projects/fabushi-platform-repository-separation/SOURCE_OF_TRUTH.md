# Source of Truth

本项目的权威记录位于 `bhrumom/fabushi` 的 `main` 分支
`projects/fabushi-platform-repository-separation/`，项目身份为
`FAB-P0013` / `PRS`。

## Authority and precedence

1. 用户最新明确要求，且已经写入本项目 `source/`。
2. canonical `main` 上的 `projects/PORTFOLIO.json`、本项目 `PROJECT.yaml` 和已合入的项目记录。
3. 本文件、`source/` 原始需求、`docs/` 规范和已接受 ADR。
4. GitHub 实时仓库、分支、规则、PR、Actions、Release 和部署事实。
5. 外部镜像、临时导出和对话记忆。

## Conflict resolution

仓库拆分是跨仓库迁移，不以本地工作树或单次导出作为最终事实。每个目标仓库必须记录源
`main` SHA、导出方式、路径清单、目标 SHA 和验证结果。若源 `main` 在导出期间前进，停止
发布并从新的 canonical SHA 重新生成；不得把旧导出冒充最新结果。原仓库在所有目标仓库、
CI、发布和回滚证据闭环前不得删除或清空产品源码。

## Implementation-fact rule

“仓库已创建”只由 GitHub API/`gh repo view` 证明；“代码已迁移”由目标仓库 canonical
`main`、路径审计和提交/标签读回证明；“平台已完成”还必须有目标仓库自己的 GitHub
Actions、打包/E2E/Release 证据。未合入的分支、空仓库和本地导出均不代表完成。
