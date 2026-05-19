import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { FaliuShell } from "../../components/faliu-shell";
import { siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/faliu");
const pageTitle = `法流 | CBETA 佛典流式浏览 | ${brand.name}`;
const pageDescription =
  "法流页使用 CBETA API 提供佛典题名、卷次与正文浏览，并接入法布施 App 后端的互动统计与评论数据。";

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "法流",
    "CBETA API",
    "佛典浏览",
    "佛经搜索",
    "大藏经阅读",
    "Fabushi 法流",
  ],
  openGraph: {
    title: pageTitle,
    description: pageDescription,
    url: pageUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: pageTitle,
    description: pageDescription,
  },
};

export default function FaliuPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "法流",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
      },
      {
        "@type": "SearchResultsPage",
        name: "CBETA 佛典流式浏览",
        url: pageUrl,
        description: "浏览精选佛典、切换专题分类，并查看卷次正文与互动数据。",
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

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">
            <LocalizedText zh="法流" en="Faloo" />
          </p>
          <h1>
            <LocalizedText
              zh="把佛典浏览做成更顺手的流式入口。"
              en="Turn scripture browsing into a calmer flowing surface."
            />
          </h1>
          <p className="lede">
            <LocalizedText
              zh="这里用 CBETA API 提供正文与经目信息，同时接入 App 后端里的点赞、评论等互动统计。"
              en="This surface uses the CBETA API for text and catalog data, while pulling engagement stats from the app backend."
            />
          </p>
        </div>
      </section>

      <FaliuShell />
      <SiteFooter />
    </main>
  );
}
