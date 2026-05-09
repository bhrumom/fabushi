import { brand, contactChannels, downloadOptions, faqItems, homeHighlights } from "@fabushi/shared";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { siteHref, siteUrl } from "../lib/site-url";

const heroSignals = ["佛法传播", "修行记录", "共修连接"] as const;

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
        description: "Fabushi 法布施官网，提供产品介绍、下载入口、测试申请与 FAQ。",
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} ${brand.englishName}`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "iOS, Android, Web",
        url: siteUrl("/download"),
        description: "佛法传播、修行记录与共修连接平台。",
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
            <p className="eyebrow">法布施 Fabushi</p>
            <p className="brand-kicker">{brand.tagline}</p>
            <h1>把佛法传播得更远。</h1>
            <p className="lede">
              上传分享、记录修行、找到同行者。官网只保留下载、内测申请和常见问题入口。
            </p>

            <div className="hero-actions">
              <a className="primary-action" href={siteHref("/apply")}>
                申请测试
              </a>
              <a className="secondary-action" href={siteHref("/download")}>
                查看下载
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
                <span>当前入口</span>
                <small>Beta</small>
              </div>
              <div className="hero-console-body">
                <div className="hero-console-line">
                  <em>01</em>
                  <strong>产品</strong>
                  <span>佛法传播、修行记录、共修连接</span>
                </div>
                <div className="hero-console-line">
                  <em>02</em>
                  <strong>下载</strong>
                  <span>Android 封闭测试，iOS 准备中</span>
                </div>
                <div className="hero-console-line">
                  <em>03</em>
                  <strong>参与</strong>
                  <span>申请测试、反馈问题、合作沟通</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="band editorial-band" id="capabilities">
        <div className="section-heading">
          <p>核心能力</p>
          <h2>传播、记录、连接。</h2>
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
          <p>下载</p>
          <h2>选择可用入口。</h2>
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
            <p>FAQ</p>
            <h2>先回答关键问题。</h2>
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
            <p>联系</p>
            <h2>申请测试或合作沟通。</h2>
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
