# Fabushi Repository History Slimming

- Project ID: `FAB-P0010`
- Project Key: `RHS`
- Status: `passed with immutable-release exception`
- Repository: `bhrumom/fabushi`
- Canonical path: `projects/fabushi-repository-history-slimming/`
- Source of truth: [SOURCE_OF_TRUTH.md](SOURCE_OF_TRUTH.md)

## Objective

彻底清理 Fabushi Git 历史中的构建产物、缓存、临时文件和已确认的重复生成树，降低 clone、fetch、fsck 和 CI 的成本，同时保留产品源码、必要模型/字体/音频/上架材料与全部可追溯的分支/标签名称。

## Current verified status

`passed with immutable-release exception`: 已完成隔离式历史重写、canonical `main`/heads 迁移、规则恢复和 post-main 质量验证。接受的瘦身产品树为 `bc4fb3032a03d6600d733ce28295256d77cca9d4`；随后文档 PR #2483 与其他已合入主线的产品提交继续前进，当前 canonical `main` 为 `7ea5055b1e0d7ee078d0d21321b5884fa93bead2`，且包含该瘦身提交。迁移时 heads 从 2116 个降为 1572 个，清理 544 个过期 head；2026-09-09 当前远端读回为 1598 heads / 419 tags。迁移时的 401 个 release tags 保持原 OID，因为它们绑定 GitHub immutable releases，不能移动或删除。当前主线树为 10,906 files / 455,513,102 bytes；瘦身候选树为 10,894 files / 455,418,012 bytes。

## Scope and next gate

本项目覆盖：远端全量 refs 盘点、可审计的历史重写、产品路径保留审计、受保护 refs 的临时迁移窗口、推送后完整性验证、规则恢复与证据归档。

下一道闸门：无。本轮 post-main 质量门已完成；后续只需将新的历史治理需求作为独立任务登记。原始 refs、远端 bare 镜像和上架/软著材料归档已保留，可回滚。当前工作树中的其他任务改动不属于本项目，保持不变。

## Acceptance summary

已验证：生成/缓存/临时树在候选重写历史中无残留；候选 `git fsck --full` 通过；远端新 `main` 与 heads 读回通过；分支保护规则已恢复且 bypass list 为空；Electron desktop quality gate（重跑）和 Native mobile quality gate 均成功；未在本机执行构建或测试。受 immutable releases 和 GitHub server-managed `refs/pull/*` 限制，不能在同一仓库重写/删除已发布 tags，也不能声称 GitHub 全部历史对象已回收；这些边界已记录为验收例外。

## Navigation

- Requirements: `source/2026-09-07-repository-history-slimming.md`
- Task record: `management/tasks/RHS-001-repository-history-slimming.md`
- Decision: `decisions/ADR-0001-history-rewrite-toolchain.md`
- Runbook: `runbooks/history-rewrite.md`
- Evidence index: `evidence/README.md`
