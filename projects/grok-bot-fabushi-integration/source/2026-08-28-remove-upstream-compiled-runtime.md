# 2026-08-28 — Remove upstream compiled/runtime dependencies

## User requirement

用户要求把 Fabushi/Mahayana 中仍依赖上游压缩、编译、非源码运行产物的实现全部移除，并由 Fabushi 自己实现等效效果；本轮直接落实到当前 Grok-style BotMark/动态头像链路，并将上游 renderer/runtime 依赖设为禁止回流的构建约束。

## Normalized engineering interpretation

- `bhrumom/fabushi` 的 production runtime 不得依赖 Grok Bot 发布包中的 minified/compiled renderer bundle、checksum-pinned renderer、recovered production payload 或等价 opaque artifact。
- 动态 BotMark 不得依赖 Grok/Cursor/OpenMaus 的 production runtime 或 vendored mascot implementation；允许历史项目文档保留来源研究和行为基准记录。
- 视觉与行为目标继续保持 observable parity，但实现边界必须是 Fabushi-owned source：React + procedural SVG + deterministic identity + Agent-state motion + reduced-motion/visibility power controls。
- CI 必须 fail closed：若 production avatar/runtime 重新引用 OpenMaus/CursorAvatar/Grok renderer bundle 等已退休路径，检查失败。
- 历史来源材料属于 evidence/reference，不是生产运行输入。

## Open-source-first gate

本任务在改写前先审查当前 production 已引入的成熟参考实现 `milind-soni/OpenMausBot@667af71ae7e93640ba4b1a5f3b38a1ad342025da`（Apache-2.0）及现有 Grok observable-parity 研究材料。可复用的设计原则包括：state-driven mascot、SVG 矢量渲染、RAF 动画、pause/reduced-motion 和 gaze；但本轮明确**不继续复用其 production source/runtime**，原因是用户要求移除外来实现并建立 Fabushi 自有运行边界，同时 Fabushi 只需要轻量头像状态渲染，不需要引入第二套 mascot engine。

此前讨论的 WebGPU/vgpu 方案也不作为基础头像依赖：对于联系人列表和常驻 BotMark，SVG/RAF 在兼容性、功耗、可维护性和 fallback 上更合适；未来若需要粒子/流体/高级大头像效果，可在 Fabushi-owned Avatar Runtime 上增加可选 GPU effect layer，而不是替换基础身份层。

决策：学习成熟实现的行为和工程约束，重新设计 Fabushi-owned source；不复制 upstream silhouette/path/component，不保留 upstream runtime dependency。

## Acceptance

1. 删除 production vendored avatar implementation。
2. `BotMark -> FabushiBotMarkEngine -> FabushiAvatarRuntime` 形成完整 Fabushi-owned source chain。
3. 保留 semantic Agent states、gaze、spin/bounce/burst、visibility pause、prefers-reduced-motion。
4. Frontend typecheck/build 与 Electron architecture guard 通过。
5. PR 合入 protected `main` 后，以 canonical-main package/E2E/Release 证据关闭 GBF-505。
