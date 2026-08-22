# M0.T01 — 审查现有 Fabushi 通信相关代码

- **Project**: `FABUSHI-TELEGRAM-FUSION`
- **Task ID**: `M0.T01`
- **Stage**: `M0 现状清点与边界固定`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Source**: `../../source/完整telegram融合进fabushi.txt`; `../wbs/M0.md`

## Objective

以 GitHub `main` 的真实代码、已合并 PR 与 CI 事实为依据，审查当前 Fabushi 通信实现，纠正项目基线中“全部 NOT_STARTED”的占位状态，并确定唯一通信核心、客户端桥、旧栈边界以及下一阶段最早未满足的验收门槛。

## In scope

- `native/mahayana-messaging/**`
- `desktop/**` 中 Messenger / native bridge / WebRTC 相关路径
- `third_party/mahayana/mahayana-rs/**` 中 Feature Host、social、旧 Telegram provider/runtime 路径
- 与通信核心直接相关的 GitHub Actions / E2E
- 已合并 PR #1961 及其最终收敛提交在当前 `main` 的事实核对

## Out of scope

- 不凭代码存在直接宣称后续功能 `TESTED` / `E2E_VERIFIED` / `RELEASED`。
- 不在本任务中删除旧 Telegram 栈；实际删除归 M14，并必须先完成依赖清零和迁移证明。

## Acceptance criteria

1. 当前通信实现有可追踪清单，并标明唯一核心路径和旧/兼容路径。
2. 已合并实现有 commit/PR/文件证据。
3. 历史 CI 失败与当前源码状态分开记录。
4. 明确最早未满足的阶段/任务。
5. 更新 WBS、状态报告、验收矩阵和迁移 ADR。

## Verification completed

- PR #1961 已合并，merge commit: `8062abb850020a702b4c8a85d8bd23d6b0470cb2`。
- `native/mahayana-messaging` README/lib/protocol/store/service 等当前 `main` 源码已核对。
- 旧 `native/telegram-runtime` 与 `third_party/mahayana/mahayana-rs/providers/telegram-*` 当前仍存在。
- 历史 Messaging Product Gate 的 `reply_to_message_id` 类型错误已与当前 `service.rs` 对比；当前源码已经显式转换 `MessageId.0`，该具体错误已不在当前源码中。
- 当前 `store.rs` 只有 Memory / JSON snapshot，没有 SQLite，实现确认 M1.T06 尚未满足。

## Branch / PR

- Branch: `project/telegram-m0-live-audit`
- PR: pending creation

## Implementation summary

- 新增 `docs/20-现状审计与迁移边界.md`，固定现有实现、迁移边界、workspace 与 canonical protocol。
- 新增 ADR-0008：`native/mahayana-messaging` 为唯一 canonical Messaging Core；旧 Telegram network/provider/runtime 全部冻结。
- 回填 M0.T01-T07 为 `IMPLEMENTED`，但在 PR 合并前 M0 整体仍是 `IN_PROGRESS`。
- 更新 feature/acceptance matrix，区分“代码已实现”与“当前 CI/E2E 已验证”。
- 将 M1.T06 SQLite schema/storage 识别为下一最早明确功能缺口。

## Evidence

- Canonical implementation: `native/mahayana-messaging/**`
- Merged implementation: PR #1961 / `8062abb850020a702b4c8a85d8bd23d6b0470cb2`
- Audit: `../../docs/20-现状审计与迁移边界.md`
- Decision: `../../decisions/ADR-0008-canonical-messaging-core-and-legacy-freeze.md`
- Matrix: `../03-验收追踪矩阵.md`
- WBS: `../wbs/M0.md`
- CI evidence: historical run documented; current branch CI pending PR creation

## Blockers / risks

- 当前-head CI 尚未产生，因此不能将本轮提升到 `TESTED`。
- 旧 Telegram crates 仍被保留，实际删除必须等 M14 依赖清零。

## Next action

创建 PR 并取得 CI/merge 证据；主干验收后立即领取 M1.T06，增加 SQLite schema 与 durable local-first storage，而不是继续新增另一套 UI/消息核心。
