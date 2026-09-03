import {
  AI_DISCOVERY_LANGUAGE,
  AI_DISCOVERY_SCHEMA,
  AI_DISCOVERY_UPDATED_AT,
  serializeAppForAi,
} from "../../../../lib/ai-discovery";
import { getMarketplaceApp, marketplaceApps } from "../../../../lib/marketplace";

export const dynamic = "force-static";
export const dynamicParams = false;

export function generateStaticParams() {
  return marketplaceApps.map((app) => ({ file: `${app.slug}.json` }));
}

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ file: string }> },
) {
  const { file } = await params;
  const slug = file.endsWith(".json") ? file.slice(0, -5) : file;
  const app = getMarketplaceApp(slug);

  if (!app || file !== `${app.slug}.json`) {
    return Response.json({ error: "app_not_found", slug }, { status: 404 });
  }

  return Response.json(
    {
      "@context": "https://schema.org",
      schema: `${AI_DISCOVERY_SCHEMA}.app`,
      generatedAt: AI_DISCOVERY_UPDATED_AT,
      language: AI_DISCOVERY_LANGUAGE,
      item: serializeAppForAi(app),
    },
    {
      headers: {
        "cache-control": "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400",
        "content-language": AI_DISCOVERY_LANGUAGE,
      },
    },
  );
}
