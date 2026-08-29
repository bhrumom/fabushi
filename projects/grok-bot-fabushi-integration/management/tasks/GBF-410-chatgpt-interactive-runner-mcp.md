# GBF-410 — ChatGPT 同账号 MCP 实时控制 GitHub Actions Runner

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-410`
- Stage: `M4`
- Requirement IDs: `GBR-005`, `GBR-007`, `GBR-010`, `GBR-016`, `GBR-017`
- Status: `IN_PROGRESS`
- Source: `source/2026-08-29-chatgpt-runner-mcp-control.md`
- Branch: `codex/interactive-runner-mcp`
- Started: `2026-08-29 17:49 +08:00`
- Updated: `2026-08-29 21:51 +0800`
- Completed: —
- Risk tier: high — remote computer input, account/OAuth boundary, temporary CI credentials, public WebSocket/MCP endpoint, evidence retention

## Objective

把 Fabushi 的账号绑定电脑控制能力标准化为 ChatGPT 可添加的远程 MCP；同一 GitHub-linked Fabushi 账号的 GitHub Actions Runner 作为短寿命设备主动连接，允许外部 AI 在构建期间和安装包启动后实时控制 Runner 桌面、测试 Fabushi、记录证据并把成功操作编译为后续自动化候选。

## In scope

- Streamable HTTP MCP、OAuth metadata、动态客户端注册、Authorization Code + PKCE、刷新令牌。
- Fabushi 浏览器登录与 MCP 账号映射；MCP 令牌不保存原始 Fabushi credential。
- 账号隔离设备网关、短租约、心跳、工具 schema 同步、远程调用与审计。
- 支持 HTTP/stdio 本地 MCP 的 Runner agent；包内 Electron + stdio MCP 切换。
- GitHub Actions X11 桌面、构建前上线、正式包启动、同账号测试登录、实时状态、远程结束和证据上传。
- 脱敏 trace 到 generated-regression 的转换与审查提示。

## Out of scope

- 绕过 Runner/OS 权限、锁屏、secure desktop 或敏感输入批准。
- 允许仅凭设备 ID 或全局共享网关令牌跨账号控制。
- 把长期测试账号密码写入仓库、MCP token、日志或 artifact。
- 自动把一次人工 trace 无审查提升为 required gate。
- 引入第二套长期远控、账号或 Agent runtime。

## Acceptance criteria

1. `/mcp` 可被标准远程 MCP 客户端添加，OAuth 完成后仅返回该 Fabushi 账号的在线设备。
2. 设备网关验证 Fabushi bearer，并用 `accountId + deviceId` 作为权威键；同 ID 跨账号不可见、不可调用。
3. Runner agent 可代理完整包内 Computer Use stdio MCP，凭据不进入子进程，公网仅允许 WSS，断连/租约到期立即离线。
4. GitHub Actions 工作流在构建前注册设备，打包后以同一设备 ID 切换到安装包内 runtime，启动正式 Fabushi，并以 workflow actor 已绑定的同一 Fabushi 账号启动短时会话。
5. AI 可通过 `ci_session_status`、电脑控制工具、`ci_session_note`、`ci_session_finish` 完成 live journey；未远程完成、应用提前退出或超时时门禁失败。
6. 调用 trace 脱敏且不记录 secure-input envelope；artifact 白名单不包含账号会话/令牌；成功动作生成待审查 regression JSON。
7. 全部 Node/Rust/打包/工作流测试通过；远程服务部署为 HTTPS/WSS；真实 Runner 从 ChatGPT 完成至少一个状态读取、应用操作、备注和远程结束闭环。

## Verification

- Unit/integration: account auth/session, OAuth PKCE/DCR, account-scoped gateway, stdio agent round-trip, CI session tools, trace compiler.
- Security: token non-forwarding, WSS enforcement, expiry/revocation, same-device cross-account isolation, redacted artifacts, exact-repository GitHub Actions OIDC, linked-account lookup and non-refreshable CI session.
- Package: runtime required files + source hash + packaged MCP handshake.
- Live CI: source agent online during build, packaged agent takeover, Electron window/AX state, remote action, video/screenshot/trace, `ci_session_finish`.

## Rollback

- Disable or remove `interactive-runner-mcp.yml`; unset the gateway repository variable.
- Stop the remote MCP service and revoke/delete its local state file; ordinary GBF-409 private stdio Computer Use remains intact.
- Revert GBF-410 files; the GitHub Actions OIDC exchange is accepted only for the exact protected-main workflow and linked Fabushi identity.

## Account-binding hardening

- Runner identity now uses GitHub Actions OIDC instead of `TEST_ACCOUNT_TOKEN` or stored username/password.
- Trust is bound to repository/owner IDs, protected `main`, exact workflow ref/SHA, workflow_dispatch, github-hosted Runner, short OIDC age and derived `gha-<run>-<attempt>-interactive` device ID.
- `actor_id` must already exist as a GitHub identity on the Fabushi account; the issued access session is private-file-only, non-refreshable and capped at four hours.
- ChatGPT sees the Runner only after signing into MCP with the same GitHub-linked Fabushi account.

## Evidence

- Local Node end-to-end covers OAuth -> MCP -> account-scoped Runner WebSocket -> stdio tool call -> refresh.
- Account gateway same-ID isolation and unknown bearer rejection pass.
- CI status/finish/note, trace compiler, package required-file checks and GitHub OIDC linked-account binding, private CI session files and no-shared-token contracts are implemented.
- PR, remote deployment, exact workflow run, live ChatGPT interaction and uploaded artifact IDs: pending.

## Next action

Finish full local source validation, deploy the remote MCP endpoint, merge through protected main, trigger the interactive workflow, connect ChatGPT with the same GitHub-linked Fabushi account, complete the live Runner journey, fix all failures and backfill exact evidence.
