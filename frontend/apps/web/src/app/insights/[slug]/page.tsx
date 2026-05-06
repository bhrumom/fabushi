import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { brand } from "@fabushi/shared";
import { SiteFooter } from "../../../components/site-footer";
import { SiteHeader } from "../../../components/site-header";
import { getAllArticles, getArticleBySlug } from "../../../lib/content";

export function generateStaticParams() {
  return getAllArticles().map((article) => ({ slug: article.slug }));
}

export function generateMetadata({ params }: { params: { slug: string } }): Metadata {
  const article = getArticleBySlug(params.slug);
  if (!article) {
    return {};
  }

  return {
    title: `${article.title} | ${brand.name}`,
    description: article.description,
  };
}

export default function InsightArticlePage({ params }: { params: { slug: string } }) {
  const article = getArticleBySlug(params.slug);

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
        {article.body.map((paragraph: string) => (
          <p key={paragraph}>{paragraph}</p>
        ))}
      </article>

      <section className="band alt">
        <div className="inline-cta">
          <a className="primary-action" href="/download">
            查看下载入口
          </a>
          <a className="secondary-action" href="/faq">
            查看常见问题
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
