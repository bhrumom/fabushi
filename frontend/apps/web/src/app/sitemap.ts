import type { MetadataRoute } from "next";
import { getAllArticles } from "../lib/content";
import { siteUrl } from "../lib/site-url";

export const dynamic = "force-static";

const staticRoutes = ["/", "/download", "/apply", "/faq", "/contact", "/insights"] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  const pages: MetadataRoute.Sitemap = staticRoutes.map((route) => ({
    url: siteUrl(route),
    lastModified: new Date(),
    changeFrequency: route === "/" ? "weekly" : "monthly",
    priority: route === "/" ? 1 : route === "/download" || route === "/faq" ? 0.9 : 0.7,
  }));

  const articlePages: MetadataRoute.Sitemap = getAllArticles().map((article) => ({
    url: siteUrl(`/insights/${article.slug}`),
    lastModified: new Date(article.publishedAt),
    changeFrequency: "monthly",
    priority: article.featured ? 0.8 : 0.6,
  }));

  return [...pages, ...articlePages];
}
