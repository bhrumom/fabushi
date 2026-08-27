# 2026-08-27 — Web Host 与 Telegram 式全平台 UI 收敛

## 用户纠正后的要求

Fabushi Web 不是独立的“应用市场网站”。Web、桌面和移动客户端需要像 Telegram 一样，在不同平台上保持同一产品信息架构、核心 UI 语义和功能集合；平台只在窗口尺寸、原生系统能力和输入方式上做适配。

本轮具体要求：

- Web 根入口直接进入 Fabushi 主 Host / Messenger，而不是进入另一套市场首页。
- 现有桌面 Host 与 Web 复用同一个 React Host surface，避免两套 UI 漂移。
- 已新增的应用市场、应用详情、内容级 SEO、搜索索引、OpenSearch、Sitemap、WebMCP 能力全部保留。
- 应用市场作为 Host 内原生“Mini Apps / 插件市场”能力继续存在，同时保留 `/apps`、`/apps/[slug]` 和内容永久 URL 作为公开分发与搜索入口。
- WebMCP 是 Web/Mini App 前台 Agent 接口，不得要求用户进入独立市场壳后才能使用。
- Marketplace 与 Host 使用同一份 Mini App catalog 和同一安装状态 key，避免重复配置和应用数量漂移。

## Open-source-first 研究

### Telegram Web K

- 上游：`TelegramOrg/Telegram-web-k`
- 许可证：GPL-3.0。
- 本轮只学习产品架构和交互模式，不复制其受 GPL 约束的实现代码。
- 采用的设计原则：一个主客户端 Shell 承载聊天、搜索、导航和扩展能力；Web 是完整客户端而不是营销站；响应式变化不改变产品身份和核心操作语义。
- Fabushi 继续用自己的 React/Next.js Host、Mahayana contracts、Mini App sandbox 和 WebMCP bridge 实现这些原则。

### 既有 Fabushi 基线

- `frontend/apps/host/src/main.tsx` 已直接复用 `frontend/apps/web/src/app/host/host-client.tsx`，证明桌面 Host 与 Web Host 可以共享同一 UI surface。
- 2026-08-27 的 WebMCP 升级要求仍有效：当前 Mini App 的前台工具由 WebMCP 暴露，后台长任务继续由 Rust/Native Runtime 承担。
- 2026-08-25 的 Telegram-style Mini Apps Marketplace 要求仍有效：Marketplace 是主客户端中的发现/安装能力，而不是替代主客户端。

## 实现计划

1. 根路由 `/` 恢复为共享 HostClientEntry。
2. 新市场完整页面迁移为 `/apps` 公开发现入口；应用详情与内容永久 URL 保持不变。
3. Host 内插件市场复用 `lib/marketplace.ts` 作为 catalog，保留安装/打开行为，并增加公开详情入口。
4. 全站 metadata / PWA manifest 改为产品优先，Marketplace/SEO/WebMCP 作为能力描述而不是产品主身份。
5. 追加回归测试，保证 `/` 和 `/host` 都指向同一 Host surface，且 `/apps` 仍保留 marketplace surface。

## 验收

- `/` 与桌面 Host 复用同一个 HostClient 入口。
- `/apps` 保留新市场 UI。
- 8 个 Marketplace Mini Apps 均可在 Host 市场出现；不再由 Host 维护第二份硬编码清单。
- WebMCP 仍由根 layout 全局挂载。
- `/apps/[slug]`、`/apps/[slug]/content/[contentId]`、`/search-index.json`、`/opensearch.xml`、`/sitemap.xml` 保持可用。
- TypeScript/typecheck/build 和相关 route/host tests 通过；PR 必须通过 protected merge queue 合入 canonical main。
