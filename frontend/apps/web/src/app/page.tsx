import { brand, contactChannels, downloadOptions, faqItems, homeHighlights } from "@fabushi/shared";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { siteHref, siteUrl } from "../lib/site-url";

const heroSignals = [
  "产品定位",
  "下载状态",
  "测试申请",
  "常见问题",
] as const;

const intentPaths = [
  {
    title: "先理解",
    description: "用最短路径看清法布施是什么、适合谁、现在开放到哪里。",
    href: "/faq",
    label: "查看常见问题",
  },
  {
    title: "再进入",
    description: "根据平台状态选择 Android、iOS 或小程序相关入口，不走空页面。",
    href: "/download",
    label: "打开下载入口",
  },
  {
    title: "然后参与",
    description: "如果你愿意内测、反馈问题或讨论合作，直接进入明确的联系路径。",
    href: "/apply",
    label: "申请测试资格",
  },
] as const;

const conciseFaq = faqItems.slice(0, 3);
const conciseHighlights = homeHighlights.slice(0, 3);
const conciseDownloads = downloadOptions.slice(0, 3);
const conciseContacts = contactChannels.slice(0, 2);

export default function HomePage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        name: `${brand.name} ${brand.englishName}`,
        alternateName: [brand.name, brand.englishName],
        url: siteUrl("/"),
        description: brand.mission,
        email: "support@fabushi.com",
        sameAs: ["https://github.com/bhrumom/fabushi"],
      },
      {
        "@type": "WebSite",
        name: `${brand.name} 官网`,
        url: siteUrl("/"),
        inLanguage: "zh-CN",
        description: "Fabushi 法布施官网，集中提供产品介绍、下载入口、测试申请与 FAQ。",
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} ${brand.englishName}`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "iOS, Android, Web",
        url: siteUrl("/download"),
        description: "围绕佛法传播、修行记录与共修连接构建的产品体系。",
      },
      {
        "@type": "FAQPage",
        mainEntity: conciseFaq.map((item) => ({
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
    <main className="page-shell home-shell">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

      <section className="hero">
        <SiteHeader />

        <div className="hero-stage">
          <div className="hero-copy">
            <p className="eyebrow">佛法传播平台</p>
            <p className="brand-kicker">
              {brand.name} <span>Fabushi</span>
            </p>
            <h1>一个更安静、更清晰的入口，让人先理解法布施，再决定是否进入。</h1>
            <p className="lede">
              官网不再试图一次讲完所有事情。它先把产品定位、下载状态、测试申请和常见问题整理清楚，让第一次到来的人几秒内知道下一步该去哪里。
            </p>

            <div className="hero-actions">
              <a className="primary-action" href={siteHref("/download")}>
                查看下载入口
              </a>
              <a className="secondary-action" href={siteHref("/faq")}>
                先看常见问题
              </a>
            </div>

            <div className="hero-signal-row" aria-label="首页重点信息">
              {heroSignals.map((item) => (
                <span key={item}>{item}</span>
              ))}
            </div>
          </div>

          <div className="hero-visual" aria-hidden="true">
            <div className="hero-orbit hero-orbit-a" />
            <div className="hero-orbit hero-orbit-b" />
            <div className="hero-console">
              <div className="hero-console-head">
                <span>Fabushi / Home</span>
                <small>Live structure</small>
              </div>
              <div className="hero-console-body">
                <div className="hero-console-line">
                  <em>01</em>
                  <strong>这是什么</strong>
                  <span>佛法传播、修行记录、共修连接</span>
                </div>
                <div className="hero-console-line">
                  <em>02</em>
                  <strong>现在能做什么</strong>
                  <span>看状态、找入口、申请测试、了解 FAQ</span>
                </div>
                <div className="hero-console-line">
                  <em>03</em>
                  <strong>下一步去哪里</strong>
                  <span>下载页、申请页、联系页</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="band compact-band" id="why-fabushi">
        <div className="section-heading narrow">
          <p>首页原则</p>
          <h2>少一点解释负担，多一点方向感。</h2>
        </div>
        <div className="statement-grid">
          {intentPaths.map((item) => (
            <article key={item.title} className="statement-card">
              <span>{item.title}</span>
              <h3>{item.description}</h3>
              <a href={siteHref(item.href)}>{item.label}</a>
            </article>
          ))}
        </div>
      </section>

      <section className="band editorial-band" id="capabilities">
        <div className="section-heading">
          <p>核心能力</p>
          <h2>法布施不是一个单点工具，而是一条从传播到连接的连续路径。</h2>
        </div>

        <div className="editorial-feature-grid">
          {conciseHighlights.map((item, index) => (
            <article key={item.title} className="feature-column">
              <small>{`0${index + 1}`}</small>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt minimal-band" id="download">
        <div className="section-heading">
          <p>当前入口</p>
          <h2>把真实状态摆在前面，比堆很多承诺更有用。</h2>
        </div>

        <div className="platform-list">
          {conciseDownloads.map((item) => (
            <a key={item.platform} className="platform-row refined" href={siteHref(item.ctaHref)}>
              <div>
                <span className="platform-name">{item.platform}</span>
                <p>{item.description}</p>
              </div>
              <div className="platform-meta">
                <strong>{item.status}</strong>
                <span>{item.ctaLabel}</span>
              </div>
            </a>
          ))}
        </div>
      </section>

      <section className="band faq-band" id="faq">
        <div className="faq-shell">
          <div className="section-heading compact">
            <p>常见问题</p>
            <h2>先回答最容易被搜索、也最容易卡住转化的问题。</h2>
          </div>

          <div className="faq-list">
            {conciseFaq.map((item) => (
              <details key={item.question} className="faq-item">
                <summary>{item.question}</summary>
                <p>{item.answer}</p>
              </details>
            ))}
          </div>

          <div className="inline-cta">
            <a className="secondary-action" href={siteHref("/faq")}>
              查看完整 FAQ
            </a>
          </div>
        </div>
      </section>

      <section className="band cta-band" id="contact">
        <div className="cta-panel">
          <div className="section-heading compact narrow">
            <p>下一步</p>
            <h2>准备下载、申请测试或直接联系时，官网只保留最清楚的入口。</h2>
          </div>

          <div className="contact-grid minimal">
            {conciseContacts.map((item) => (
              <a key={item.label} className="contact-card minimal" href={siteHref(item.href)}>
                <span>{item.label}</span>
                <strong>{item.value}</strong>
                <p>{item.note}</p>
              </a>
            ))}
          </div>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
