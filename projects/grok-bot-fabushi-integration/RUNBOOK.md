# Execution Runbook

1. 从 `main` 读取本项目目录和当前代码。
2. 选择一个最小能力任务，不从历史 Grok 分支整批合并。
3. 比较来源分支与 `main` 对应文件/行为。
4. 标记：已在 main、更优于 main、main 已超越、需重构迁移、应废弃、来源待确认。
5. 设计正式 Fabushi 归属与权限边界。
6. 实现最小 PR，并补单测/集成/E2E。
7. 更新 WBS、验收矩阵、风险和 evidence。
8. 只有 CI 与验收证据通过后提升状态。
9. 通过受保护 main/merge queue 合并；再验证 main。
