# Grok Bot -> Fabushi 全量融合项目

本目录是 Grok Bot 能力/源码进入 Fabushi 的唯一长期项目基线。目标不是在 Fabushi 中长期保留一个平行的 `Grok Bot` 子产品，而是对已有 Grok Bot 融合源码进行逐项盘点、差异分析、重构和验证，把有价值的产品能力归入 Fabushi/Mahayana 的正式架构。

## 权威位置

- Repository: `bhrumom/fabushi`
- Authoritative branch: `main`
- Project path: `projects/grok-bot-fabushi-integration/`

## 已确认的代码输入

仓库存在 `grok-bot-latest-source-fusion` 与 `grok-bot-0.16-source-fusion` 分支。最新融合分支中可见 Electron 主进程、preload、host process、native capability handlers、native edge、离线 ASR、桌面 E2E 等代码。当前 `main` 对若干相同文件已有进一步演进，所以历史融合分支只作为审计输入，禁止整分支覆盖 `main`。

## 核心原则

1. 一个能力只允许有一个正式归属；不得长期保留 Grok/Fabushi 两套并行执行通道。
2. 任何源码迁移必须先比较 `main` 与来源分支，优先保留 `main` 的后续修复。
3. “文件存在”不等于“功能完成”。完成必须至少有实现、测试、E2E/集成验证、权限边界、错误处理、可观测和 CI 证据。
4. Grok Bot 作为能力研究/迁移来源；最终产品身份、API、数据模型、权限和运行时必须是 Fabushi/Mahayana 自有。
5. 许可证、来源和可复用边界必须逐项记录；无法确认来源权利的代码不得静默当作自有原创代码发布。

## 推荐阅读顺序

`SOURCE_OF_TRUTH.md` -> `REQUIREMENTS.md` -> `ARCHITECTURE.md` -> `docs/02-Grok-Bot能力目录.md` -> `management/01-WBS原子任务.md` -> `management/03-验收追踪矩阵.md` -> `docs/15-完成定义.md`。
