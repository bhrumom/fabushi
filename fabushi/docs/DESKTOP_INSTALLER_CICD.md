# 桌面安装包 CI/CD

`.github/workflows/desktop-installers.yml` 负责构建并发布桌面安装包。

## 触发方式

- Pull Request：构建 macOS / Linux / Windows 安装包并上传 workflow artifacts，不创建 GitHub Release。
- Push main：构建三平台安装包，成功后创建 GitHub Release 并上传产物和 `SHA256SUMS.txt`；同时上传 macOS App Store 包到 App Store Connect。
- workflow_dispatch：可指定 `source_sha`、`release_tag`、`openclaw_version`，也可关闭 GitHub Release 发布或 macOS App Store 上传，仅做构建验证。

## 产物

- macOS：`.dmg` 和 `.zip`
- Linux：`.deb` 和 `.tar.gz`
- Windows：NSIS `.exe` 安装器和 `.zip`
- Mac App Store Connect：用于 TestFlight/App Store 处理的 `.pkg`，同时保留上传状态 artifact

所有平台在打包前都会运行 `scripts/build_openclaw_desktop_bundle.sh`，把 Node.js 与 OpenClaw runtime vendoring 到 `assets/openclaw/<platform>/`，最终用户无需安装 Node、npm 或 OpenClaw。默认 OpenClaw npm 版本固定为 `2026.6.1`，手动 workflow dispatch 可覆盖。

## macOS Developer ID 签名与公证

GitHub Release 里的 macOS DMG 面向 App Store 外分发，使用 Developer ID Application 证书签名，并通过 Apple 公证服务检查恶意软件、签发 notarization ticket，再 stapler 到 DMG 上。未配置时产物仍会构建并发布，但不会签名/公证。

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_CODESIGN_IDENTITY`

公证凭据可二选一：

- App Store Connect API key：`APP_STORE_CONNECT_API_KEY_ID`、`APP_STORE_CONNECT_API_ISSUER_ID`、`APP_STORE_CONNECT_API_KEY_BASE64`
- Apple ID app-specific password：`APPLE_ID`、`APPLE_TEAM_ID`、`APPLE_APP_SPECIFIC_PASSWORD`

## macOS App Store Connect / TestFlight

macOS App Store 上传使用 `.github/scripts/upload-macos-app-store.sh`，在 main push 或手动 dispatch 开启 `upload_macos_app_store` 时运行。它会 archive/export macOS App Store `.pkg`，用 App Store Connect API key 校验并上传。上传成功后，构建会进入 App Store Connect 的处理流程，可用于 TestFlight 内测或后续提交审核；workflow 不会自动点“提交审核”。

必需 secrets：

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `MACOS_APP_STORE_CERTIFICATE_P12_BASE64`
- `MACOS_APP_STORE_CERTIFICATE_PASSWORD`
- `MACOS_APP_STORE_INSTALLER_CERTIFICATE_P12_BASE64`
- `MACOS_APP_STORE_INSTALLER_CERTIFICATE_PASSWORD`
- `MACOS_APP_STORE_PROVISIONING_PROFILE_BASE64`

推荐 variables：

- `MACOS_APP_STORE_TEAM_ID`
- `MACOS_APP_STORE_BUNDLE_ID`
- `MACOS_APP_STORE_SIGNING_CERTIFICATE`
- `MACOS_APP_STORE_INSTALLER_SIGNING_CERTIFICATE`
- `MACOS_APP_STORE_INTERNAL_TESTING_ONLY`

## 与移动端 CD 的关系

iOS / Android 原来的发布 CD 不被桌面 workflow 替代：Android 继续使用 Google Play service account 和 keystore secrets，iOS 继续使用现有 App Store Connect API key、iOS p12、iOS provisioning profile。新增的 macOS secrets/variables 只服务桌面安装包签名、公证和 Mac App Store/TestFlight 上传。

Windows 代码签名证书暂未接入；当前 workflow 产出可安装 NSIS 包和校验和。
