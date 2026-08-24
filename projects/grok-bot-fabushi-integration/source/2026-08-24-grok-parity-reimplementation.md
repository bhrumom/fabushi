# 2026-08-24 — Grok Bot parity reimplementation requirement

## User requirement

用户要求开始把 Grok Bot 的整体体验完整复刻进 Fabushi：在功能、交互、动画、UI 视觉和运行行为上达到一比一的可观察效果，同时保持 Fabushi 为自己的产品，最终实现不能呈现为一个平行的 Grok Bot 子产品。

## Normalized engineering interpretation

- Grok Bot 0.20 / 历史可观察实现作为行为、布局、动效与交互验收基准。
- Fabushi/Mahayana 保持自己的 Electron + Rust Host + Mahayana sovereign runtime；不为了相似度退回第二套 Node/Grok runtime。
- 对来源许可不明确或生产 bundle 反推得到的实现采用 clean-room behavior/spec reimplementation，不原样复制专有源码或品牌资产。
- 目标是 observable parity：布局层级、密度、深色材质、composer、搜索/菜单、BotMark 状态表现、Host/Computer-Control 行为与恢复语义达到等效或更优。
- Telegram/Fabushi 已有消息、支付、Mini App、通话、搜索等能力必须保留，不因 Grok 风格重构而退化。

## Acceptance direction

1. Desktop shell 不再呈现 Telegram 白底/亮蓝作为主视觉，而统一为 Grok/Fabushi 深色、低对比层级、浮层材质。
2. Bot/User/Group/Channel/Mini App 共用 Fabushi BotMark/Identity 体系，AI 状态直接驱动动态表现。
3. Rust Host / Mahayana 仍是唯一正式 Agent/Tool/Computer runtime，吸收 Grok coordinator/supervisor 的恢复、取消、事件流语义。
4. 所有变化需通过现有 Electron/Messaging/Host/portfolio gates，并按 canonical main 的 packaged E2E + Release 规则完成交付。
