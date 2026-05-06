export interface InsightArticle {
  slug: string;
  title: string;
  description: string;
  category: string;
  publishedAt: string;
  updatedAt?: string;
  author: string;
  readTime: string;
  featured?: boolean;
  body: string[];
}
