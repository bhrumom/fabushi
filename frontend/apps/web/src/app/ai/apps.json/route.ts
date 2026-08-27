import {
  AI_DISCOVERY_LANGUAGE,
  AI_DISCOVERY_SCHEMA,
  AI_DISCOVERY_UPDATED_AT,
  serializeAppForAi,
} from "../../../lib/ai-discovery";
import { marketplaceApps } from "../../../lib/marketplace";
import { siteUrl } from "../../../lib/site-url";

export const dynamic = "force-static";

export function GET() {
  return Response.json(
    {
      "@context": "https://schema.org",
      schema: `${AI_DISCOVERY_SCHEMA}.apps`,
      generatedAt: AI_DISCOVERY_UPDATED_AT,
      language: AI_DISCOVERY_LANGUAGE,
      canonicalUrl: siteUrl("/ai/apps.json"),
      count: marketplaceApps.length,
      items: marketplaceApps.map(serializeAppForAi),
    },
    {
      headers: {
        "cache-control": "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400",
        "content-language": AI_DISCOVERY_LANGUAGE,
      },
    },
  );
}
