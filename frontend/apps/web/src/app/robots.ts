import type { MetadataRoute } from "next";
import { siteUrl } from "../lib/site-url";

export const dynamic = "force-static";

const publicCrawlerRule = (userAgent: string) => ({
  userAgent,
  allow: "/",
  disallow: ["/api/"],
});

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      publicCrawlerRule("OAI-SearchBot"),
      publicCrawlerRule("ChatGPT-User"),
      publicCrawlerRule("Googlebot"),
      publicCrawlerRule("Bingbot"),
      publicCrawlerRule("*"),
    ],
    sitemap: siteUrl("/sitemap.xml"),
    host: new URL(siteUrl("/")).origin,
  };
}
