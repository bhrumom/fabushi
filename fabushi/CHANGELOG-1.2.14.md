# Fabushi 1.2.14 release notes

## 全新正式版本发布

- 以当前 canonical `main` 为唯一来源启动全新 `1.2.14` 正式发布列车；当前开放 PR #2287 已审阅，但仍为 Draft，且其 iOS marketplace live-official 安装门禁缺少兼容 `global-dharma` artifact，因此按仓库验收约束继续隔离，不提前并入正式主线。
- 桌面、Android 与 iOS 产品版本统一提升到 `1.2.14`，Android `versionCode` 与 iOS `CURRENT_PROJECT_VERSION` 统一提升到 `20`。
- 沿用仓库现有 `[full-platform-release]` exact-main GitHub Actions 编排，覆盖 macOS/Windows/Linux 桌面产物、Android/iOS、正式商店交付、生产部署、GitHub Release 资产、全新安装与上一正式版本升级验收；重型构建和测试仅在 GitHub Actions 执行。
