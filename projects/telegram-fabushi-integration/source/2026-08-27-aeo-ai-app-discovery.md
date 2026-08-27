# 2026-08-27 — Fabushi AEO / AI 应用发现能力

- Project: `FAB-P0001 / TFI`
- Task: `M8-AEO-001`
- Source: 用户要求在已上线的 Host + Marketplace + WebMCP 架构上继续开发，不推翻现有设计。

## 目标

让 AI 能稳定发现、理解、引用并在支持时调用 Fabushi Mini Apps：

1. 每个 Mini App 使用稳定的 `https://fabushi.ombhrum.com/apps/{slug}#app` entity ID，并输出完整 `SoftwareApplication` / `WebApplication` JSON-LD。
2. 从现有 `frontend/apps/web/src/lib/marketplace.ts` catalog 派生 `/ai/apps.json`、`/ai/apps/{slug}.json`、`/ai/content.json` 与 `/ai/answers.json`，禁止复制第二份应用 catalog。
3. 提供 `/llms.txt` 与 `/llms-full.txt` 辅助入口；它们补充 sitemap、robots、结构化数据和真实内容页，不替代这些标准入口。
4. 提供 `/answers/{slug}` 自然语言意图页并纳入 sitemap。
5. 全站 WebMCP 新增 `recommend_fabushi_app` 与 `get_app_capabilities`，只读发现工具必须返回稳定 entity/deep links。
6. robots 明确允许 OAI-SearchBot、ChatGPT-User、Googlebot 与 Bingbot；Cloudflare 部署后必须做真实 HTTP header/body 验收。
7. 更新 TFI 记录并通过 current-head CI、protected merge、canonical-main readback、生产部署/runtime 验收。

## Open-source-first survey

- `AnswerDotAI/llms-txt` (Apache-2.0): 采用根级精简入口、分区链接、详细信息按需读取的约定；不复制实现代码。
- `schemaorg/schemaorg` (Apache-2.0): 采用 SoftwareApplication/WebApplication entity、稳定 `@id` 和关联内容语义。
- `modelcontextprotocol/typescript-sdk` (Apache-2.0/MIT transition): 沿用 MCP 工具发现与调用分离的契约思想；Fabushi 继续复用现有 WebMCP adapter 和 Marketplace catalog，不引入第二套 runtime 或依赖。

## 非目标

- 不重做 Host UI、Marketplace 或现有 Mini App 页面。
- 不把 llms.txt 当作保证模型收录/排名的私有协议。
- 不绕过 WebMCP 的用户确认和现有安装/执行权限边界。
- 不在本机构建或运行重型测试；按仓库规则使用 GitHub Actions。
