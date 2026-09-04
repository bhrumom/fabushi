# Grok Bot -> Fabushi 全量融合项目

本目录是 Grok-like 行为/能力进入 Fabushi 的长期项目基线。目标不是保留平行 Grok Runtime，而是把有价值的可观察产品行为、设备能力和 Agent Surface 契约归入 Fabushi/Mahayana 正式架构。

## Canonical state
- `bhrumom/fabushi` protected `main` is implementation truth.
- GBF owns observable Bot behavior and same-account device/App capability semantics; `FAB-P0005/MSR` owns execution/session/policy; `FAB-P0001/TFI` owns message transport/projection.
- Existing GBF-409 and GBF-411 remain current dependencies; neither is accepted merely because implementation exists.

## 2026-09-04 P0 repair status
PR #2320 architecture head `21ee56892db48925fe863320a1cd68b51c4596cd` was `REVIEW-REJECTED`; review write-back reached `a0333f32a5d0edc04723c49fc53a5997a3b0fe1e`. This repair is ready only for fresh latest-head review. `GBF-409` and `GBF-411` are both still `IN_PROGRESS`, and MSR-201/202 are still `in-progress`; therefore GBF-508 capability integration remains hard-blocked.

`bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d` has no root LICENSE and its provenance does not grant upstream source rights. It is clean-room **observable behavior/UI/IPC evidence only**. No implementation code may be copied; unverified/unclear-rights files are not adopted.

Authoritative P0 task: `management/tasks/GBF-508-group-bot-behavior-capability-routing.md`. The task file itself contains the complete execution/acceptance contract; shared docs cannot fill omissions.

## Source of truth
See `SOURCE_OF_TRUTH.md`.
