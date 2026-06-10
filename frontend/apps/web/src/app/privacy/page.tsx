import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const privacyUrl = siteUrl("/privacy");
const privacyTitle = `隐私说明 | ${brand.name}`;
const privacyDescription = "Fabushi 对测试申请、账号、设备信息和支持沟通的隐私说明。";

const privacySections = [
  {
    title: "我们会处理什么",
    text: "测试申请、支持邮件和账号相关流程中，你主动提供的邮箱、平台、设备、问题说明或合作信息。",
  },
  {
    title: "为什么处理",
    text: "用于发送测试入口、排查下载与安装问题、维护账号服务、回应反馈和沟通合作。",
  },
  {
    title: "不会做什么",
    text: "不会因为你浏览官网就要求注册，也不会为了无关营销扩大收集范围。",
  },
  {
    title: "如何联系",
    text: "你可以通过支持邮箱询问、更新或删除与自己相关的申请和反馈信息。",
  },
] as const;

const privacyFaqs = [
  {
    question: "申请测试需要哪些信息？",
    answer: "通常需要邮箱、平台、设备型号和你最想体验的功能。",
  },
  {
    question: "只是浏览官网需要注册吗？",
    answer: "不需要。下载状态、FAQ、隐私说明和联系入口都可以直接查看。",
  },
  {
    question: "如何删除或更正信息？",
    answer: "通过支持邮箱联系，并说明要查询、更新或删除的信息范围。",
  },
] as const;

export const metadata: Metadata = {
  title: privacyTitle,
  description: privacyDescription,
  alternates: {
    canonical: privacyUrl,
  },
  keywords: ["Fabushi 隐私说明", "法布施隐私政策", "法布施测试申请"],
  openGraph: {
    title: privacyTitle,
    description: privacyDescription,
    url: privacyUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: privacyTitle,
    description: privacyDescription,
  },
};

export default function PrivacyPage() {
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@ombhrum.com";
  const supportHref = contactChannels.find((item) => item.href.startsWith("mailto:"))?.href ?? "mailto:support@ombhrum.com";
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        name: `${brand.name} 隐私说明`,
        url: privacyUrl,
        inLanguage: "zh-CN",
        description: privacyDescription,
        about: {
          "@type": "Organization",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
          email: supportEmail,
        },
      },
      {
        "@type": "FAQPage",
        mainEntity: privacyFaqs.map((item) => ({
          "@type": "Question",
          name: item.question,
          acceptedAnswer: {
            "@type": "Answer",
            text: item.answer,
          },
        })),
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
          <p className="eyebrow">隐私说明</p>
          <h1>只收集完成当前动作所需的信息。</h1>
          <p className="lede">测试申请、下载反馈、账号支持和合作沟通，都保持用途清楚。</p>
        </div>
      </section>

      <section className="band compact-band">
        <div className="governance-grid">
          {privacySections.map((item) => (
            <article key={item.title} className="governance-card">
              <h3>{item.title}</h3>
              <p>{item.text}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>边界说清楚。</h2>
        </div>
        <div className="faq-list full">
          {privacyFaqs.map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={supportHref}>
            联系支持
          </a>
          <a className="secondary-action" href={siteHref("/download")}>
            回到下载
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
