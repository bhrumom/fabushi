# GBF-101 — Pin source/main refs

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-101
- Objective: 固化本轮审计使用的 `main`、`grok-bot-latest-source-fusion`、`grok-bot-0.16-source-fusion` 精确 commit/tree refs，作为 M1 后续 manifest、能力矩阵、差异矩阵和 provenance 的不可变输入。
- Source requirement IDs/references: GBR-001, GBR-008; `source/grok-bot融合优化.txt`
- Stage: M1-source-inventory
- Status: RELEASED
- In scope: 读取远端分支 head、tree、commit 时间/签名状态、merge-base/reachability；写入项目 evidence/依赖/行动项。
- Out of scope: 在本任务中直接迁移运行时代码或宣称 GBF-102..105 完成。
- Dependencies: GBF-001 RELEASED; GitHub `main`; two historical Grok source branches.
- Implementation branch: `gbf/gbf-101-m1-inventory-20260822`
- PR: #2003
- Started: 2026-08-22 16:47+08
- Updated: 2026-08-22 16:47+08
- Completed: 2026-08-22 17:01+08

## Acceptance criteria / checks

- [x] `main` 精确 commit SHA 与 tree SHA 已固化。
- [x] `grok-bot-latest-source-fusion` 精确 commit SHA 与 tree SHA 已固化。
- [x] `grok-bot-0.16-source-fusion` 精确 commit SHA 与 tree SHA 已固化。
- [x] 三个 ref 均由 GitHub/live git refs 交叉核验。
- [x] merge-base/reachability 关系已记录，避免把历史分支误当成当前产品基线。
- [x] `management/06-依赖与阻塞.md`、`management/08-问题与行动项.md` 与 evidence 同步。
- [ ] PR/CI/protected-main/post-merge evidence 完整后才提升为 RELEASED。

## Verification method

- `git rev-parse <ref>` / `git show -s --format=... <ref>` / `git rev-parse <ref>^{tree}`
- `git merge-base` + `git merge-base --is-ancestor`
- GitHub branch API reads for the three refs.

## Evidence

`evidence/GBF-101/README.md` and `refs.json` record exact refs/tree hashes/commit metadata/reachability. PR/CI/merge/main verification remains the only open closure gate.

## Blockers / risks

No known blocker. Historical source refs are input-only and must never overwrite current `main` wholesale.

## Next action

Pin the three refs, close QA-001, then begin GBF-102 recursive manifest generation.
