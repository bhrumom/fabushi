import type { MetadataRoute } from "next";
import { getAllArticles } from "../lib/content";
import { siteUrl } from "../lib/site-url";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  const routes: MetadataRoute.Sitemap = ["/", "/download", "/apply", "/faq", "/contact", "/insights"].map((path) => ({
    url: siteUrl(path),
    lastModified: "2026-05-06",
  }));

  const articleRoutes = getAllArticles().map((article) => ({
    url: siteUrl(`/insights/${article.slug}`),
    lastModified: article.publishedAt,
  }));

  return [...routes, ...articleRoutes];
}
