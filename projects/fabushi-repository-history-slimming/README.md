# Fabushi Repository History Slimming

- Project ID: `FAB-P0010`
- Project Key: `RHS`
- Status: `in-progress`
- Repository: `bhrumom/fabushi`
- Canonical path: `projects/fabushi-repository-history-slimming/`
- Source of truth: [SOURCE_OF_TRUTH.md](SOURCE_OF_TRUTH.md)

## Objective

彻底清理 Fabushi Git 历史中的构建产物、缓存、临时文件和已确认的重复生成树，降低 clone、fetch、fsck 和 CI 的成本，同时保留产品源码、必要模型/字体/音频/上架材料与全部可追溯的分支/标签名称。

## Current verified status

`in-progress`: 已完成隔离式历史重写、canonical `main`/heads 迁移和规则恢复。远端 `main` 当前为 `bc4fb3032a03d6600d733ce28295256d77cca9d4`；heads 从 2116 个降为 1572 个，删除 544 个超过 90 天且没有开放 PR 关联的旧 heads。401 个 tags 保持原状，因为它们均绑定 GitHub immutable releases，GitHub 明确禁止移动或删除这些 tag。GitHub Actions 的 Electron 与 Native mobile 质量门仍在针对该 SHA 运行。

## Scope and next gate

本项目覆盖：远端全量 refs 盘点、可审计的历史重写、产品路径保留审计、受保护 refs 的临时迁移窗口、推送后完整性验证、规则恢复与证据归档。

下一道闸门：完成两个 post-main 质量门并把结果写回任务证据；若失败，按项目规则通过后续 PR 修复。原始 refs、远端 bare 镜像和上架/软著材料归档已保留，可回滚。当前工作树中的其他任务改动不属于本项目，必须保持不变。

## Acceptance summary

已验证：生成/缓存/临时树在候选重写历史中无残留；候选 `git fsck --full` 通过；远端新 `main` 与 heads 读回通过；分支保护规则已恢复且 bypass list 为空；未在本机执行构建或测试。受 immutable releases 和 GitHub server-managed `refs/pull/*` 限制，不能在同一仓库重写/删除已发布 tags，也不能声称 GitHub 全部历史对象已回收；这些边界已记录为验收例外。

## Navigation

- Requirements: `source/2026-09-07-repository-history-slimming.md`
- Task record: `management/tasks/RHS-001-repository-history-slimming.md`
- Decision: `decisions/ADR-0001-history-rewrite-toolchain.md`
- Runbook: `runbooks/history-rewrite.md`
- Evidence index: `evidence/README.md`
