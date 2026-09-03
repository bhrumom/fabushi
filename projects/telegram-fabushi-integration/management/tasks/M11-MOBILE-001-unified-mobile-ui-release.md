# M11-MOBILE-001 — 统一移动端逻辑 UI 与 1.1.0 全平台交付

- **Project ID**：`FAB-P0001`
- **Project Key**：`TFI`
- **状态**：`RELEASED`（本次发布列车）；M11 更广泛的跨端互通验收仍为 `IN_PROGRESS`
- **更新时间**：2026-09-01

## 目标

完成统一移动端逻辑 UI 的剩余修复，统一 1.1.0 版本元数据，并通过 GitHub Actions 完成 Web/PWA、Electron、Android 与 Apple 交付。

## 实施范围

- PR #2248–#2251：移动端逻辑 UI 主体修复并合入主线。
- PR #2252：1.1.0 版本、Android code 5、iOS build 5 与锁文件统一。
- PR #2253–#2260：iOS bridge、可见性、无障碍、Profile 菜单、selector、对话框与导航 sheet 修复。
- PR #2261：Android GitHub Release FileProvider manifest merge 修复。
- PR #2262：在既有不可变 `desktop-1.1.0` 发布存在旧 target 时，增加同版本 recovery tag 发布策略。

## 可追溯验证

- 应用产品源码基线：`82ddb78653ecdc47c95bf1a372389adff9f24d09`。
- 当前发布控制主线：`3f7cddc0bc09802d9a3d142cab7f9a56c573c07c`。
- `82ddb... → 3f7c...` 仅包含 `.github/workflows/macos-desktop-e2e.yml` 与 `.github/workflows/post-main-delivery.yml`；没有产品代码变化。
- 当前主线 CI：`33436781726`；移动端质量门：`33436781683`；Electron 桌面质量门：`33436781694`；交付治理：`33436781731`。
- Post-main 交付：`33437994689`；Worker：`33436811350`；Fabushi Pay：`33436811361`。
- Android 产物发布：`33434030555`；Apple 上传交付：`33434030571`。

## 发布产物

- 桌面：[`desktop-1.1.0-3f7cddc0bc09`](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.1.0-3f7cddc0bc09)，target 为当前主线 `3f7c...`，非 draft、非 prerelease。
- Android：[`android-v1.1.0-262432005`](https://github.com/bhrumom/fabushi/releases/tag/android-v1.1.0-262432005)，target 为产品源码基线 `82ddb...`，包含 APK、update manifest 与 SHA256。
- Apple：[`apple-v1.1.0-2026.8.3133`](https://github.com/bhrumom/fabushi/releases/tag/apple-v1.1.0-2026.8.3133)，target 为产品源码基线 `82ddb...`，App Store Connect 上传成功并包含 IPA 与 SHA256。
- 官方站版本策略已同步为 macOS/Windows/Linux `1.1.0+5`，同步结果均为 `success: true`。

## 边界与后续

- Android 交付是 GitHub APK 发布，不等同于 Google Play 公共商店审核通过；Apple 交付是 App Store Connect 接收，不等同于 App Review/公开上架完成。
- 当前主线的自动移动发布因提交未带历史 `[full-platform-release-final-20260831]` 标记而跳过；已发布的 Android/Apple 产物来自紧邻父提交，且经比较确认无产品代码差异，因此不重复构建同一份应用。
- 本记录只关闭本次统一移动端 UI 发布列车；M11.T01–T05 的完整 iOS/Android/Electron 跨设备互通、push sync 与 background recovery 仍须独立证据，不能由本次 UI 发布代替。

## 证据位置

- `../../evidence/M11-MOBILE-001/README.md`
- `management/03-验收追踪矩阵.md`
- `management/05-状态报告.md`
- `management/07-变更日志.md`