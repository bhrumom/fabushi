import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { brand } from "@fabushi/shared";
import { SiteFooter } from "../../../components/site-footer";
import { SiteHeader } from "../../../components/site-header";
import { getAllArticles, getArticleBySlug } from "../../../lib/content";
import { siteHref } from "../../../lib/site-url";

type ArticlePageParams = Promise<{ slug: string }>;

export function generateStaticParams() {
  return getAllArticles().map((article) => ({ slug: article.slug }));
}

export async function generateMetadata({ params }: { params: ArticlePageParams }): Promise<Metadata> {
  const { slug } = await params;
  const article = getArticleBySlug(slug);
  if (!article) {
    return {};
  }

  return {
    title: `${article.title} | ${brand.name}`,
    description: article.description,
  };
}

export default async function InsightArticlePage({ params }: { params: ArticlePageParams }) {
  const { slug } = await params;
  const article = getArticleBySlug(slug);

  if (!article) {
    notFound();
  }

  return (
    <main className="inner-page">
      <section className="inner-hero article">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">{article.category}</p>
          <h1>{article.title}</h1>
          <p className="lede">{article.description}</p>
          <span className="article-date">
            {article.publishedAt} · {article.author} · {article.readTime}
          </span>
        </div>
      </section>

      <article className="article-body">
        {article.body.map((paragraph) => (
          <p key={paragraph}>{paragraph}</p>
        ))}
      </article>

      <section className="band alt">
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/download")}>
            查看下载入口
          </a>
          <a className="secondary-action" href={siteHref("/faq")}>
            查看常见问题
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
