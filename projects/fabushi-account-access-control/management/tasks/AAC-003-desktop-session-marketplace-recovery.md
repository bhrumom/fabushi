# AAC-003 — 桌面撤销会话恢复、退出登录与公开市场搜索

## 用户需求

2026-08-26：用户在 macOS Fabushi 1.0.941 中看到 `refresh_token_reused: 登录会话已撤销，请重新登录`，同时新的 Telegram 风格 Messenger 找不到“退出登录”，全局“应用”搜索也错误显示没有匹配的在线应用。要求完全修复并发布一个新版本。

## 现场证据与根因

1. macOS 当前安装 `/Applications/Fabushi.app` 为 1.0.941，GitHub 当时 Latest 也是 1.0.941，因此不是单纯旧版本问题。
2. 同一台 Mac 直接访问生产 `/v1/marketplace/plugins?platform=desktop` 可返回 9 个应用，包括 `global-dharma / 全球法布施`，说明生产 Marketplace 已恢复。
3. `MahayanaProductClient::marketplace_browse`、release metadata 与 download 仍调用 `optional_authorization_token`。公开市场读取会因此触发已撤销 refresh token 的刷新流程，401 会在真正的公开 Marketplace 请求之前失败。
4. `auth_status` 在访问 `/api/auth/user-info` 之前先调用 `active_session_token`；刷新阶段的 `refresh_token_reused` 会直接抛错，绕过原本只处理 user-info 401 的 `loggedIn:false` 分支。Desktop Shell 又把所有 `authStatus()` 异常当临时网络故障，因此旧 Messenger 投影持续留在屏幕。
5. 新 `messaging-shell-v2` 的 General 设置页没有迁移旧 HostClient 已有的 `transport.logout()` 入口。
6. `refreshMiniApps` 使用 `Promise.all(marketplaceBrowse, pluginListInstalled)`，任一子请求失败会丢弃另一个已成功结果并误呈现“没有应用”。

## Open-source-first 启动门禁

- 检索 `signalapp/Signal-Desktop` 的账号/退出相关桌面边界，确认成熟桌面客户端将账号退出视为显式会话生命周期动作，而不是仅隐藏 UI。
- Fabushi 已有更直接且兼容的成熟内部边界：旧 HostClient 的 `transport.logout()`、Rust `MahayanaProductClient::logout()`（服务端撤销 best-effort、随后始终删除本地 session）以及现有 Native persistence API。优先复用这些边界，没有复制第三方源码。
- 不引入新的认证框架；仅修复现有 Rust session 状态机与统一 Messenger 的迁移遗漏。

## 实施

- Rust Product：公开 Marketplace browse/release/download 不再依赖账号 token 或触发 refresh。
- Rust Product：刷新阶段遇到 401/终止型 session 错误立即清理 Rust-owned 本地 session；`auth_status` 将其转换为 `loggedIn:false`，而不是继续抛成“临时网络错误”。
- Desktop Shell：新增终止型认证错误分类；`refresh_token_reused` / session revoked / 401 等自动清理账号级快速启动缓存并切回登录页，普通 5xx/网络波动仍保留 local-first shell。
- Messenger General：恢复“退出登录”按钮，调用同一个 Host logout 边界；清理 projection、draft、conversation journal 与 native projection mirror，保留设备级外观/偏好。
- Marketplace UI：browse 与 installed list 改为独立 settle，公开搜索成功时不会因另一个请求失败而被丢弃。

## 验收条件

- [ ] `refresh_token_reused` 不再让桌面停留在旧 Messenger；本地会话被清理并回到登录页。
- [ ] General 设置中存在可见、可操作的“退出登录”。
- [ ] 退出登录后账号级 projection/draft/conversation journal 均被清理，重新登录可恢复正常 Messenger。
- [ ] 未登录或本地存在已过期 session 时，公开 Marketplace browse 不发送 Authorization、也不触发 refresh，仍能发现 `global-dharma`。
- [ ] 搜索“全球法布施”可显示 `global-dharma`；生产 Marketplace 结果不会因 installed-list 子请求失败而被整批丢弃。
- [ ] Rust targeted regression、Renderer build、Electron E2E/CI 通过。
- [ ] PR 通过 protected main / merge queue 并合入 canonical `main`。
- [ ] exact-main Electron/macOS/Windows/Linux package + required post-main E2E 通过。
- [ ] GitHub Release 发布严格高于 1.0.941 的新 desktop 版本，包含 updater-compatible macOS/Windows/Linux assets。
- [ ] macOS 旧版能够发现新版本，并对新包进行版本/搜索/退出登录实机回归。

## 状态

in-progress


## 2026-09-06 — Global Dharma Mini App controlled-session projection

Cross-project consumer: `FAB-P0001 / M9-GLOBAL-DHARMA-003`. The desktop Mini App bridge now receives only a bounded authenticated account projection (`loggedIn`, provider, public account identity fields, `tokenExposed:false`) from the existing Host session. Raw access/refresh tokens are not copied into the Mini App contract. The durable Mini App execution revision is account-scoped and is deleted from localStorage, native persistence and renderer cache on `MAHAYANA_ACCOUNT_SESSION_RESET_EVENT`. Acceptance remains pending protected CI and exact-main packaged Electron evidence; this entry does not close AAC-003.
