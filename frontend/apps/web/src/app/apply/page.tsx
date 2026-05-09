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

const applicationProcessSteps = [
  {
    title: "先确认你属于哪条入口",
    description: "官网会先按 iOS、Android 和合作沟通三种目标来判断，不同目的不会混在同一个处理队列里。",
  },
  {
    title: "再看当前开放阶段是否匹配",
    description: "如果对应入口仍在准备、名额有限或发布状态还没公开，会先回复当前阶段和更合适的下一步，而不是假装已经开放。",
  },
  {
    title: "通过邮件继续确认关键信息",
    description: "设备、系统版本、关注模块和反馈意愿，通常都会决定后续该发哪个入口、什么时候发。",
  },
  {
    title: "资格发放后继续进入反馈闭环",
    description: "申请页不是终点，下载、体验、反馈和后续版本说明会继续回到官网、邮件或公开协作通道里。",
  },
] as const;

const applicationReviewPrinciples = [
  {
    title: "会明确当前状态",
    description: "如果入口还没准备好，官网和邮件都应该先告诉你目前处于什么阶段，而不是只让你等待。",
  },
  {
    title: "会按场景分流处理",
    description: "下载体验、资格申请、合作沟通和公开建议，本来就不该挤进同一套回复逻辑里。",
  },
  {
    title: "不会承诺并不存在的自动化流程",
    description: "当前申请与筛选仍以人工处理为主，因此更重要的是把路径、条件和下一步说清楚。",
  },
] as const;

const applyFaqs = [
  {
    question: "提交申请后通常会发生什么？",
    answer:
      "通常会先确认你申请的是 iOS、Android 还是合作沟通，再结合当前开放阶段决定是直接继续、补充信息，还是先说明暂未开放的状态。",
  },
  {
    question: "现在会承诺多快回复吗？",
    answer:
      "当前更适合承诺的是“会先说明当前阶段与下一步”，而不是给出一个并不稳定的自动回复时限。官网会优先把路径和所需信息写清楚，减少无效往返。",
  },
  {
    question: "如果现在还没有公开入口，我还有必要申请吗？",
    answer:
      "有必要。如果你已经明确想参与测试或合作，申请页的价值就在于让你进入正确队列，并获得当前阶段与后续动作说明，而不是继续在下载页反复猜测。",
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
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
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
            name: "申请测试",
            item: applyUrl,
          },
        ],
      },
      {
        "@type": "FAQPage",
        mainEntity: applyFaqs.map((item) => ({
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
          <p>申请后通常会发生什么</p>
          <h2>把处理节奏说清楚，比空泛承诺“很快回复”更能建立信任。</h2>
        </div>
        <div className="definition-grid">
          {applicationProcessSteps.map((item) => (
            <article key={item.title} className="definition-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>处理原则</p>
          <h2>官网应该先把会发生什么、不会假装什么写出来，让申请预期更加稳定。</h2>
        </div>
        <div className="compare-grid">
          {applicationReviewPrinciples.map((item) => (
            <article key={item.title} className="compare-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
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
          <p>常见问题</p>
          <h2>把申请后的预期、节奏和边界先回答出来，用户和生成式搜索都更容易理解这页的价值。</h2>
        </div>
        <div className="faq-list full">
          {applyFaqs.map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
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
