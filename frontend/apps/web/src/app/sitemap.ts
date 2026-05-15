import type { MetadataRoute } from "next";
import { getAllArticles } from "../lib/content";
import { siteUrl } from "../lib/site-url";

export const dynamic = "force-static";

const staticRoutes = ["/", "/download", "/apply", "/faq", "/privacy", "/contact", "/insights", "/buddhadharma"] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  const pages: MetadataRoute.Sitemap = staticRoutes.map((route) => ({
    url: siteUrl(route),
    lastModified: route === "/privacy" ? "2026-05-08" : new Date(),
    changeFrequency:
      route === "/"
        ? "weekly"
        : route === "/download" || route === "/faq" || route === "/buddhadharma"
          ? "weekly"
          : "monthly",
    priority:
      route === "/"
        ? 1
        : route === "/download" || route === "/faq" || route === "/buddhadharma"
          ? 0.9
          : route === "/apply"
            ? 0.85
            : route === "/privacy"
              ? 0.8
              : 0.75,
  }));

  const articlePages: MetadataRoute.Sitemap = getAllArticles().map((article) => ({
    url: siteUrl(`/insights/${article.slug}`),
    lastModified: new Date(article.publishedAt),
    changeFrequency: "monthly",
    priority: article.featured ? 0.8 : 0.65,
  }));

  return [...pages, ...articlePages];
}
