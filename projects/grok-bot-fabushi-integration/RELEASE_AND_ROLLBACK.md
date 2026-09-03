# Release and Rollback

- 所有运行时代码通过 PR 进入受保护 `main`。
- 高风险能力使用可关闭的 capability/feature gate 分阶段启用。
- 发布前记录影响平台、迁移步骤、数据兼容性、回滚命令或回滚 PR。
- 桌面端变更必须进入 Electron 构建/E2E；移动端受影响时进入对应原生验证。
- 回滚不得恢复已退役 Flutter/Tauri 路径，也不得直接回滚整个历史 Grok 分支。
