# Grok Bot -> Fabushi 全量融合项目

本目录是 Grok Bot 能力/源码进入 Fabushi 的唯一长期项目基线。目标不是在 Fabushi 中长期保留一个平行的 `Grok Bot` 子产品，而是对已有 Grok Bot 融合源码进行逐项盘点、差异分析、重构和验证，把有价值的产品能力归入 Fabushi/Mahayana 的正式架构。

## 当前已验证状态

- **M0 企业级项目基线已完成**：PR #1982 经 required `CI result` 成功并通过 merge queue 合入 `main`，merge commit `6d1e9cd7a475e8058d5d8512f5c3a0c21da8ed9c`；随后已从 `main` 重新读取项目元数据和原始需求验证 canonical state。
- 当前阶段：**M4 — interactive runner MCP and agent surface**。
- 历史 Grok 分支是只读审计输入，禁止整分支覆盖 `main`。
- **M1–M8 的全部迁移仍不能因代码存在而宣称完成。**

## 2026-09-04 P0 cross-project contract

Program `FAB-ARCH-P0-20260904` 复用 GBF，不新建项目。GBF 负责 Grok-like 可观察 Bot 行为、同账号设备能力和 Agent Surface 语义；真正执行仍由 `FAB-P0005/MSR` 唯一 Runtime/session 完成，TFI 只负责消息投影/传输。

现有 `GBF-409`（同账号设备发现/授权 Computer Use）与 `GBF-411`（Web/App MCP Agent Surface）继续作为能力依赖；新增 `GBF-508` 只定义/实现缺失的 Bot group behavior 和设备/MiniApp capability routing 接缝。

`bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d` 本轮根 `LICENSE` 不存在，且其 `PROVENANCE.md` 明示不蕴含上游源码许可，所以只能 clean-room 参考可观察行为/边界，不复制实现代码。

## 权威位置

- Repository: `bhrumom/fabushi`
- Branch: `main`
- Project path: `projects/grok-bot-fabushi-integration/`
- Source precedence: `SOURCE_OF_TRUTH.md`

## Owner / Review

- Accountable/execution owner: Fabushi/Mahayana maintainers
- Required review: Fabushi maintainers；computer-control、敏感输入、本机执行等高风险能力还需安全审查

## 项目级验收

最终完成必须满足来源分类、单一正式 runtime、自动化/E2E、安全、受保护 main 和发布证据；本次架构记录不改变既有实现状态。

## 目录导航

- 原始需求/来源：`source/`
- 规范：`docs/`
- 执行管理：`management/`
- ADR：`decisions/`
- 证据：`evidence/`
