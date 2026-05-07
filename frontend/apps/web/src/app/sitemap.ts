import type { MetadataRoute } from "next";
import { getAllArticles } from "../lib/content";
import { siteUrl } from "../lib/site-url";

export const dynamic = "force-static";

const staticRoutes = ["/", "/download", "/apply", "/faq", "/contact", "/insights"] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  const routes: MetadataRoute.Sitemap = staticRoutes.map((path) => ({
    url: siteUrl(path),
    lastModified: "2026-05-07",
    changeFrequency: path === "/" ? "weekly" : path === "/download" || path === "/faq" ? "weekly" : "monthly",
    priority: path === "/" ? 1 : path === "/download" || path === "/faq" ? 0.9 : path === "/apply" ? 0.85 : 0.75,
  }));

  const articleRoutes: MetadataRoute.Sitemap = getAllArticles().map((article) => ({
    url: siteUrl(`/insights/${article.slug}`),
    lastModified: article.publishedAt,
    changeFrequency: "monthly",
    priority: article.featured ? 0.8 : 0.65,
  }));

  return [...routes, ...articleRoutes];
}
