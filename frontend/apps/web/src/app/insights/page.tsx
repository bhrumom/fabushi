import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { getAllArticles } from "../../lib/content";
import { siteHref, siteUrl } from "../../lib/site-url";

const insightsUrl = siteUrl("/insights");
const insightsTitle = `内容专栏 | ${brand.name}`;
const insightsDescription = "查看 Fabushi 的产品更新、版本说明和官网内容建设进展。";

export const metadata: Metadata = {
  title: insightsTitle,
  description: insightsDescription,
  alternates: {
    canonical: insightsUrl,
  },
  keywords: ["Fabushi 内容专栏", "产品更新", "版本说明", "官网更新"],
  openGraph: {
    title: insightsTitle,
    description: insightsDescription,
    url: insightsUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: insightsTitle,
    description: insightsDescription,
  },
};

export default function InsightsIndexPage() {
  const articles = getAllArticles();
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: "Fabushi 内容专栏",
    url: insightsUrl,
    description: insightsDescription,
    inLanguage: "zh-CN",
    hasPart: articles.map((item) => ({
      "@type": "Article",
      headline: item.title,
      description: item.description,
      url: siteUrl(`/insights/${item.slug}`),
    })),
  };

  return (
    <main className="inner-page">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">
            <LocalizedText zh="内容专栏" en="Insights" />
          </p>
          <h1>
            <LocalizedText
              zh="产品更新、版本说明与官网内容进展。"
              en="Product updates, release notes, and official site progress."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="这里主要记录版本、下载体验和官网迭代；佛法入门内容已单独整理到专题页。"
              en="This section tracks releases, downloads, and site updates, while dharma basics now live in a dedicated guide."
            />
          </p>
        </div>
      </section>

      <section className="band">
        <div className="editorial-list">
          {articles.map((item) => (
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
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/buddhadharma")}>
            <LocalizedText zh="查看佛法入门" en="Open Dharma Basics" />
          </a>
          <a className="secondary-action" href={siteHref("/download")}>
            <LocalizedText zh="查看下载入口" en="View downloads" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
