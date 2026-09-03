# M11-MOBILE-001 — 统一移动端逻辑 UI / 1.1.0 发布证据

- **Project**：`FAB-P0001 / TFI`
- **验收范围**：统一移动端逻辑 UI、版本元数据、全平台构建/发布链路
- **应用版本**：`1.1.0`
- **证据日期**：2026-09-01

## 主线与源码关系

| 项目 | SHA / 结果 |
|---|---|
| 当前 canonical main | [`3f7cddc0bc09802d9a3d142cab7f9a56c573c07c`](https://github.com/bhrumom/fabushi/commit/3f7cddc0bc09802d9a3d142cab7f9a56c573c07c) |
| 应用产品源码基线 | [`82ddb78653ecdc47c95bf1a372389adff9f24d09`](https://github.com/bhrumom/fabushi/commit/82ddb78653ecdc47c95bf1a372389adff9f24d09) |
| 两者比较 | 仅 2 个发布 workflow 文件，0 个产品源码文件变化 |

## PR 链

- #2248–#2251：移动端逻辑 UI 主体。
- #2252：1.1.0 / Android code 5 / iOS build 5 版本收敛。
- #2253–#2260：iOS bridge、可见性、无障碍、profile 与导航 sheet。
- #2261：Android FileProvider release manifest merge 修复。
- #2262：同版本不可变桌面 Release recovery tag。

## GitHub Actions

- [CI 33436781726](https://github.com/bhrumom/fabushi/actions/runs/33436781726) — success。
- [Native mobile quality gate 33436781683](https://github.com/bhrumom/fabushi/actions/runs/33436781683) — success。
- [Electron desktop quality gate 33436781694](https://github.com/bhrumom/fabushi/actions/runs/33436781694) — success。
- [Delivery governance 33436781731](https://github.com/bhrumom/fabushi/actions/runs/33436781731) — success。
- [Post-main E2E Release delivery 33437994689](https://github.com/bhrumom/fabushi/actions/runs/33437994689) — success。
- [Worker production deploy 33436811350](https://github.com/bhrumom/fabushi/actions/runs/33436811350) — success。
- [Fabushi Pay production deploy 33436811361](https://github.com/bhrumom/fabushi/actions/runs/33436811361) — success。

## Release 验收

| 平台 | Release / 上传 | target | 结果 |
|---|---|---|---|
| Desktop | [`desktop-1.1.0-3f7cddc0bc09`](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.1.0-3f7cddc0bc09) | `3f7cddc…` | published，19 个桌面/更新元数据资产 |
| Android | [`android-v1.1.0-262432005`](https://github.com/bhrumom/fabushi/releases/tag/android-v1.1.0-262432005) | `82ddb786…` | APK、update JSON、SHA256 已发布 |
| Apple | [`apple-v1.1.0-2026.8.3133`](https://github.com/bhrumom/fabushi/releases/tag/apple-v1.1.0-2026.8.3133) | `82ddb786…` | IPA 上传 App Store Connect 成功 |

Apple 上传日志包含 `No errors validating archive` 与 `UPLOAD SUCCEEDED with no errors`。Android 工作流包含 Gradle `BUILD SUCCESSFUL`、版本/code 校验、签名校验与 GitHub Release 创建成功。

## Official site

- Post-main sync 将 `macos/stable`、`windows/stable`、`linux/stable` 全部更新为 `1.1.0+5`，三项 API 返回 `success: true`。

## 未关闭项

- 当前主线的自动 Android run [33438057062](https://github.com/bhrumom/fabushi/actions/runs/33438057062) 为 skipped；Apple run [33438057055](https://github.com/bhrumom/fabushi/actions/runs/33438057055) 的 resolve 阶段因同一 marker gate 跳过实际上传。由于 `3f7cddc…` 相对 `82ddb…` 只改发布 workflow，已发布移动端二进制仍与当前产品源码等价。
- Android GitHub APK 不代表 Google Play 公共上架；Apple App Store Connect 接收不代表 App Review 已通过。
- M11 全量 cross-device E2E、push sync、background recovery 仍保持 `IN_PROGRESS`，见 `management/wbs/M11.md` 与行动项 ACT-006。