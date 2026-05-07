import type { Metadata } from "next";
import { brand, faqItems } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

export const metadata: Metadata = {
  title: `常见问题 | ${brand.name}`,
  description: "查看 Fabushi 是什么、是否可下载，以及官网、微信小程序与主应用分别承担什么角色。",
  alternates: {
    canonical: siteUrl("/faq"),
  },
  keywords: ["法布施 FAQ", "Fabushi 常见问题", "法布施下载", "法布施官网", "法布施小程序"],
};

export default function FaqPage() {
  const faqJsonLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqItems.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: item.answer,
      },
    })),
  };
  const breadcrumbJsonLd = {
    "@context": "https://schema.org",
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
        name: "常见问题",
        item: siteUrl("/faq"),
      },
    ],
  };

  return (
    <main className="inner-page">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbJsonLd) }} />

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">常见问题</p>
          <h1>把用户最容易问的关键问题写清楚，官网才真正开始承担解释和转化的工作。</h1>
          <p className="lede">
            这一页优先回答 Fabushi 是什么、现在能否下载、适合哪些人先关注，以及官网、微信小程序和 Flutter 主应用之间的分工关系。
          </p>
        </div>
      </section>

      <section className="band">
        <div className="faq-list full">
          {faqItems.map((item) => (
            <details key={item.question} className="faq-item" open>
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/download")}>
            去下载入口
          </a>
          <a className="secondary-action" href={siteHref("/contact")}>
            查看联系信息
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
