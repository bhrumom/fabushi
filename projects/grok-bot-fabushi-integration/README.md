# Grok Bot -> Fabushi 全量融合项目

本目录是 Grok Bot 能力/源码进入 Fabushi 的唯一长期项目基线。目标不是在 Fabushi 中长期保留一个平行的 `Grok Bot` 子产品，而是对已有 Grok Bot 融合源码进行逐项盘点、差异分析、重构和验证，把有价值的产品能力归入 Fabushi/Mahayana 的正式架构。

## 当前已验证状态

- 当前阶段：**M0 — 项目基线与治理**。
- 已确认历史输入分支：`grok-bot-latest-source-fusion`、`grok-bot-0.16-source-fusion`。
- 已确认 latest 分支包含 Electron main/preload/host/native-capability/native-edge/offline-ASR/desktop-E2E 等输入。
- 已确认当前 `main` 对部分同名 Electron 文件已有后续演进，因此历史 Grok 分支是只读审计输入，禁止整分支覆盖 `main`。
- 当前下一验收门：GBF-001 项目基线 PR -> required CI -> protected main -> post-merge main verification。
- **M1–M8 的运行时代码迁移尚未被宣称完成。**

## 权威位置

- Repository: `bhrumom/fabushi`
- Branch after merge: `main`
- Project path: `projects/grok-bot-fabushi-integration/`
- Source precedence: `SOURCE_OF_TRUTH.md`

## Owner / Review

- Accountable/execution owner: Fabushi/Mahayana maintainers
- Required review: Fabushi maintainers；computer-control、敏感输入、本机执行等高风险能力还需安全审查
- 详细职责：`OWNERS.md`

## 项目级验收

最终“Grok Bot 所有功能、所有源码已融合”必须满足 `docs/19-完成定义与验收.md`：来源 100% 分类、单一正式 runtime、保留能力有自动化/E2E 证据、安全/来源阻塞清零、受保护 main 与发布证据完整。

## 目录导航

- 原始需求/来源：`source/`
- 标准产品与工程规范：`docs/00..07`、`docs/19`
- 深入专题规范：`docs/02-Grok-Bot能力目录.md` 到 `docs/15-完成定义.md`
- 执行管理：`management/`
- ADR：`decisions/`
- 验收证据：`evidence/`
- 运维/回滚/恢复：`runbooks/`
- 可复用模板：`templates/`
