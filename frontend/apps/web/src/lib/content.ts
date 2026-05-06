import { insightArticles } from "../content/articles";

export function getAllArticles() {
  return insightArticles;
}

export function getArticleBySlug(slug: string) {
  return insightArticles.find((article) => article.slug === slug) ?? null;
}

export function getFeaturedArticles() {
  return insightArticles.filter((article) => article.featured);
}
