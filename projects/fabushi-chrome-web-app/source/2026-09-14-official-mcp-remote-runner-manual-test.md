# 官方 MCP 远程 GitHub Actions 浏览器手测增量

Date: 2026-09-14. Project: FAB-P0011 / CWA. Task: CWA-007.

用户最新要求：Fabushi 官方插件登录官方测试账号，并通过官方 `fabushi test` MCP 发现同账号的插件；启动或接入 GitHub Actions 中的远程浏览器后，直接连接并手动执行验收，避免只依赖本地或间接的盲测。

本增量复用 CWA-007 已实现的账号隔离与 `/browser-agent` 注册链路，不新增第二套浏览器控制协议，也不把测试账号凭据写入仓库、脚本或项目记录。GitHub Actions Runner 使用受保护的 `FABUSHI_CI_TEST_USERNAME` / `FABUSHI_CI_TEST_PASSWORD`，远程手测必须绑定同一专用账号和待验收的 exact SHA。

新增验收要求：

- CWA-R019：插件可在受信任扩展页面完成官方账号登录，浏览器会话只保留短期内存态，不持久化可复用刷新凭据。
- CWA-R020：官方 MCP 能列出同账号的 Runner/Chrome device，先读取工具描述，再通过 `ci_session_status` 确认 GitHub Actions 远程浏览器状态。
- CWA-R021：针对 exact SHA 的远程浏览器完成脚本内存状态、手动清理/宿主回收、标签切换后恢复与连续任务不中断的逐步手测，并保留截图、视频、trace/报告和 session note/finish 证据。

当前核验：

- `https://fabushi-mcp.ombhrum.com/health` 返回 HTTP 200，官方 MCP 服务在线，MCP 路径为 `/mcp`，浏览器代理路径为 `/browser-agent`。
- 当前 `fabushi test` 连接器已暴露账号、设备列表、设备工具描述和设备调用入口，但本任务环境调用账号/设备列表均返回 `Mcp error: -32603: Internal error`；这不是远程服务健康检查通过的证明，也不能据此伪造测试账号或设备身份。
- 因连接器内部错误且没有可安全读取的测试账号凭据，CWA-R020/CWA-R021 的远程手测暂未执行，状态保持 `IN_PROGRESS / REMOTE_MANUAL_PENDING`。连接恢复或由授权用户完成登录后，应按 runbook 顺序执行并回写 exact-SHA 证据。
