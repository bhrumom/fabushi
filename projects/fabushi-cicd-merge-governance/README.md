# Fabushi CI/CD & Merge Governance

- **Project ID:** `FAB-P0003`
- **Project Key:** `FCM`
- **Status:** `active`
- **Repository:** `bhrumom/fabushi`
- **Canonical path:** `projects/fabushi-cicd-merge-governance/`
- **Current stage:** `G4 — Incremental build & test efficiency`

## Objective

把 Fabushi 的 CI/CD、合并、构建、测试与发布链路建设为高吞吐、低等待、可审计且 fail-safe 的工程体系：PR 只跑快速必要检查；受保护 `main` 承担受影响平台的安装包、Debug 包与 E2E；重复构建通过跨 GitHub Actions run 的分层增量缓存最大化复用上一轮结果。

## Previously verified state

G0-G3 及 FCM-001..008 已有客观证据并保持历史完成状态，包括 change-aware CI、merge queue、延迟观测、release-source gate、CODEOWNERS、商店发布安全和 Developer ID/notarization 修复。

## Active G4 outcome

FCM-009 当前目标：

- PR/merge-group 仅快速静态、类型、格式、契约和必要单元检查，不运行 E2E、installer 或 Debug package 重型任务；
- 只有 protected `main` push 才运行受影响平台的安装包、Debug 包和自动化端到端测试；
- Electron macOS/Windows/Linux、Android、iOS 使用 Node/Cargo/Gradle/Xcode/native output 分层跨 run 缓存；
- small-change 后续构建优先复用上一轮依赖、编译中间产物和原生二进制，只重建失效子图；
- cache miss 必须正确回退 clean build；缓存不能替代 release provenance；
- 对 cache hit/miss、cold/warm duration 和节省率进行真实 Actions 观测，warm build 目标较 cold build 减少至少 50% 墙钟时间。

## Architectural constraint

GitHub-hosted runner 是 ephemeral 的，因此“像热更新一样”不是永久保留 runner 工作区，而是使用内容寻址、版本化、平台/架构/工具链/锁文件/源码感知的跨运行缓存和同一 run artifact handoff 来实现近似 warm incremental build。自托管 runner 不在当前范围。

## Source of truth

- `SOURCE_OF_TRUTH.md`
- `source/2026-08-23-build-test-efficiency.md`
- `management/tasks/FCM-009-incremental-build-test-efficiency.md`
- `decisions/ADR-0003-incremental-cache-and-post-main-heavy-gates.md`

## Current next gate

完成 FCM-009 的 workflow 实现与真实 GitHub Actions cold/warm 对照验证，经 protected PR/merge queue 合入 `main`，再重新读取 canonical main 并关闭 G4。

## Navigation

- `SOURCE_OF_TRUTH.md`
- `OWNERS.md`
- `source/`
- `docs/`
- `management/`
- `decisions/`
- `evidence/`
- `runbooks/`
