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

`in-progress`: 已完成一次本地只读体积审计和隔离式重写预案；截至本项目记录建立时，GitHub 远端 refs 尚未被改写。当前工作树中的其他任务改动不属于本项目，必须保持不变。

## Scope and next gate

本项目覆盖：远端全量 refs 盘点、可审计的历史重写、产品路径保留审计、受保护 refs 的临时迁移窗口、推送后完整性验证、规则恢复与证据归档。

下一道闸门：本项目引导 PR 先通过项目治理检查并合入 `main`；然后基于最新 canonical `main` 重新生成重写镜像。真正修改 GitHub 分支/标签保护规则前必须在动作发生前再次确认。

## Acceptance summary

必须满足：生成/缓存/临时树不再出现在重写历史；产品文件清单无意外删除；所有原有 head/tag 名称均有新 OID；`git fsck` 和连通性校验通过；GitHub 保护规则恢复；未在本机执行构建或测试。

## Navigation

- Requirements: `source/2026-09-07-repository-history-slimming.md`
- Task record: `management/tasks/RHS-001-repository-history-slimming.md`
- Decision: `decisions/ADR-0001-history-rewrite-toolchain.md`
- Runbook: `runbooks/history-rewrite.md`
- Evidence index: `evidence/README.md`
