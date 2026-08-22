# Source of Truth

## 权威项目基线

唯一长期项目基线：`bhrumom/fabushi` 的 `main:projects/grok-bot-fabushi-integration/`。

## 原始需求

原始上传需求保存于 `source/grok-bot融合优化.txt`，原文为：学习 Grok Bot 项目并把 Grok Bot 完全融合进 Fabushi。

当前任务进一步明确：为“融合 Grok Bot 所有功能、所有源码”建立完整项目文件夹并持续完成项目资料。

## 工程事实来源

- 当前产品事实：GitHub `main`。
- Grok Bot 历史融合输入：`grok-bot-latest-source-fusion`、`grok-bot-0.16-source-fusion`。
- PR/CI/Release/部署事实：GitHub 实时状态。
- 聊天、外部副本、历史分支不得静默覆盖 `main`。

## 冲突处理

若来源分支与 `main` 冲突：先做能力级 diff；默认保留 `main` 的后续修复，再迁移来源分支独有能力。只有有明确 ADR、测试与 CI 证据时才改变正式架构。
