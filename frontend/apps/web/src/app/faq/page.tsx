import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocalizedText } from "../../components/localized-text";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const faqUrl = siteUrl("/faq");
const faqTitle = `FAQ | ${brand.name}`;
const faqDescription = "Fabushi download, beta access, and support questions.";

const faqItems = [
  {
    questionZh: "我应该下载哪个版本？",
    questionEn: "Which version should I download?",
    answerZh: "想尽快体验新功能，先看测试版；更重视稳定性，就等正式版。",
    answerEn: "Choose beta if you want new features quickly. Wait for stable if you prefer a steadier path.",
  },
  {
    questionZh: "iOS 为什么会跳到 TestFlight？",
    questionEn: "Why does iOS open TestFlight?",
    answerZh: "iOS 内测通过 Apple TestFlight 分发，公开加入链接准备好后会直接显示。",
    answerEn: "iOS beta is distributed through Apple TestFlight, and the public join link appears here once it is ready.",
  },
  {
    questionZh: "Android 下载慢怎么办？",
    questionEn: "What if Android downloads are slow?",
    answerZh: "优先尝试下载页里的镜像链接；原始链接也会继续保留。",
    answerEn: "Try the mirror links on the download page first. The original link stays available too.",
  },
  {
    questionZh: "官网会显示版本更新信息吗？",
    questionEn: "Will the site show release updates?",
    answerZh: "会。首页和下载页都会同步 GitHub 发布版本、发布时间和更新摘要。",
    answerEn: "Yes. The homepage and download page sync GitHub release versions, publish time, and update summaries.",
  },
] as const;

export const metadata: Metadata = {
  title: faqTitle,
  description: faqDescription,
  alternates: {
    canonical: faqUrl,
  },
  keywords: ["Fabushi FAQ", "download help", "beta access"],
  openGraph: {
    title: faqTitle,
    description: faqDescription,
    url: faqUrl,
    siteName: "Fabushi",
    locale: "en_US",
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
      name: item.questionEn,
      acceptedAnswer: {
        "@type": "Answer",
        text: item.answerEn,
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
          <h1>
            <LocalizedText zh="先解决下载前会卡住的问题。" en="Solve the questions that usually block a download first." />
          </h1>
          <p className="lede">
            <LocalizedText zh="产品、下载、内测和支持方式都在这里。" en="Product, download, beta access, and support answers all live here." />
          </p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="faq-list full">
          {faqItems.map((item) => (
            <details key={item.questionEn} className="faq-item">
              <summary>
                <LocalizedText zh={item.questionZh} en={item.questionEn} />
              </summary>
              <p>
                <LocalizedText zh={item.answerZh} en={item.answerEn} />
              </p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/download")}>
            <LocalizedText zh="去下载" en="Go to downloads" />
          </a>
          <a className="secondary-action" href={siteHref("/apply")}>
            <LocalizedText zh="申请测试" en="Apply for beta" />
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
