import type { Metadata } from "next";
import { brand, faqItems } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const faqUrl = siteUrl("/faq");
const faqTitle = `常见问题 | ${brand.name}`;
const faqDescription =
  "查看 Fabushi 是什么、现在能否下载，以及官网、微信小程序与主应用分别承担什么角色。";

const roleDefinitions = [
  {
    title: "官网负责先解释清楚",
    description: "首页、下载入口、FAQ、隐私说明和联系路径先承担理解、信任建立与转化，不让第一次访问的人只能靠猜。",
  },
  {
    title: "微信小程序负责轻触达",
    description: "更适合承接轻浏览、榜单、公开档案和微信生态内的快速传播，不承担最重的沉浸式流程。",
  },
  {
    title: "主应用负责完整体验",
    description: "更完整的内容浏览、上传分享、个人中心和重交互流程，继续放在主应用里逐步打磨。",
  },
] as const;

const faqJourneys = [
  {
    title: "想先判断现在能不能下载",
    description: "优先去下载页看 Beta、正式版和镜像入口的当前状态，而不是先点击一个可能还没开放的按钮。",
    href: "/download",
    ctaLabel: "去下载入口",
  },
  {
    title: "想参与内测或合作沟通",
    description: "先按 iOS、Android 或合作方向拆分入口，后续资格发放和反馈沟通会更顺畅。",
    href: "/apply",
    ctaLabel: "去申请测试",
  },
  {
    title: "想先确认边界和联系方式",
    description: "如果你更在意隐私说明、支持邮箱和公开协作路径，可以先看隐私页与联系页。",
    href: "/privacy",
    ctaLabel: "查看隐私说明",
  },
] as const;

export const metadata: Metadata = {
  title: faqTitle,
  description: faqDescription,
  alternates: {
    canonical: faqUrl,
  },
  keywords: ["法布施 FAQ", "Fabushi 常见问题", "法布施下载", "法布施官网", "法布施小程序"],
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
        item: faqUrl,
      },
    ],
  };

  return (
    <main className="inner-page">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
      />
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbJsonLd) }}
      />

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

      <section className="band alt">
        <div className="section-heading">
          <p>先讲角色</p>
          <h2>把三个入口各自负责什么说清楚，后面的下载、申请和内容理解才不会混在一起。</h2>
        </div>
        <div className="definition-grid">
          {roleDefinitions.map((item) => (
            <article key={item.title} className="definition-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>常见问题本体</p>
          <h2>这里优先回答首次访问最容易阻塞理解和决策的几个问题。</h2>
        </div>
        <div className="faq-list full">
          {faqItems.map((item) => (
            <details key={item.question} className="faq-item" open>
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>下一步怎么走</p>
          <h2>FAQ 的价值不只是回答问题，还要把人送到正确的下一页。</h2>
        </div>
        <div className="path-grid">
          {faqJourneys.map((item) => (
            <article key={item.title} className="path-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
              <a className="path-link" href={siteHref(item.href)}>
                {item.ctaLabel}
              </a>
            </article>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/contact")}>
            查看联系信息
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
