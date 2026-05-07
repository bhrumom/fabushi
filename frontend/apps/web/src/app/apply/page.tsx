import type { Metadata } from "next";
import { betaApplicationTracks, brand } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const applyUrl = siteUrl("/apply");
const applyTitle = `申请测试 | ${brand.name}`;
const applyDescription = "查看 Fabushi 当前可申请的测试与合作入口，并按不同场景选择对应通道。";

const applicationJourneys = [
  {
    title: "想先体验完整主应用流程",
    description: "更适合先看 iOS TestFlight 入口，尤其是你想重点体验完整内容浏览、个人中心和重交互流程时。",
    href: "mailto:support@fabushi.com?subject=Fabushi%20iOS%20Beta%20Application",
    ctaLabel: "申请 iOS 内测",
  },
  {
    title: "想尽快跟上最新交付进度",
    description: "更适合先看 Android Beta，尤其是你愿意更早体验新版本并持续反馈问题时。",
    href: "mailto:support@fabushi.com?subject=Fabushi%20Android%20Beta%20Application",
    ctaLabel: "申请 Android 内测",
  },
  {
    title: "想讨论传播合作或渠道联动",
    description: "如果你更在意内容共建、活动承接或渠道资源，直接走合作入口会更准确。",
    href: "mailto:support@fabushi.com?subject=Fabushi%20Partnership%20Inquiry",
    ctaLabel: "发起合作沟通",
  },
] as const;

const prepChecklist = [
  {
    title: "先说你的目标",
    description: "说明你更关心传播、修行记录、榜单社交、设备测试，还是渠道合作。",
  },
  {
    title: "把必要信息一次带全",
    description: "包括常用邮箱、平台、机型、系统版本，或者合作方向与可回联方式。",
  },
  {
    title: "最好提前说明反馈意愿",
    description: "如果你愿意持续反馈体验问题，后续资格发放和沟通节奏通常会更顺。",
  },
] as const;

const applicationSignals = [
  {
    title: "入口先分清楚",
    description: "把 iOS、Android 和合作沟通拆成三条路径，本身就是在减少后续筛选成本。",
  },
  {
    title: "申请页先服务真实决策",
    description: "这页不是为了堆表单，而是帮你更快判断自己该走哪条通道。",
  },
  {
    title: "下载与申请会互相配合",
    description: "如果下载页暂时还没有适合你的公开入口，申请页就应该成为自然的下一步。",
  },
] as const;

export const metadata: Metadata = {
  title: applyTitle,
  description: applyDescription,
  alternates: {
    canonical: applyUrl,
  },
  keywords: ["法布施内测", "Fabushi 申请测试", "法布施 Android Beta", "法布施 TestFlight", "法布施合作"],
  openGraph: {
    title: applyTitle,
    description: applyDescription,
    url: applyUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: applyTitle,
    description: applyDescription,
  },
};

export default function ApplyPage() {
  const applyPageJsonLd = {
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    name: `${brand.name} 申请测试`,
    url: applyUrl,
    inLanguage: "zh-CN",
    description: "Fabushi 当前开放的 iOS、Android 与合作沟通申请通道。",
    mainEntity: {
      "@type": "ItemList",
      itemListElement: betaApplicationTracks.map((item, index) => ({
        "@type": "ListItem",
        position: index + 1,
        item: {
          "@type": "EntryPoint",
          name: item.name,
          description: item.summary,
          urlTemplate: siteHref(item.ctaHref),
        },
      })),
    },
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
        name: "申请测试",
        item: applyUrl,
      },
    ],
  };

  return (
    <main className="inner-page">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(applyPageJsonLd) }}
      />
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbJsonLd) }}
      />

      <section className="inner-hero">
        <SiteHeader />
        <div className="inner-copy">
          <p className="eyebrow">申请测试</p>
          <h1>先把申请入口分清楚，后续沟通和发放资格才不会乱成一团。</h1>
          <p className="lede">
            当前官网阶段最需要的是把 iOS、Android 和合作沟通三条入口拆清楚，
            让不同目的的人能直接走到正确通道，而不是先发来一封没有上下文的邮件。
          </p>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>先判断你该走哪条路</p>
          <h2>这一步先做对，后面的资格发放、设备确认和反馈沟通会简单很多。</h2>
        </div>
        <div className="path-grid">
          {applicationJourneys.map((item) => (
            <article key={item.title} className="path-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
              <a className="path-link" href={siteHref(item.href)}>
                {item.ctaLabel}
              </a>
            </article>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>申请前最好先准备</p>
          <h2>把这些信息一次带上，往返确认和资格筛选通常会更高效。</h2>
        </div>
        <div className="definition-grid">
          {prepChecklist.map((item) => (
            <article key={item.title} className="definition-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>申请通道</p>
          <h2>按你的目标选择入口，会比一股脑挤到同一个邮箱主题里更高效。</h2>
        </div>
        <div className="application-grid">
          {betaApplicationTracks.map((item) => (
            <article key={item.name} className="application-card">
              <div>
                <p className="eyebrow">{item.name}</p>
                <h2>{item.name}</h2>
              </div>
              <p className="application-summary">{item.summary}</p>
              <ol className="application-list">
                {item.checklist.map((entry) => (
                  <li key={entry}>{entry}</li>
                ))}
              </ol>
              <a className="primary-action" href={siteHref(item.ctaHref)}>
                {item.ctaLabel}
              </a>
            </article>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>为什么这一页值得先看</p>
          <h2>申请页不仅是一个入口集合，更是把下载、反馈和合作分流清楚的关键环节。</h2>
        </div>
        <div className="evidence-grid">
          {applicationSignals.map((item) => (
            <article key={item.title} className="evidence-card">
              <strong>{item.title}</strong>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>申请建议</p>
          <h2>把基本信息一次带全，往返确认会少很多。</h2>
        </div>
        <ol className="roadmap-list">
          <li>说明你最关心的是传播、修行记录、榜单社交，还是渠道合作。</li>
          <li>如果是设备测试，请把平台、机型或系统版本一并写清楚。</li>
          <li>如果你愿意持续反馈问题，也建议在申请邮件里直接写明。</li>
        </ol>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/download")}>
            回到下载入口
          </a>
          <a className="secondary-action" href={siteHref("/privacy")}>
            查看隐私说明
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
