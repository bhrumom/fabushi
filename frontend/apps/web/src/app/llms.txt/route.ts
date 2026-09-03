import { fabushiAnswerIntents } from "../../lib/ai-discovery";
import { marketplaceApps } from "../../lib/marketplace";
import { siteUrl } from "../../lib/site-url";

export const dynamic = "force-static";

export function GET() {
  const appLinks = marketplaceApps
    .map((app) => `- [${app.name}](${siteUrl(`/ai/apps/${app.slug}.json`)}): ${app.subtitle}`)
    .join("\n");
  const answerLinks = fabushiAnswerIntents
    .map((answer) => `- [${answer.question}](${siteUrl(`/answers/${answer.slug}`)}): ${answer.answer}`)
    .join("\n");

  const body = `# Fabushi

> Fabushi 是跨平台 Messenger、AI Agent Host 与 Mini Apps 平台。Web、桌面和移动端共享产品身份；Marketplace 是 Mini Apps 的发现与安装层，WebMCP 是网页与 Mini App 的 Agent 工具接口。

Fabushi 的公开 AI 发现数据全部从同一个 Marketplace catalog 派生。写入、安装和本地操作仍需遵守 Host 权限与用户确认。

## Machine-readable indexes

- [All Mini Apps](${siteUrl("/ai/apps.json")}): 稳定应用实体、能力、权限、版本、详情和调用入口。
- [App content](${siteUrl("/ai/content.json")}): 指南、模板、工作流和内容级永久链接。
- [Questions and answers](${siteUrl("/ai/answers.json")}): 自然语言意图、直接答案和推荐应用。
- [Full AI guide](${siteUrl("/llms-full.txt")}): 完整 catalog-derived 能力与内容目录。
- [Sitemap](${siteUrl("/sitemap.xml")}): 所有公开页面。

## Mini Apps

${appLinks}

## Answers

${answerLinks}

## Optional

- [Fabushi Web](${siteUrl("/")}): 打开共享 Host 客户端。
- [Marketplace](${siteUrl("/apps")}): 浏览和安装 Mini Apps。
- [Search](${siteUrl("/search")}): 搜索应用与内容。
`;

  return new Response(body, {
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400",
      "content-language": "zh-CN",
    },
  });
}
