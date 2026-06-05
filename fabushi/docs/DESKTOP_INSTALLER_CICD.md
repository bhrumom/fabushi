# 桌面安装包 CI/CD

`.github/workflows/desktop-installers.yml` 负责构建并发布桌面安装包。

## 触发方式

- Pull Request：构建 macOS / Linux / Windows 安装包并上传 workflow artifacts，不创建 GitHub Release。
- Push main：构建三平台安装包，成功后创建 GitHub Release 并上传产物和 `SHA256SUMS.txt`。
- workflow_dispatch：可指定 `source_sha`、`release_tag`、`openclaw_version`，也可关闭发布仅做构建验证。

## 产物

- macOS：`.dmg` 和 `.zip`
- Linux：`.deb` 和 `.tar.gz`
- Windows：NSIS `.exe` 安装器和 `.zip`

所有平台在打包前都会运行 `scripts/build_openclaw_desktop_bundle.sh`，把 Node.js 与 OpenClaw runtime vendoring 到 `assets/openclaw/<platform>/`，最终用户无需安装 Node、npm 或 OpenClaw。默认 OpenClaw npm 版本固定为 `2026.6.1`，手动 workflow dispatch 可覆盖。

## 可选签名与公证

macOS 发布支持以下 secrets。未配置时产物仍会构建并发布，但不会签名/公证。

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_CODESIGN_IDENTITY`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Windows 代码签名证书暂未接入；当前 workflow 产出可安装 NSIS 包和校验和。
