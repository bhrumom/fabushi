import type { Metadata } from "next";
import { brand, contactChannels } from "@fabushi/shared";
import { SiteFooter } from "../../components/site-footer";
import { SiteHeader } from "../../components/site-header";
import { siteHref, siteUrl } from "../../lib/site-url";

const contactUrl = siteUrl("/contact");
const contactTitle = `联系 | ${brand.name}`;
const contactDescription = "查看 Fabushi 的支持邮箱、官网域名和公开仓库入口。";

const contactJourneys = [
  {
    title: "下载申请、测试资格、问题反馈",
    description: "优先走支持邮箱，并在邮件里直接带上平台、机型、场景和你最想解决的问题。",
    href: "mailto:support@fabushi.com",
    ctaLabel: "发送支持邮件",
  },
  {
    title: "想看公开进度、Issue 和协作记录",
    description: "优先去 GitHub 仓库，这条路径更适合公开问题跟踪、版本记录和技术协作。",
    href: "https://github.com/bhrumom/fabushi",
    ctaLabel: "打开 GitHub 仓库",
  },
  {
    title: "想转发官网或确认正式入口",
    description: "优先使用官网域名，把首页、下载页、FAQ 和隐私说明作为统一对外入口来转发。",
    href: "https://fabushi.ombhrum.com",
    ctaLabel: "打开官网域名",
  },
] as const;

const contactBoundaries = [
  {
    title: "涉及个人信息或资格判断",
    description: "像邮箱、设备信息、测试资格、下载失败截图这类内容，更适合走支持邮箱，不适合直接公开到 issue 里。",
  },
  {
    title: "涉及公开问题、版本记录或站点建议",
    description: "只要内容适合公开复查、也对后续协作有帮助，优先沉淀到 GitHub 会更清楚。",
  },
  {
    title: "只是想确认正式入口和项目定位",
    description: "先用官网页做转发和说明，通常比把同样的问题反复发给支持邮箱更高效。",
  },
] as const;

const responseSignals = [
  {
    title: "先给出清楚的来意",
    description: "说明你是想下载、申请测试、反馈问题，还是讨论合作，后续转接会更快。",
  },
  {
    title: "设备与平台信息尽量一次带全",
    description: "尤其是 Android 机型、iOS 邮箱、系统版本和触发问题的场景，能明显减少来回确认。",
  },
  {
    title: "公开问题尽量沉淀到 GitHub",
    description: "这样更适合后续复查、团队协作和外部理解，也能提升站点的公开可信度。",
  },
] as const;

const contactFaqs = [
  {
    question: "什么情况应该优先发支持邮箱？",
    answer:
      "凡是涉及测试资格、下载问题、设备环境、个人邮箱、账号信息或不适合公开暴露的内容，都更适合先发支持邮箱。",
  },
  {
    question: "什么情况更适合提 GitHub issue？",
    answer:
      "如果问题可以公开复现、对后续版本记录有帮助，或者属于官网结构、文案和公开体验建议，优先沉淀到 GitHub 会更清楚。",
  },
  {
    question: "联系时最好一次带上哪些信息？",
    answer:
      "至少带上你的目标、所用平台、机型或系统版本、触发场景，以及你最希望解决的问题。这样通常能减少很多来回确认。",
  },
] as const;

export const metadata: Metadata = {
  title: contactTitle,
  description: contactDescription,
  alternates: {
    canonical: contactUrl,
  },
  keywords: ["联系 Fabushi", "法布施支持邮箱", "法布施官网", "Fabushi GitHub", "法布施合作"],
  openGraph: {
    title: contactTitle,
    description: contactDescription,
    url: contactUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: contactTitle,
    description: contactDescription,
  },
};

export default function ContactPage() {
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@fabushi.com";
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "ContactPage",
        name: `${brand.name} 联系方式`,
        url: contactUrl,
        inLanguage: "zh-CN",
        description: "Fabushi 的支持邮箱、官网域名与公开仓库入口。",
        mainEntity: {
          "@type": "Organization",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
          email: supportEmail,
          sameAs: contactChannels.filter((item) => item.href.startsWith("https://")).map((item) => item.href),
          contactPoint: [
            {
              "@type": "ContactPoint",
              contactType: "customer support",
              email: supportEmail,
              availableLanguage: ["zh-CN"],
            },
          ],
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
            name: "联系",
            item: contactUrl,
          },
        ],
      },
      {
        "@type": "FAQPage",
        mainEntity: contactFaqs.map((item) => ({
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
          <p className="eyebrow">联系</p>
          <h1>官网至少要给出清楚、稳定、能回应的联系入口。</h1>
          <p className="lede">
            当前最重要的是把支持邮箱、官网域名和公开仓库入口放到明确位置，让下载申请、测试资格和问题反馈都有固定去处。
          </p>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>先选路径</p>
          <h2>不同问题去不同入口，沟通会比“先发一封没有上下文的邮件”顺畅得多。</h2>
        </div>
        <div className="path-grid">
          {contactJourneys.map((item) => (
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
          <p>固定入口</p>
          <h2>让下载、申请、合作和公开协作都有稳定入口，用户才会更愿意继续往下走。</h2>
        </div>
        <div className="contact-grid">
          {contactChannels.map((item) => (
            <a key={item.label} className="contact-card" href={siteHref(item.href)}>
              <span>{item.label}</span>
              <strong>{item.value}</strong>
              <p>{item.note}</p>
            </a>
          ))}
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>公开与私密边界</p>
          <h2>把什么适合公开、什么适合私下联系写清楚，本身就是信任信息的一部分。</h2>
        </div>
        <div className="definition-grid">
          {contactBoundaries.map((item) => (
            <article key={item.title} className="definition-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band">
        <div className="section-heading">
          <p>联系前最好准备什么</p>
          <h2>把这些信息一次带全，往返确认通常会少很多。</h2>
        </div>
        <div className="evidence-grid">
          {responseSignals.map((item) => (
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
          <h2>把联系边界和入口职责先写清楚，用户与搜索系统都更容易找到正确路径。</h2>
        </div>
        <div className="faq-list full">
          {contactFaqs.map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/apply")}>
            去申请测试
          </a>
          <a className="secondary-action" href={siteHref("/privacy")}>
            查看隐私说明
          </a>
          <a className="secondary-action" href={siteHref("/download")}>
            回到下载页
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
