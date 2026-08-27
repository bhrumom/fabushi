import type { MetadataRoute } from "next";
import { getAllArticles } from "../lib/content";
import { marketplaceApps } from "../lib/marketplace";
import { siteUrl } from "../lib/site-url";

export const dynamic = "force-static";

const staticRoutes = [
  "/",
  "/app",
  "/app/ai",
  "/download",
  "/apply",
  "/faq",
  "/privacy",
  "/contact",
  "/insights",
  "/buddhadharma",
  "/start-learning-buddhism",
  "/buddhist-concepts",
  "/what-is-karma",
  "/what-is-bodhicitta",
  "/what-are-the-six-paramitas",
  "/what-is-emptiness",
  "/meditation",
  "/practice-guide",
  "/daily-practice",
  "/nianfo-guide",
  "/sutra-guide",
  "/sutra-listening",
  "/beginner-sutra-recommendations",
] as const;

const weeklyRoutes = new Set([
  "/",
  "/app",
  "/app/ai",
  "/download",
  "/faq",
  "/buddhadharma",
  "/start-learning-buddhism",
  "/buddhist-concepts",
  "/what-is-karma",
  "/what-is-bodhicitta",
  "/what-are-the-six-paramitas",
  "/what-is-emptiness",
  "/meditation",
  "/practice-guide",
  "/daily-practice",
  "/nianfo-guide",
  "/sutra-guide",
  "/sutra-listening",
  "/beginner-sutra-recommendations",
]);

const routeLastModified: Partial<Record<(typeof staticRoutes)[number], string>> = {
  "/": "2026-08-27",
  "/app": "2026-06-09",
  "/app/ai": "2026-06-09",
  "/download": "2026-05-18",
  "/faq": "2026-05-17",
  "/privacy": "2026-05-08",
  "/insights": "2026-05-17",
  "/buddhadharma": "2026-05-15",
  "/start-learning-buddhism": "2026-05-17",
  "/buddhist-concepts": "2026-05-17",
  "/what-is-karma": "2026-05-16",
  "/what-is-bodhicitta": "2026-05-16",
  "/what-are-the-six-paramitas": "2026-05-17",
  "/what-is-emptiness": "2026-05-16",
  "/meditation": "2026-05-15",
  "/practice-guide": "2026-05-16",
  "/daily-practice": "2026-05-16",
  "/nianfo-guide": "2026-05-17",
  "/sutra-guide": "2026-05-17",
  "/sutra-listening": "2026-05-16",
  "/beginner-sutra-recommendations": "2026-05-16",
};

export default function sitemap(): MetadataRoute.Sitemap {
  const pages: MetadataRoute.Sitemap = staticRoutes.map((route) => ({
    url: siteUrl(route),
    ...(routeLastModified[route] ? { lastModified: routeLastModified[route] } : {}),
    changeFrequency: weeklyRoutes.has(route) ? "weekly" : "monthly",
    priority:
      route === "/"
        ? 1
        : weeklyRoutes.has(route)
          ? 0.85
          : route === "/apply"
            ? 0.8
            : route === "/privacy"
              ? 0.6
              : 0.7,
  }));

  const appPages: MetadataRoute.Sitemap = marketplaceApps.map((app) => ({
    url: siteUrl(`/apps/${app.slug}`),
    lastModified: app.updatedAt,
    changeFrequency: "weekly",
    priority: app.featured ? 0.95 : 0.9,
  }));

  const appContentPages: MetadataRoute.Sitemap = marketplaceApps.flatMap((app) =>
    app.content.map((item) => ({
      url: siteUrl(`/apps/${app.slug}/content/${item.id}`),
      lastModified: item.updatedAt,
      changeFrequency: "monthly" as const,
      priority: 0.8,
    })),
  );

  const articlePages: MetadataRoute.Sitemap = getAllArticles().map((article) => ({
    url: siteUrl(`/insights/${article.slug}`),
    lastModified: new Date(article.updatedAt ?? article.publishedAt),
    changeFrequency: "monthly",
    priority: article.featured ? 0.8 : 0.65,
  }));

  return [...pages, ...appPages, ...appContentPages, ...articlePages];
}
