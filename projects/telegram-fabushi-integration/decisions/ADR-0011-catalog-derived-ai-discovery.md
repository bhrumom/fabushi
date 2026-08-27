# ADR-0011 — Catalog-derived AI discovery and stable Mini App entities

- **Project**: FAB-P0001 / TFI
- **Status**: ACCEPTED
- **Date**: 2026-08-27
- **Task**: M8-AEO-001
- **Supersedes**: none
- **Related**: ADR-0010 (WebMCP foreground / Rust background)

## Context

Fabushi 已有共享 Host、公开 Marketplace、内容级 SEO、搜索索引和全站 WebMCP，但 AI 仍需要跨页面推断应用身份、能力、权限和可调用入口。若为 AEO 再维护第二份应用清单，Host、Marketplace、SEO 和 Agent discovery 会快速漂移。

## Decision

1. `frontend/apps/web/src/lib/marketplace.ts` 继续作为公开 Mini App catalog 的单一事实源。
2. 每个应用的稳定实体 ID 固定为 `https://fabushi.ombhrum.com/apps/{slug}/#app`；页面 JSON-LD、内容 `isPartOf`、JSON feeds、答案页和 WebMCP 均引用它。
3. `src/lib/ai-discovery.ts` 只负责把 catalog 投影成机器实体、自然语言答案映射和推荐结果，不复制应用详情。
4. 正式机器入口为 versioned JSON feeds：aggregate apps、per-app、content、answers。稳定公开页面仍是可引用的人类入口。
5. `llms.txt` 保持精简导航，`llms-full.txt` 提供完整 catalog-derived 文本；二者是辅助发现入口，不替代 robots、sitemap、结构化数据、内容质量或真实索引。
6. WebMCP 新增只读 `recommend_fabushi_app` 与 `get_app_capabilities`；安装、写入和本地工具执行继续使用现有确认与 Host 权限边界。
7. robots 明确允许 OAI-SearchBot、ChatGPT-User、Googlebot 和 Bingbot。Cloudflare/WAF 是否放行必须由部署后的 User-Agent HTTP probes 验证，不能仅由 robots 声明推断。

## Consequences

- 新应用加入 canonical catalog 后会自动进入 aggregate feed、per-app feed、llms、sitemap 和能力工具。
- 意图/答案文本仍是小型独立 registry，只保存问题、直接答案和 app slug 引用，不复制 catalog 字段。
- AI 推荐是可解释的目录匹配，不冒充模型排序或个性化保证。
- 所有机器端点必须保持公开、无凭据、无用户数据和确定性静态输出。

## Open-source provenance

- AnswerDotAI/llms-txt (Apache-2.0): adapted concise index/full-detail split and linked Markdown convention.
- schemaorg/schemaorg (Apache-2.0): adapted SoftwareApplication/WebApplication entity relationships.
- modelcontextprotocol/typescript-sdk (Apache-2.0/MIT transition): adapted discovery/call separation at the contract level.
- No upstream source code copied; no dependency introduced.
