# AAC-002 — 桌面登录平台恢复与发布闭环

## 背景
Windows 桌面端浏览器登录出现 `platform_control_plane_unavailable` / HTTP 502；随后 Mahayana 平台 Worker 恢复部署后 `/health` 持续 HTTP 500，阻断浏览器登录、注册验证与桌面正式发布。与此同时 Windows 构建在 CRLF checkout 下会导致桌面品牌预处理脚本匹配失败。

## 根因
1. `mahayana-platform-worker/src/worker_api.rs` 重复注册了同一组 developer-commerce GET/POST 路由。官方 `cloudflare/workers-rs` Router 实现对 `matchit::Router::insert` 的注册错误直接 `panic!`，因此 Router 在每次请求构造时即崩溃，连 `/health` 也返回 500。
2. `desktop/scripts/prepare-desktop-window-branding.mjs` 过去按 LF 精确匹配，Windows checkout 的 CRLF 导致品牌预处理失败。

## Open-source-first 证据
已核对官方 `cloudflare/workers-rs` 的 `worker/src/router.rs`：`add_handler` 对重复/冲突路由的 `insert` 结果使用 `unwrap_or_else(... panic!(...))`。本修复仅依据其公开行为定位根因，不复制上游实现。

## 实施
- 删除 Mahayana Worker 第二组重复 developer-commerce 路由，保留 payout/profile/request 与完整 miniapp/product/advanced-commerce 路由。
- 增加回归测试，确保相关 method/path 注册只出现一次。
- Windows/macOS 桌面品牌预处理先规范化 CRLF/LF，再按原 EOL 写回。
- 通过 PR CI、Electron desktop gate、受保护 main merge queue。
- main 合并后重新部署 Mahayana 平台并验证 `/health`、browser start/poll/cancel、注册页与 OAuth provider lifecycle。
- main exact-SHA 桌面打包/E2E 全绿后发布 Windows/macOS 新版本与 updater-compatible Release 资产。

## 验收条件
- [ ] Mahayana 平台 `/health` 返回 200 且 `{ "ok": true }`。
- [ ] `/api/auth/browser/start` 返回有效 attempt、pollSecret 与同源 portal URL。
- [ ] 浏览器登录/注册/provider lifecycle 自动验证通过。
- [ ] Windows 构建不再因 CRLF 失败。
- [ ] Windows/macOS 应用名统一为 Fabushi，Windows 图标存在，原生顶部名字框不再显示，登录后可退出登录。
- [ ] 修复合并进 canonical `main`。
- [ ] canonical main exact-SHA packaged user E2E 通过。
- [ ] GitHub Release 发布新的 Windows/macOS updater-compatible 安装资产。

## 状态
in-progress
