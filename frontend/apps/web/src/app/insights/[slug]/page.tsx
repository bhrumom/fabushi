import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { brand } from "@fabushi/shared";
import { SiteFooter } from "../../../components/site-footer";
import { SiteHeader } from "../../../components/site-header";
import { getAllArticles, getArticleBySlug } from "../../../lib/content";
import { siteHref, siteUrl } from "../../../lib/site-url";

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

  const articleUrl = siteUrl(`/insights/${article.slug}`);

  return {
    title: `${article.title} | ${brand.name}`,
    description: article.description,
    alternates: {
      canonical: articleUrl,
    },
    keywords: [article.category, article.title, `${brand.name} 更新`, "产品更新"],
    openGraph: {
      title: `${article.title} | ${brand.name}`,
      description: article.description,
      url: articleUrl,
      siteName: "Fabushi",
      locale: "zh_CN",
      type: "article",
      publishedTime: article.publishedAt,
      modifiedTime: article.updatedAt ?? article.publishedAt,
      authors: [article.author],
      section: article.category,
    },
    twitter: {
      card: "summary_large_image",
      title: `${article.title} | ${brand.name}`,
      description: article.description,
    },
  };
}

export default async function InsightArticlePage({ params }: { params: ArticlePageParams }) {
  const { slug } = await params;
  const article = getArticleBySlug(slug);

  if (!article) {
    notFound();
  }

  const articleUrl = siteUrl(`/insights/${article.slug}`);
  const relatedArticles = getAllArticles().filter((item) => item.slug !== article.slug).slice(0, 3);
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "BlogPosting",
        headline: article.title,
        description: article.description,
        url: articleUrl,
        mainEntityOfPage: articleUrl,
        articleSection: article.category,
        datePublished: article.publishedAt,
        dateModified: article.updatedAt ?? article.publishedAt,
        author: {
          "@type": "Person",
          name: article.author,
        },
        publisher: {
          "@type": "Organization",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          {
            "@type": "ListItem",
            position: 1,
            name: "首页",
            item: siteUrl("/"),
          },
          {
            "@type": "ListItem",
            position: 2,
            name: "内容专栏",
            item: siteUrl("/insights"),
          },
          {
            "@type": "ListItem",
            position: 3,
            name: article.title,
            item: articleUrl,
          },
        ],
      },
    ],
  };

  return (
    <main className="inner-page">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

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

      {relatedArticles.length > 0 ? (
        <section className="band">
          <div className="section-heading tight">
            <p>相关文章</p>
            <h2>继续了解相关更新。</h2>
          </div>
          <div className="editorial-list">
            {relatedArticles.map((item) => (
              <a key={item.slug} className="editorial-row" href={siteHref(`/insights/${item.slug}`)}>
                <span>{item.category}</span>
                <div>
                  <strong>{item.title}</strong>
                  <p>{item.description}</p>
                  <small>
                    {item.author} · {item.readTime}
                  </small>
                </div>
              </a>
            ))}
          </div>
        </section>
      ) : null}

      <section className="band alt">
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/buddhadharma")}>
            查看佛法入门
          </a>
          <a className="secondary-action" href={siteHref("/download")}>
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
