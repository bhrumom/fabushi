# 2026-08-23 — Online Mini App Marketplace convergence

## User requirement

官方 Mini App 与第三方 Mini App 使用同一线上安装模型：不在 Messenger 中维护内置 `defaultMiniApps` 清单；用户在 Mini Apps 入口搜索线上 Marketplace，安装经过审核的 release，安装后才能打开、更新或卸载。

## Implementation

- Electron Mahayana edge 暴露 `marketplace.browse` / `marketplace.release` 与 plugin install/active/list/uninstall/UI document 方法。
- Renderer `MahayanaHostTransport` 使用同一版本化 edge，不走退役 generic IPC。
- Unified Messenger 删除 `defaultMiniApps`，Mini Apps 左栏与 workspace 都改为在线搜索结果。
- 安装路径读取 approved `mahayana.external-release.v1` manifest，再交给 Rust `PluginInstaller` 下载、哈希验证、版本化落盘和 active pointer 切换。
- Rust AppHost 新增 installed-plugin enumeration；Mini App UI 只从当前已安装版本目录读取，未安装应用禁止打开。
- 增加 CI guard，禁止 unified Messenger 恢复 bundled `defaultMiniApps` registry。

## Local evidence

- `git diff --check` PASS。
- `node --check desktop/electron/mahayana-edge.cjs` PASS。
- `.github/scripts/assert-electron-feature-host-bridge.sh` PASS（补齐 sparse paths 后执行）。
- GitHub required checks 与 protected merge 仍是最终 TESTED 条件。
