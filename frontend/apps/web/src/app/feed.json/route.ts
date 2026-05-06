import { getAllArticles } from "../../lib/content";

export function GET() {
  const items = getAllArticles().map((article) => ({
    slug: article.slug,
    title: article.title,
    description: article.description,
    category: article.category,
    publishedAt: article.publishedAt,
    updatedAt: article.updatedAt ?? article.publishedAt,
    author: article.author,
    readTime: article.readTime,
    url: `https://fabushi.ombhrum.com/insights/${article.slug}`,
  }));

  return Response.json({
    site: "Fabushi",
    generatedAt: "2026-05-06",
    items,
  });
}
