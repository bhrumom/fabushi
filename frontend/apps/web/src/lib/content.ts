import { insightArticles } from "@fabushi/shared";

export function getAllArticles() {
  return insightArticles;
}

export function getArticleBySlug(slug: string) {
  return insightArticles.find((article) => article.slug === slug) ?? null;
}
