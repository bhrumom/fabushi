# GBF-412 — Tailscale-inspired 跨平台账号设备网格

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-412`
- Stage: `M4`
- Status: `IN_PROGRESS`
- Started: `2026-08-31`
- Updated: `2026-08-31`
- Branch: `codex/tailscale-mobile-device-mesh`
- PR: pending
- Source: `source/2026-08-31-tailscale-cross-platform-device-mesh.md`
- ADR: `decisions/ADR-0008-tailscale-inspired-account-device-mesh.md`
- Risk tier: high — remote device identity, cross-platform control, mobile lifecycle, network transport

## Objective

在 GBF-409/410/411 的正式链路上融合 Tailscale 的节点身份、控制面/数据面分离、路径迁移、租约、健康与故障测试优势，让同一 Fabushi 账号下登录的 Electron、Android、iOS 和临时 GitHub Actions Runner 使用一个可验证设备网格被发现和控制。

## In scope

- 持久 P-256 节点身份、签名注册、节点指纹和重放/伪造拒绝。
- 版本化 mesh 状态：features、tags、posture、supported/preferred/active path。
- 当前 WSS relay 路径显式化、健康与重连状态；保留未来直连协商扩展点。
- 现有账号隔离、设备租约、动态工具目录、secure input、App MCP、Computer Use 与审计不回归。
- Android/iOS 原生 device agent，发布共享 `fabushi.app.*` 合同并执行受控调用。
- 平台安全存储与生命周期：Android Keystore/foreground service；Apple Keychain/CryptoKit/URLSessionWebSocketTask/后台状态。
- GitHub Actions 单元、协议、安全、Android/iOS 编译与 live test-account Runner 验收。
- Tailscale BSD-3-Clause 研究与来源记录。

## Out of scope for the first accepted increment

- 未经单独安全评审的系统级 VPN、出口节点、子网路由或 DNS 接管。
- 在没有真实直连证据时宣称已实现 WireGuard/P2P 直连。
- 绕过 iOS/Android 平台后台、权限、通知或应用商店规则。
- 使用节点密钥替代 Fabushi 账号授权；两者必须同时成立。

## Acceptance criteria

1. 新注册设备必须同时通过 Fabushi 账号认证与节点签名验证；旧兼容设备明确标记 `signed=false`，迁移门关闭后可被策略拒绝。
2. 修改 device id、connection generation、tool schema version、nonce 或公钥后，原签名必然验证失败。
3. 同一 device id 在不同账号下仍隔离；同账号重连会关闭旧 socket 并拒绝旧 generation 的挂起调用。
4. `list_devices` 返回 mesh 协议、节点指纹、签名状态、路径、标签、姿态与 schema 版本，且不返回私钥、access token、cookie 或敏感 UI 值。
5. Electron 打包应用登录后注册为签名节点，完整 `computer_*` 和 `fabushi.app.*` 工具不回归。
6. Android 安装/登录后可注册并响应 App MCP status/snapshot/find/action/wait/assert；持久在线只在用户可见前台服务与允许条件下运行。
7. iOS 安装/登录且应用活动时可注册并响应相同工具；系统挂起后准确离线，支持安全重连和系统允许的后台唤醒。
8. GitHub Actions 使用已配置测试账号启动临时签名节点，`@fabushi test` 能发现、读取 schema、调用状态并确认账号标签 `fabushi_mcp_ci_test`。
9. 节点签名、账号隔离、租约、重连、路径 fallback、工具上限、移动端输入脱敏和安全存储合同均有自动化测试。
10. PR required checks 通过并合入受保护 `main`；exact-main package/E2E/live MCP evidence 完整后方可标记完成。

## Current evidence

- `@fabushi test` account: `fabushi_mcp_ci_test` (`197915874789377`).
- Live Runner discovered: `gha-33346933085-1-interactive`, workflow run `33346933085`, 25 dynamic tools.
- Live `fabushi.app.status` result currently reports unavailable because the running desktop package is not publishing the App Agent Surface; this is an active acceptance failure, not a waived condition.
- Initial clean-room mesh identity module committed on the task branch.

## Verification plan

- Node protocol/unit tests for identity persistence, file mode, canonical signature, mutation rejection and safe public state.
- Gateway integration tests for account isolation, signed registration, legacy marking, reconnect and call routing.
- Agent integration tests for registration envelope, heartbeat posture and no-private-key leakage.
- Android JVM/instrumentation tests plus packaged emulator journey.
- iOS unit/UI tests plus packaged Simulator journey.
- Live GitHub Actions Runner registration and remote plugin calls using the existing test account.
- CI artifacts retain logs, screenshots/video/trace where applicable and exact commit/run metadata.

## Next action

Integrate the signed mesh module into the Node agent/gateway, establish CI security tests, then add native Android/iOS adapters and run the live account journey against the branch package.
