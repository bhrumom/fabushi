# Contributing — Telegram → Fabushi 融合项目

所有实现必须从 `management/01-WBS原子任务.md` 中领取稳定 Task ID，或先新增经过评审的原子任务。

## 开发流程

1. 确认 Task ID、依赖、验收条件和客观验证方式。
2. 如果改动长期架构、协议、权限模型或公共 SDK，先新增/更新 ADR。
3. 只在既定模块边界内实现；禁止新增第二套聊天、联系人、Bot/Agent 或同步状态机。
4. 补齐单元/集成/E2E/性能/安全测试中适用的部分。
5. 使用 `templates/PR_ACCEPTANCE_TEMPLATE.md` 提交验收信息。
6. CI、E2E 和必要门禁通过后才能提升任务状态。
7. 合并后更新证据位置、状态报告和变更日志。

## 完成状态

仅允许：`NOT_STARTED` → `IN_PROGRESS` → `IMPLEMENTED` → `TESTED` → `E2E_VERIFIED` → `RELEASED`。

不得把“代码已写”“分支已推送”直接视为 DONE。

## 外部实现与许可证

任何 Telegram、Unigram、Grok Bot 或其他外部项目相关代码/设计来源必须按 `docs/18-许可证与来源合规.md` 记录来源与许可证。License 不明或不兼容的代码不得直接合并。
