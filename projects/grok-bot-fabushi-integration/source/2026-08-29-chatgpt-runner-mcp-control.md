# 2026-08-29 — ChatGPT 通过 Fabushi MCP 实时控制 GitHub Actions Runner

## 原始目标

1. Fabushi 对外提供标准远程 MCP，而不是由应用内部 AI“自己控制自己”。
2. ChatGPT 把该 MCP 添加为连接器并登录 Fabushi 测试账号；MCP 只能发现同一账号下主动上线的设备。
3. GitHub Actions Runner 在工作流期间使用同一测试账号启动控制代理；代理以出站 WebSocket 注册临时设备，并把本机 Fabushi Computer Use stdio MCP 的工具目录和调用结果转发给远程 MCP。
4. AI 可以在构建开始前看到 Runner，实时读取构建/安装/启动状态；安装包就绪后同一个设备 ID 切换到包内 MCP 运行时，启动正式 Fabushi 并完成黑盒操作。
5. 远程测试过程保留脱敏调用 trace、屏幕视频、最终截图、日志和人工备注；成功动作可编译成待审查的自动化回归动作文件。
6. Runner、设备租约、OAuth 会话和证据都必须是短寿命、可审计、可撤销并在工作流结束时清理。

## 架构边界

- MCP 身份映射到 Fabushi 账号；设备注册、发现、工具描述和调用都按账号隔离，不能仅凭设备 ID 跨账号访问。
- ChatGPT OAuth 令牌只保存稳定账号标识和授权范围，不持久化原始 Fabushi 登录令牌。
- 设备代理只向远程网关发送 Fabushi access token；该凭据不会传入本地 Computer Use MCP 子进程、模型上下文或证据包。
- 公网设备通道必须使用 `wss://`；明文 `ws://` 仅允许 loopback 测试。
- GitHub Actions 测试账号自动登录需要 `GITHUB_ACTIONS=true`、显式 `FABUSHI_CI_TEST_ACCOUNT_AUTOLOGIN=1` 和现有测试账号令牌三者同时满足。
- 本地 Computer Use 仍由 fail-closed 策略、辅助功能权限、敏感输入安全通道和操作后重新读取约束；远程 MCP 不建立旁路原生输入协议。
- 工作流上传证据时明确列出文件，不上传账号会话、策略之外的临时目录或凭据文件。

## 开源与标准调研

- Model Context Protocol 官方 SDK/规范：采用 Streamable HTTP、工具目录、OAuth protected-resource metadata、Authorization Code + PKCE 和动态客户端注册。
- Cloudflare Agents SDK MCP handler：其远程 Streamable HTTP Worker 部署模式可作为未来无服务器迁移路径；当前实现继续复用 Fabushi 已有账号 API、设备网关和发布架构，不引入第二个 Agent/身份权威。
- GitHub Actions 官方 Runner 模型：Runner 是临时环境并允许出站网络连接，因此设备代理按工作流重新注册、使用短租约并在 job cleanup 时退出。
- 现有 GBF-409：复用完整 clean-room Computer Use registrar、账号边界、敏感输入和打包完整性验证，不引入 RustDesk/MeshCentral/VNC 第二套控制协议。

## 验收口径

- ChatGPT 可通过 `/mcp` 完成 OAuth 并得到账号限定的 `list_devices`、`describe_device_tool`、`device_call`。
- 两个账号使用相同设备 ID 时仍完全隔离；未知或过期 bearer 被拒绝。
- Runner 可在应用构建前上线，报告阶段；打包后切换到包内 MCP 并启动同账号 Fabushi。
- AI 能读取应用状态、执行 UI 操作、写测试备注，并通过 `ci_session_finish` 结束 live window。
- 工作流生成脱敏 trace、视频/截图、状态、备注和 generated-regression；超时、应用退出或未远程完成时明确失败。
- Node 单元/集成测试、Rust 双重 opt-in 测试、打包清单、workflow syntax/security gate 和真实 GitHub Actions live journey 全部通过。

## 2026-08-29 安全澄清：Runner 账号绑定

原始需求中的“同一测试账号”保留为同账号语义，但不再由全局 `TEST_ACCOUNT_TOKEN` 模拟。最终实现使用 GitHub Actions OIDC：只有受保护 `main` 上的 `interactive-runner-mcp.yml`、官方 GitHub-hosted Runner、精确仓库/组织 ID、精确 source SHA 和短时 OIDC assertion 才能换取最多四小时且不可刷新的 Fabushi Runner 会话。平台以 workflow actor 的 GitHub `actor_id` 查询已绑定的 Fabushi GitHub identity；ChatGPT 必须用同一个 GitHub/Fabushi 账号完成 MCP OAuth，才能发现该 Runner。未绑定 GitHub 身份、fork、非 main、非受保护 ref、过期 assertion 或 device/run 不一致全部 fail closed。

该澄清取代上文关于 `FABUSHI_CI_TEST_ACCOUNT_AUTOLOGIN` 与共享测试令牌的具体实现描述；不改变“同一账号才能发现设备”的原始目标。
