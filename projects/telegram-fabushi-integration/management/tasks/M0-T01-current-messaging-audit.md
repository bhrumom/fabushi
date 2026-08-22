# M0.T01 — 审查现有 Fabushi 通信相关代码

- **Project**: `FABUSHI-TELEGRAM-FUSION`
- **Task ID**: `M0.T01`
- **Stage**: `M0 现状清点与边界固定`
- **Status**: `TESTED`
- **Started**: `2026-08-22`
- **Completed**: `2026-08-22`
- **Updated**: `2026-08-22`
- **Source**: `../../source/完整telegram融合进fabushi.txt`; `../wbs/M0.md`

## Objective

以 GitHub `main` 的真实代码、已合并 PR 与 CI 事实为依据，审查当前 Fabushi 通信实现，纠正项目基线中“全部 NOT_STARTED”的占位状态，并确定唯一通信核心、客户端桥、旧栈边界以及下一阶段最早未满足的验收门槛。

## Acceptance result

1. 当前通信实现已有可追踪清单，并标明唯一核心路径和旧/兼容路径：PASS。
2. 已合并实现有 commit/PR/文件证据：PASS。
3. 历史 CI 失败与当前源码状态分开记录：PASS。
4. 已明确下一最早未满足任务 M1.T06 SQLite storage：PASS。
5. WBS、状态报告、验收矩阵和迁移 ADR 已进入项目目录：PASS。

## Canonical result

- Canonical Messaging Core: `native/mahayana-messaging/`.
- Canonical protocol: `native/mahayana-messaging/src/protocol.rs`, protocol version 2.
- Desktop client: Electron Messenger V2 / self-hosted messaging client.
- Product composition: Mahayana Feature Host.
- Legacy/frozen: `native/telegram-*`, `mahayana-telegram`, `providers/telegram-*`.
- No Telegram API/MTProto network is permitted as a hidden Fabushi messaging fallback.

## Verification completed

- PR #1961 merged implementation: `8062abb850020a702b4c8a85d8bd23d6b0470cb2`.
- M0 reconciliation PR #1987 passed repository CI and merged through the protected merge queue.
- PR #1987 merge commit on `main`: `5aeca75a1e9f6c5bd9fc376cf697012004c0766c`.
- Canonical `main` now contains `docs/20-现状审计与迁移边界.md`, ADR-0008, M0 WBS reconciliation and the live acceptance matrix.
- Historical `reply_to_message_id` compile failure is documented as historical; current source contains the fix.

## Evidence

- Audit: `../../docs/20-现状审计与迁移边界.md`
- Decision: `../../decisions/ADR-0008-canonical-messaging-core-and-legacy-freeze.md`
- Matrix: `../03-验收追踪矩阵.md`
- WBS: `../wbs/M0.md`
- PR: #1987
- Main merge: `5aeca75a1e9f6c5bd9fc376cf697012004c0766c`

## Remaining risks transferred

- Old Telegram crates remain physically present; removal is owned by M14 after dependency-zero proof.
- Broad implemented domains still need current project-scoped acceptance evidence before they can be promoted beyond `IMPLEMENTED`.

## Next action

M0 is closed. Continue M1 with M1.T06 SQLite storage (#1988), M1.T02 production SQLite adoption (#1990), then reconcile the remaining existing M1 implementation against current-head CI.
