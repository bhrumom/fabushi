# GBF-409 — 全平台账号绑定电脑发现、人工/AI 远控与内置 Computer Use

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-409`
- Stage: `M4`
- Requirement IDs: `GBR-005`, `GBR-007`, `GBR-008`, `GBR-010`, `GBR-016`
- Status: `IN_PROGRESS`
- Source: `source/2026-08-28-universal-computer-control.md`; Codex session `01a04629-fda9-7e93-a6c2-0c42f9988b28`
- Branch: `codex/universal-computer-control`
- Started: `2026-08-28 10:19 +08:00`
- Updated: `2026-08-28 14:20 +0800`
- Completed: —
- Risk tier: high — computer control, persistent background process, native accessibility/screen capture, remote signaling, mobile WebView, package signing

## Objective

把安装后的 Fabushi 桌面端变成账号绑定、可发现但默认不可控制的电脑；在明确配对与控制授权后，由 Web/iOS/Android 用户或指定 Bot 通过同一 Mahayana 权限、会话和执行边界完成远控。把仓库现有 clean-room Computer Use 完整能力作为私有 stdio MCP 随桌面包发布，并支持语义优先、后台应用状态读取、坐标兜底和每步验证。

## In scope

- 桌面安装包内嵌内容寻址的 Computer Use runtime 与平台 helper；Mahayana Agent 自动注入私有 MCP。
- 登录后的设备注册/心跳与远控授权解耦；关闭窗口后托盘驻留。
- Bot 资料栏电脑状态、配对、启停、断开和控制页面入口。
- Web 人工输入、屏幕帧、Bot 自然语言请求及人类优先仲裁。
- iOS/Android 官方 origin 限制 WebView 入口。
- macOS/Windows/Linux 打包、安全、模拟用户 E2E 与精确 main SHA Release。

## Out of scope

- 绕过锁屏、UAC secure desktop、macOS TCC 或系统级权限。
- 将账号登录等同于远控授权。
- 引入 RustDesk/MeshCentral/noVNC 作为第二套身份、会话或 Agent 权威。
- 未经单独安全与许可审查的公网常驻原生远控监听服务。

## Dependencies

- GBF-202..205 Electron/Host/IPC 收敛。
- GBF-302..307 单一 Agent/tool/provider runtime。
- GBF-401..407 computer target、平台 adapter、敏感输入和重连语义。
- Fabushi 平台现有 remote-computer 配对、会话和 ICE signaling API。

## Acceptance criteria

1. 登录桌面端自动注册并周期心跳；远控关闭时可发现但不轮询/接受会话。
2. 配对、远控开关、客户端授权、device/session/client/generation 全部匹配后才可截图或输入；关闭/撤销立即断开。
3. 每个 Bot 资料栏显示电脑入口及真实状态；远端 AI 请求进入选定 Bot 的现有 `chat.send`/审批链。
4. 内置 MCP 覆盖完整 Computer Use registrar，使用私有 stdio、无 TCP listener；策略缺失/损坏/禁用时 fail closed。
5. macOS 可读辅助功能树与窗口截图并在允许时操作后台应用；Windows/Linux 使用现有 UIA/AT-SPI/X11 adapter；语义引用过期/变更后拒绝。
6. iOS/Android 仅允许 `https://fabushi.ombhrum.com`，拒绝证书错误/混合内容且无原生 bridge。
7. 所有受影响 PR 检查、安全矩阵、三桌面平台 package/E2E、Android instrumentation、iOS UI journey 和可视证据完整。
8. PR 经受保护 main 合并；精确 main SHA 产生可安装包、Updater 元数据与 GitHub Release；项目记录回填实际 run/asset/rollback 证据。

## Verification

- Static: JS/CJS/MJS syntax, JSON/plist/YAML parsing, `git diff --check`, source invariant guards.
- CI: main CI, Computer Control security, Electron packaged matrices, macOS hot/full path, native mobile, Apple delivery where credentials exist.
- E2E: desktop profile/presence/pairing/control-disable disconnect; human action; AI request; restricted mobile surface; package contains runtime/helper and launches private MCP.
- Security: fail-closed policy, stale generation/replay, target mismatch, revoked client, remote-disabled session polling, origin restriction and no network listener.

## Open-source survey and decision

- `rustdesk/rustdesk`: cross-platform capture/input and relay design is useful; AGPL client is not vendored into the proprietary application and would duplicate Fabushi identity/session authority.
- `Ylianst/MeshCentral` / MeshAgent: mature fleet/relay design under Apache-2.0; retained as a future isolated high-frame-rate provider behind Fabushi authorization, not required in this slice.
- `novnc/noVNC`: retained only as Linux/VPS compatibility reference; VNC does not provide semantic accessibility/background native app control。
- `webrtc-rs/webrtc`: MIT/Apache primitives remain a future option if media/signaling moves into Rust; current browser WebRTC reuses the already-deployed direct/ICE path.
- Grok Bot 0.18 reconstructed: VNC/noVNC human path and X11 model path are behavior references only; no unlicensed source is copied.

The implementation reuses Fabushi's existing account/session API, WebRTC signaling, `mahayana-computer` arbitration and clean-room Computer Use adapters rather than importing a second remote desktop product.

## Rollback

- Disable `remoteControlEnabled` and/or `aiComputerControlEnabled`; revoke paired clients and terminate active sessions.
- Revert the task PR to remove package staging, MCP injection, tray persistence and mobile entries while preserving pre-existing remote-computer APIs.
- If a release artifact is defective, withdraw that Release and republish from the last verified main SHA with a strictly higher version.

## Current implementation summary

Implementation is present in the task worktree and under active review. The resumed review corrected policy-path alignment, fail-closed authorization, signaling/session validation, account-scoped pairing state, mobile origin restrictions, packaged runtime verification and exact-main release gating.

## Evidence

- Branch/worktree: `codex/universal-computer-control` / `~/Documents/fabushi-remote-computer`; base equals protected `origin/main` at `dea04b588e07a45c5871f1c8027d8376d078ff04`.
- Original Codex session ended because workspace credits were exhausted, not because implementation or tests failed.
- Local Computer Control tests: 25/25 passed; packaged-runtime verifier 4/4 passed; native installer 3/3 passed; embedded source/security invariants 12/12 passed.
- Electron Host/IPC/auth/native-capability contract tests: 49/49 passed; canonical Host, Feature Host bridge, desktop architecture, edge parity, auth entry and native capability assertions passed.
- Changed JS/CJS/MJS syntax, workflow YAML, JSON, plist, project YAML, changed Rust `rustfmt`, `git diff --check` and secret-material scan passed.
- SQLite race simulation proved that client revocation atomically blocks new sessions plus signaling writes/reads; desktop close/open checks were hardened against control-disable races.
- Local TypeScript and full Cargo builds are intentionally delegated to GitHub-hosted CI because this sparse worktree has no JavaScript dependencies and the Mac data volume has less than 3 GiB free.
- Target unified release version/tag: `1.0.6` / `v1.0.6`; the remote tag is unused.
- PR, required CI, exact-main packaged E2E, Release and asset evidence: pending.

## Blockers / risks

- Cross-platform signing and package size must be proven in GitHub-hosted CI; local heavy builds are avoided because the Mac volume has limited free space.
- App Store submission can be blocked by external certificate/profile/account availability even when source/package gates pass; record exact external status rather than claiming publication.

## Next action

Complete lightweight verification, submit the protected-main PR, resolve every required CI check, merge, tag the exact main SHA, run the unified release workflow and backfill actual evidence.
