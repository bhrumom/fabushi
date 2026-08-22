# Dependencies and Blockers

## Dependencies

- 当前 `main` 的 Electron 与 Mahayana sovereign kernel。
- 历史来源分支 `grok-bot-latest-source-fusion`、`grok-bot-0.16-source-fusion`。
- CI/E2E 基础设施。
- 各平台本机能力适配器。

## 当前阻塞规则

任何“所有源码已融合”声明都被阻塞，直到 M1 完成 100% 文件/能力分类。任何高风险能力发布都被阻塞，直到权限、拒绝路径和 E2E 通过。来源许可不明确的模块不得以直接复制方式进入正式发布。
