import { fabushiAnswerIntents } from "../../lib/ai-discovery";
import { marketplaceApps } from "../../lib/marketplace";
import { siteUrl } from "../../lib/site-url";

export const dynamic = "force-static";

export function GET() {
  const appSections = marketplaceApps
    .map((app) => {
      const contentLinks = app.content
        .map(
          (item) =>
            `- [${item.title}](${siteUrl(`/apps/${app.slug}/content/${item.id}`)}): ${item.summary}`,
        )
        .join("\n");
      return `## ${app.name} (${app.englishName})

- Entity: ${siteUrl(`/apps/${app.slug}#app`)}
- Machine record: ${siteUrl(`/ai/apps/${app.slug}.json`)}
- Details: ${siteUrl(`/apps/${app.slug}`)}
- Launch: ${siteUrl(`/miniapps/${app.id}`)}
- Category: ${app.category}
- Version: ${app.version}
- Updated: ${app.updatedAt}
- Description: ${app.description}
- Capabilities: ${app.capabilities.join("；")}
- Permissions: ${app.permissions.join("；")}
- Tags: ${app.tags.join("；")}
- Pricing: ${app.pricing.label}；${app.pricing.detail}

### Public content

${contentLinks || "- No public content entries."}`;
    })
    .join("\n\n");

  const answers = fabushiAnswerIntents
    .map(
      (answer) =>
        `- [${answer.question}](${siteUrl(`/answers/${answer.slug}`)}): ${answer.answer} Recommended app: ${answer.recommendedAppSlug}.`,
    )
    .join("\n");

  const body = `# Fabushi full AI discovery guide

> This document is generated from the same public Marketplace catalog used by the Fabushi Host and Marketplace. It is an auxiliary discovery surface; canonical app entities and permissions remain authoritative.

## Product model

Fabushi Host is the main product. Mini Apps are native first-class capabilities. Marketplace provides discovery and installation. Public app/content/answer pages provide stable citation URLs. WebMCP exposes structured read and action tools; action tools preserve user confirmation.

## Machine endpoints

- Apps: ${siteUrl("/ai/apps.json")}
- Content: ${siteUrl("/ai/content.json")}
- Answers: ${siteUrl("/ai/answers.json")}
- Search index: ${siteUrl("/search-index.json")}
- Sitemap: ${siteUrl("/sitemap.xml")}

${appSections}

## Natural-language answers

${answers}
`;

  return new Response(body, {
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400",
      "content-language": "zh-CN",
    },
  });
}
