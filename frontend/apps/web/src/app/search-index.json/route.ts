import { appEntityId, appMachineUrl } from "../../lib/ai-discovery";
import { MARKETPLACE_CATEGORY_LABELS, marketplaceApps } from "../../lib/marketplace";
import { siteUrl } from "../../lib/site-url";

export const dynamic = "force-static";

export function GET() {
  const index = {
    schema: "fabushi.marketplace.search-index.v1",
    generatedAt: "2026-08-27",
    language: "zh-CN",
    marketplaceUrl: siteUrl("/"),
    searchUrlTemplate: `${siteUrl("/search")}?q={query}`,
    apps: marketplaceApps.map((app) => ({
      id: app.id,
      entityId: appEntityId(app),
      machineUrl: appMachineUrl(app),
      slug: app.slug,
      name: app.name,
      englishName: app.englishName,
      subtitle: app.subtitle,
      description: app.description,
      category: app.category,
      categoryLabel: MARKETPLACE_CATEGORY_LABELS[app.category],
      developer: app.developer,
      verified: app.verified,
      tags: app.tags,
      capabilities: app.capabilities,
      permissions: app.permissions,
      pricing: app.pricing,
      version: app.version,
      updatedAt: app.updatedAt,
      detailsUrl: siteUrl(`/apps/${app.slug}`),
      launchUrl: siteUrl(`/miniapps/${app.id}`),
      content: app.content.map((item) => ({
        id: item.id,
        entityId: siteUrl(`/apps/${app.slug}/content/${item.id}#article`),
        type: item.type,
        title: item.title,
        summary: item.summary,
        keywords: item.keywords,
        updatedAt: item.updatedAt,
        readingMinutes: item.readingMinutes,
        url: siteUrl(`/apps/${app.slug}/content/${item.id}`),
      })),
    })),
  };

  return Response.json(index, {
    headers: {
      "cache-control": "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400",
      "content-language": "zh-CN",
    },
  });
}
