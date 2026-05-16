import type { MetadataRoute } from "next";
import { getAllArticles } from "../lib/content";
import { siteUrl } from "../lib/site-url";

export const dynamic = "force-static";

const staticRoutes = [
  "/",
  "/download",
  "/apply",
  "/faq",
  "/privacy",
  "/contact",
  "/insights",
  "/buddhadharma",
  "/start-learning-buddhism",
  "/what-is-karma",
  "/meditation",
  "/practice-guide",
  "/daily-practice",
  "/sutra-guide",
  "/sutra-listening",
  "/beginner-sutra-recommendations",
] as const;

const weeklyRoutes = new Set([
  "/",
  "/download",
  "/faq",
  "/buddhadharma",
  "/start-learning-buddhism",
  "/what-is-karma",
  "/meditation",
  "/practice-guide",
  "/daily-practice",
  "/sutra-guide",
  "/sutra-listening",
  "/beginner-sutra-recommendations",
]);

export default function sitemap(): MetadataRoute.Sitemap {
  const pages: MetadataRoute.Sitemap = staticRoutes.map((route) => ({
    url: siteUrl(route),
    lastModified: route === "/privacy" ? "2026-05-08" : new Date(),
    changeFrequency: weeklyRoutes.has(route) ? "weekly" : "monthly",
    priority:
      route === "/"
        ? 1
        : weeklyRoutes.has(route)
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
