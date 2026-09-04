# TFI-CLOSE-001 — 完整推进 FAB-P0001 全部未闭环要求

- **Portfolio Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `TFI-CLOSE-001`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-09-04`
- **Updated**: `2026-09-04`
- **Owner**: Fabushi maintainers / current task owner
- **Source**: `../../source/2026-09-04-full-project-completion.md`; `../../source/完整telegram融合进fabushi.txt`

## Objective

按 TFI 项目源计划与 M0–M14 WBS 完成所有尚未达到 `RELEASED` 的功能和交付闭环：自有 Rust 消息核心、自建实时网络、桌面完整交互、媒体、联系人/群组、频道/Topic、Bot/Agent、Mini Apps、支付、音视频、iOS/Android 共享核心、高级 IM、安全/E2EE 及旧通信栈退出。

## In scope

- 复核并推进所有当前 `NOT_STARTED`、`IN_PROGRESS`、`TESTING`、`IMPLEMENTED`、`RELEASE_BLOCKED` 的 M3–M14 WBS 项。
- 复用现有 canonical `native/mahayana-messaging`、Mahayana Host/Pay/MiniApp 边界和共享客户端契约。
- 补齐服务端边界、权限、幂等、离线/重连、错误恢复、指标/日志、跨端绑定和测试证据。
- 为每个影响产品的合并 SHA 走 GitHub Actions packaged build、模拟用户 E2E、完整截图/视频/trace/report、Release 和 canonical-main 回读闭环。

## Out of scope

- Telegram 官方 API、Bot API、MTProto、品牌资源或不可兼容许可代码。
- 以本机编译/打包/原生模拟器运行替代 GitHub Actions 验证。
- 在未具备真实第三方 PSP、KYC、App Store/Play 资格或凭据时伪造支付、结算或商店发布成功。

## Dependencies

- Canonical GitHub `main` and protected merge queue.
- Existing M0–M2 protocol/storage/realtime contracts.
- Existing Mahayana Host, MiniApp, WebMCP and Rust Pay contracts.
- CI secrets, platform signing credentials, provider sandbox/production credentials and device runners where the acceptance item requires them.

## Acceptance criteria

1. Every applicable WBS item M3–M14 has an explicit implementation state and evidence; no planned item is silently treated as complete.
2. Canonical messaging, identity, conversation, media, MiniApp, payment and security boundaries remain single-source and authorization checks fail closed.
3. Required Rust, frontend, contract, integration, native and packaged E2E checks pass on GitHub Actions for the exact accepted `main` SHA.
4. Required E2E evidence retains labelled checkpoint screenshots, complete journey video, trace/HTML report and platform-native logs/reports with SHA, version, run, test id and timestamp.
5. Every application-affecting accepted SHA has a traceable newer Release with installable/updater-compatible assets where applicable.
6. M14 proves dependency-zero removal of frozen Telegram runtime/provider paths without hidden fallback and with migration/rollback evidence.
7. TFI project records (task, WBS, milestone, acceptance matrix, status, changelog, risks, dependencies, issues/actions and evidence indexes) match live GitHub facts.

## Verification plan

- Lightweight local: source/config/diff/search inspection only; no application build, package, emulator, simulator, integration, E2E or full-suite run.
- GitHub Actions: use the narrowest existing workflow per change, restore valid caches/artifacts, record cache/warm-build data, and retain pass/fail evidence on an always-run path.
- Delivery: protected PR merge, canonical-main readback, exact-SHA packaged E2E, Release asset/version/SHA verification, and applicable deployment/migration smoke.

## Open-source-first survey and decision

- Matrix Synapse: use as a reference for self-hosted service decomposition, sync/federation operations and reverse-proxy deployment; reject direct protocol/runtime adoption because TFI requires its own Rust Protocol v2 and product boundary. Apache-2.0.
- Element Web: use as a reference for mature Messenger/Web/Electron surface organization and acceptance coverage; reject direct code/UI reuse because its AGPL/GPL/commercial licensing and branding boundary do not fit this integration. No dependency added.
- Signal libsignal: use as a reference for Rust-backed cross-language cryptographic boundaries and key lifecycle testing; defer direct dependency until M13 security and license review explicitly accepts it. AGPL-3.0.
- Full source-backed record: `../../source/2026-09-04-full-project-completion.md`.

## Branch / PR / evidence

- **Branch**: current task branch to be recorded after implementation branch is stabilized.
- **Commit / PR**: pending.
- **CI / E2E / Release**: pending; must be recorded per stage and exact canonical SHA.

## Current implementation summary

The canonical `main` audit confirms M0–M2 are tested, while M3/M7/M8/M9/M11 have partial or pending closure and M4/M5/M6/M10/M12/M13/M14 contain unstarted WBS items. Existing branches may contain candidate work but are not evidence of canonical completion. This task begins by closing the earliest unmet canonical dependencies and will update this record after each governed round.

## Risks / blockers

- Scope spans multiple independent product domains and cannot be truthfully closed in one local pass.
- GitHub review, protected merge, CI capacity, platform signing, external provider credentials and device runners can block delivery after code is ready.
- Current worktree contains pre-existing untracked `fabushi/native_libs/`; it is intentionally preserved and excluded from this task.

## Next action

Audit canonical `main` code against M4/M5 entry points, select the first smallest missing vertical slice, and implement it with contract tests plus project evidence in the same PR.
