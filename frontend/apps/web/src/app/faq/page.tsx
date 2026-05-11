import type { Metadata } from "next";
import { brand, faqItems } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const faqUrl = siteUrl("/faq");
const faqTitle = `常见问题 | ${brand.name}`;
const faqDescription = "查看 Fabushi 下载、内测、平台入口和支持方式。";

export const metadata: Metadata = {
  title: faqTitle,
  description: faqDescription,
  alternates: {
    canonical: faqUrl,
  },
  keywords: ["法布施 FAQ", "Fabushi 常见问题", "法布施下载"],
  openGraph: {
    title: faqTitle,
    description: faqDescription,
    url: faqUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: faqTitle,
    description: faqDescription,
  },
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

  return (
    <main className="inner-page">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
      />

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">FAQ</p>
          <h1>先解决下载前会卡住的问题。</h1>
          <p className="lede">产品、下载、内测、支持方式都在这里。</p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="faq-list full">
          {faqItems.map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/download")}>
            去下载
          </a>
          <a className="secondary-action" href={siteHref("/apply")}>
            申请测试
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
