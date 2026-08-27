import {
  AI_DISCOVERY_LANGUAGE,
  AI_DISCOVERY_SCHEMA,
  AI_DISCOVERY_UPDATED_AT,
  serializeContentForAi,
} from "../../../lib/ai-discovery";
import { siteUrl } from "../../../lib/site-url";

export const dynamic = "force-static";

export function GET() {
  const items = serializeContentForAi();
  return Response.json(
    {
      "@context": "https://schema.org",
      schema: `${AI_DISCOVERY_SCHEMA}.content`,
      generatedAt: AI_DISCOVERY_UPDATED_AT,
      language: AI_DISCOVERY_LANGUAGE,
      canonicalUrl: siteUrl("/ai/content.json"),
      count: items.length,
      items,
    },
    {
      headers: {
        "cache-control": "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400",
        "content-language": AI_DISCOVERY_LANGUAGE,
      },
    },
  );
}
