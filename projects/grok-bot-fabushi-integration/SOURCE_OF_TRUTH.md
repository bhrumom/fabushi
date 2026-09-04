# Source of Truth

## 权威项目基线

唯一长期项目基线：`bhrumom/fabushi` 的 `main:projects/grok-bot-fabushi-integration/`。

## 原始需求

原始上传需求保存于 `source/grok-bot融合优化.txt`。当前产品目标是把有价值的 Grok Bot 行为/能力融入 Fabushi，而不是保留第二套 runtime。

## 工程事实来源

- 当前产品事实：GitHub `main`。
- Grok Bot 历史融合输入：`grok-bot-latest-source-fusion`、`grok-bot-0.16-source-fusion`。
- PR/CI/Release/部署事实：GitHub 实时状态。
- 聊天、外部副本、历史分支不得静默覆盖 `main`。

## 2026-09-04 clean-room boundary

Program `FAB-ARCH-P0-20260904` additionally inspected `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d`. Root `LICENSE` is absent; `PROVENANCE.md` says no upstream source-code license is implied and independent rights review is required. Therefore this repository is behavior/evidence reference only: observable mention/privacy/session/tool-result/UI boundary may inform clean-room specifications, but implementation source must not be copied.

GBF owns behavior and same-account device capability semantics; FAB-P0005/MSR owns execution/session; FAB-P0001/TFI owns message transport/projection.

## 冲突处理

若来源与 `main` 冲突：先做能力级 diff；默认保留 `main` 后续修复。只有明确 ADR、测试、CI 与许可/来源证据时才改变正式架构。
