# Source of Truth

## 权威位置

本项目唯一长期基线：`bhrumom/fabushi` 的 `main:projects/telegram-fabushi-integration/`。原始完整需求保存在 `source/完整telegram融合进fabushi.txt`。

规则：原始需求定义目标；`docs/` 规范化；`management/` 管理执行与真实状态；`decisions/` 保存 ADR；`evidence/` 保存证据索引。代码、PR、CI、Release、部署事实必须以 GitHub 实际状态为准。聊天、本地副本、外部镜像不得覆盖 canonical main。

## 2026-09-04 recovery addendum

Program `FAB-ARCH-P0-20260904` 复用 `FAB-P0001/TFI`，跨项目契约链接 `FAB-P0005/MSR` 与 `FAB-P0004/GBF`。canonical base 为 `688465e94647d4c866f6b1d7b4884145b2f4a9da`；审计输入为 `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`，不是 canonical source of truth，也不因代码存在自动升级状态。

PR #2320 的代码审查已对 architecture head `21ee56892db48925fe863320a1cd68b51c4596cd` 给出 `REVIEW-REJECTED`；审查回写后 head 起点 `a0333f32a5d0edc04723c49fc53a5997a3b0fe1e` 也不是 `REVIEW-PASS`。本轮 repair 只允许进入 fresh real-diff re-review。

### M6 precise current facts at audited implementation head

- `RespondCommunityJoin` 仍存在 `approved && Option<Event>` 形态的 Rust 编译阻断；这是 `TFI-M6-P0-001` 当前 defect。
- `native/mahayana-messaging/src/service.rs` 的 Community-backed `CreateConversation` 仍可直接投影到 generic `UpsertConversation`；create/update ownership boundary 仍需修复。
- 无 Community 的 `RequestCommunityJoin` **已经**显式返回 `CommunityNotFound`；不得再描述为当前仍通过 `CommunityState::new()` 抢占。它是后续 admission 工作必须保持的 regression guard。
- Admission 尚未闭环，必须覆盖 public/private/invite/join-request 的正负矩阵，以及 invite expiry/revoke/replay、ban/already-member/unauthorized approval 等边界。
- journal/replay、v2 reader boundary/v3 negotiation 等保持 rejected until their authoritative task contracts pass fresh review and real verification.

## Cross-project closure rule

TFI M8 session-dependent closure cannot treat unfinished MSR session work as satisfied；`MSR-201` 当前 `in-progress`，因此 `MSR-210` 必须在 `MSR-201 REVIEW-PASS/accepted contract` 后才能通过。TFI M7 group-Bot closure additionally hard-gates `MSR-211 REVIEW-PASS` and `GBF-508 REVIEW-PASS`; `MSR-211` itself is hard-gated by current in-progress `MSR-202`, `GBF-409`, and `GBF-411` as recorded in their projects.

No task is complete from `REVIEW-PASS` alone: its own merge/CI/exact-canonical-main packaged/installable E2E/release evidence must also satisfy the task-local contract.
