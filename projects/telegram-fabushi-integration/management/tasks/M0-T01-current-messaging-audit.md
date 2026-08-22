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
- 已合并 PR #1961 及后续修复/收敛提交在当前 `main` 的事实核对

## Out of scope

- 本任务不凭代码存在直接宣称后续功能 `TESTED` / `E2E_VERIFIED` / `RELEASED`。
- 不在本任务中删除旧 Telegram 栈；删除归 M14，并必须先完成依赖审计和迁移证明。

## Dependencies

- GitHub `main` 可读。
- 项目基线 `projects/telegram-fabushi-integration/` 已存在。

## Acceptance criteria

1. 形成当前通信实现的可追踪清单，并标明唯一核心路径和旧/兼容路径。
2. 对已合并实现给出 commit/PR/文件证据，不能只依赖聊天记忆。
3. 对 CI 历史失败与当前代码是否已修复作出区分。
4. 给出最早未满足的阶段/任务，作为下一实现入口。
5. 更新 WBS、状态报告、验收矩阵和证据索引；状态不得高于现有客观证据。

## Verification

- GitHub file/PR/commit inspection on authoritative `main`.
- PR #1961 changed-file inventory and merged commit evidence.
- Historical Messaging Product Gate log compared with current `main` source.
- 新 PR 的 GitHub Actions 作为本轮文档/架构变更最终门禁。

## Branch / PR

- Branch: `project/telegram-m0-live-audit`
- PR: pending

## Implementation summary

In progress.

## Evidence

Pending final round update.

## Blockers / risks

- 历史 PR 检查存在失败记录，不能把“已合并”误当“测试通过”。
- 当前本地开发工作区连接不可用，因此本轮工程事实以 GitHub 连接器与 Actions 为准，不在本机执行构建/测试。

## Next action

完成当前代码清点，落盘 M0 审计结论并更新项目状态。
