# 2026-08-28 — Remove upstream compiled/runtime dependencies

## User requirement

用户要求把 Fabushi/Mahayana 中仍依赖上游压缩、编译、非源码运行产物的实现全部移除，并由 Fabushi 自己实现等效效果；本轮直接落实到当前 Grok-style BotMark/动态头像链路，并将上游 renderer/runtime 依赖设为禁止回流的构建约束。

## Normalized engineering interpretation

- `bhrumom/fabushi` 的 production runtime 不得依赖 Grok Bot 发布包中的 minified/compiled renderer bundle、checksum-pinned renderer、recovered production payload 或等价 opaque artifact。
- 动态 BotMark 不得依赖 Grok/Cursor/OpenMaus 的 production runtime 或 vendored mascot implementation；允许历史项目文档保留来源研究和行为基准记录。
- 视觉与行为目标继续保持 observable parity，但实现边界必须是 Fabushi-owned source：React + procedural SVG + deterministic identity + Agent-state motion + reduced-motion/visibility power controls。
- CI 必须 fail closed：若 production avatar/runtime 重新引用 OpenMaus/CursorAvatar/Grok renderer bundle 等已退休路径，检查失败。
- 历史来源材料属于 evidence/reference，不是生产运行输入。

## Acceptance

1. 删除 production vendored avatar implementation。
2. `BotMark -> FabushiBotMarkEngine -> FabushiAvatarRuntime` 形成完整 Fabushi-owned source chain。
3. 保留 semantic Agent states、gaze、spin/bounce/burst、visibility pause、prefers-reduced-motion。
4. Frontend typecheck/build 与 Electron architecture guard 通过。
5. PR 合入 protected `main` 后，以 canonical-main package/E2E/Release 证据关闭 GBF-505。
