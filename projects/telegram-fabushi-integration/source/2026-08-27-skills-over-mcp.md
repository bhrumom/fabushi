# 2026-08-27 — Skills over MCP / MiniApp Skill 统一能力

## 用户需求

把 MCP Skills over MCP 的能力与 Skill 工作方式正式融合进 Fabushi，使 MiniApp 不仅暴露 Tools / Resources / UI / CLI，还可以暴露结构化 Agent Skill；Mahayana/Bot 能发现 Skill、按需读取 Skill 内容，再通过既有 MiniApp Tool Contract 执行业务。

## 目标架构

`MiniApp -> MCP Server -> skills/list + skills/get -> skill resources -> Mahayana activation/read -> existing tools/call`

Skill 负责“应该如何完成工作流”，Tool Contract 继续负责“允许执行哪些动作”。Skill 不创建第二套执行权限、Tool 映射或业务 runtime。

## 上游基线（2026-08-27）

- MCP Skills Over MCP WG 的当前方向为 SEP-2640 Skills Extension（Extensions Track），仍处于 In Review。
- 当前 v1 方向使用 `skills/list` + `skills/get`；早期 `skill://index.json` 已被取代。
- Skill 文件继续作为 MCP Resource 读取，主入口通常为 `skill://<path>/SKILL.md`，但 URI scheme 本身不具有可信/特权语义。
- 静态 Skill 以逐文件 SHA-256 digest 做内容绑定与缓存/验证；archive 分发不属于 v1。
- Skill identity 必须包含来源 MCP Server identity + Skill URI；不得仅凭 `name` 去重或覆盖。
- Host 负责 activation/consent、来源展示、digest 验证与安全边界；读取 Skill 不得绕过既有 Tool approval。

## Fabushi 设计约束

1. 扩展现有 `fabushi.miniapp.manifest.v2`，增加可选 `skills` 声明；现有无 Skill MiniApp 必须保持兼容。
2. 每个 MiniApp MCP Server 可发布零个或多个 Skill，且通过 Resource 提供 `SKILL.md` 与 supporting files。
3. 服务端提供与 SEP-2640 v1 语义一致的 `skills/list` / `skills/get` surface；在当前 MCP SDK 尚未稳定暴露扩展 handler 时，允许使用明确标记的兼容 bridge，但 canonical data model 不得绑定 bridge tool 名称。
4. Mahayana 按需加载，不在连接时把全部 Skill 正文灌入上下文。
5. 激活前校验来源、URI、资源 digest；同名不同来源 Skill 不得静默 shadow。
6. Skill 只能指导既有 Tool Contract；写入、open-world、destructive Tool 继续走现有 Host/Native approval。
7. 不自动执行 Skill 内脚本；脚本/附件只按 Resource 数据处理，实际执行仍必须落到已批准 Runtime/Tool。
8. Marketplace/BotFather 允许发布 Skills metadata；未来可逐步把 Skill 质量纳入审核，但本任务不得让没有 Skill 的历史 MiniApp 失效。
9. 先以官方 `global-dharma`/Marketplace contract 建立一条端到端 Skill 样例和 contract test。
10. SEP-2640 尚未定稿，所以实现必须放在 adapter/extension boundary，可随上游 schema 变更而替换，不能污染核心业务模型。

## 验收

- MiniApp manifest 能规范化 Skill metadata/resources，拒绝非法 URI/path、重复 URI、错误 digest。
- MiniApp MCP server 能枚举 Skill、按 URI 获取单项 metadata、通过 MCP Resource 读取真实 `SKILL.md`。
- 静态 Skill 返回逐文件 SHA-256，测试能验证 Resource bytes 与 digest 一致。
- Mahayana/Fabushi Host 有 origin-scoped Skill identity、按需读取/验证 helper，并保留 approval boundary。
- 官方全球法布施至少提供一个真实工作流 Skill 作为回归样例。
- Node contract tests + relevant CI required checks 通过；只有 protected `main` 合并、canonical-main 回读及适用 delivery gate 完成后才可关账。
