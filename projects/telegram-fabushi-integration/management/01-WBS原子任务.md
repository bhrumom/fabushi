# WBS 原子任务

- **项目**：Fabushi Telegram 全量融合
- **文档 ID**：MGMT-01
- **版本**：v1.0
- **状态**：BASELINE
- **基线日期**：2026-08-22
- **源计划**：`../source/完整telegram融合进fabushi.txt`

> 本文档由源计划结构化拆分而来。源计划未明确的管理字段会标记为“项目管理补充/待确认”，避免把推导内容冒充既有事实。

## 使用规则

每一项任务都必须具备稳定 ID、交付物、验收标准、客观验证、状态、证据位置和下一步。这里先根据源计划建立基线任务；代码审查后可以继续细分，但禁止用模糊“大任务”替换可验证原子任务。

## 分卷索引

为便于 GitHub 长期维护，原子任务按阶段拆分；各分卷共同构成完整 WBS。

- [M0 现状清点与边界固定](wbs/M0.md)
- [M1 Rust Core 骨架](wbs/M1.md)
- [M2 自建实时网络 + 1:1 文本消息](wbs/M2.md)
- [M3 桌面聊天完整交互](wbs/M3.md)
- [M4 媒体与文件](wbs/M4.md)
- [M5 联系人 + 群组](wbs/M5.md)
- [M6 频道 + Topic + 管理能力](wbs/M6.md)
- [M7 Bot/Agent 统一联系人体系](wbs/M7.md)
- [M8 Mini Apps](wbs/M8.md)
- [M9 支付](wbs/M9.md)
- [M10 语音/视频通话](wbs/M10.md)
- [M11 移动端共享 Rust Core](wbs/M11.md)
- [M12 高级 IM 能力](wbs/M12.md)
- [M13 安全强化 + E2EE](wbs/M13.md)
- [M14 全量替换旧通信栈](wbs/M14.md)
- [项目治理任务](wbs/governance.md)

状态变更必须同时更新对应分卷、验收追踪矩阵、状态报告与任务记录。

## 2026-08-24 — M3-DESKTOP-002 Telegram local-first + Settings

- `M3-DESKTOP-002` — `TESTING`: returning-user fast-start projection, first sync 20 / cursor background 100, responsive zero-width absent info panel, Telegram-inspired Settings IA, supported desktop preference bindings, and Playwright regression coverage implemented in PR #2079. GitHub Actions + protected merge + canonical-main verification remain the completion gate.

## 2026-08-24 — M3-DESKTOP-002 closed

- `M3-DESKTOP-002` — `COMPLETED`: PR #2079 passed CI, Messaging Product Gate, self-hosted messaging, and Electron desktop quality gate, then merged through the protected merge queue as `01b33d60f7d7d9add41a5fba84d21014094cb5dc`. Canonical `main` was re-read at the merge SHA.

## 2026-08-24 — M3-DESKTOP-002 performance continuation

- `M3-DESKTOP-002` — `TESTING`: canonical-main full-relaunch E2E exposed a renderer-projection durability gap. Follow-up adds an existing native client-persistence mirror/fallback and durable-preclose assertion; `< 1000 ms` packaged timing + exact-main Release remain blocking.

## 2026-08-24 — M3-DESKTOP-002 returning-session continuation

- `M3-DESKTOP-002` — `TESTING`: durable projection restore is proven on canonical main; deterministic Rust test account persistence is the remaining full-restart blocker. Follow-up persists only UI-safe test identity in configured Host runtime data, deletes it on logout, and adds a post-auth-poll Messenger-stability E2E assertion. `< 1000 ms` exact-main packaged timing and Release remain blocking.
