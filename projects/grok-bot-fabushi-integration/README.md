# Grok Bot → Fabushi 全功能融合项目

## 权威位置

- Repository: `bhrumom/fabushi`
- Branch: `main`
- Path: `projects/grok-bot-fabushi-integration/`

## 项目目标

将 Grok Bot 产品能力完整分析、重构并融合进入 Fabushi，不作为外部依赖，而成为 Fabushi 自有架构的一部分。

目标能力包括：

- Electron 桌面架构能力
- renderer / main / preload 分层能力
- coordinator 调度能力
- host 与 local-exec 本机执行能力
- AI Agent 协作能力
- 电脑控制能力
- 动态头像与交互动画引擎能力
- 工具调用与任务执行链路
- 与 Mahayana Kernel 统一

## 执行原则

1. 不直接复制不可维护的外部实现，按照 Fabushi 架构重构。
2. 每个功能必须有模块归属、测试和验收证据。
3. GitHub 项目目录为长期状态来源。
4. 未完成实现、测试、E2E 验证不能标记完成。

## 来源

用户提供的 Grok Bot 融合需求作为 source 基线。该项目与 Telegram 融合项目并行，并最终统一进入 Fabushi 产品架构。
