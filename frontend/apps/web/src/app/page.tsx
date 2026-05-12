import { brand, contactChannels, faqItems, homeHighlights } from "@fabushi/shared";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { ZenOrbit } from "../components/zen-orbit";
import { getOfficialSiteReleaseCollection } from "../lib/official-site-releases";
import { siteHref, siteUrl } from "../lib/site-url";

const productMoments = [
  {
    title: "经文听诵",
    description: "读经、听诵、进度保存。",
    image: "/product/sutra.png",
  },
  {
    title: "全球法布施",
    description: "一键发送，看见善意抵达世界。",
    image: "/product/home.png",
  },
  {
    title: "禅修冥想",
    description: "禅室、计时、修行记录。",
    image: "/product/home.png",
  },
  {
    title: "法流视频",
    description: "滑动浏览佛法内容。",
    image: "/product/video.png",
  },
] as const;

export default async function HomePage() {
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const channels = [...releaseCollection.betaChannels, ...releaseCollection.stableChannels].slice(0, 3);
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@ombhrum.com";
  const directChannel = releaseCollection.betaChannels.find((item) => !item.primaryHref.startsWith("/contact"));
  const primaryHref = directChannel?.primaryHref ?? "/download";
  const primaryLabel = directChannel?.primaryLabel ?? "查看下载入口";
  const faqPreview = faqItems.slice(0, 4);

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        name: `${brand.name} 大乘`,
        url: siteUrl("/"),
        email: supportEmail,
        description: brand.mission,
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} 大乘`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "iOS, Android, Web",
        url: siteUrl("/download"),
        description: brand.tagline,
      },
      {
        "@type": "FAQPage",
        mainEntity: faqPreview.map((item) => ({
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
    <main className="page-shell">
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

      <header className="hero">
        <SiteHeader />
        <div className="hero-grid">
          <section className="hero-copy" aria-labelledby="home-title">
            <div className="brand-kicker">
              <img src={siteHref("/product/app-icon.png")} alt="" />
              <span>大乘</span>
            </div>
            <h1 id="home-title">法布施</h1>
            <p className="hero-subtitle">{brand.tagline}</p>
            <div className="hero-actions">
              <a className="primary-action" href={siteHref(primaryHref)}>
                {primaryLabel}
              </a>
              <a className="secondary-action" href={siteHref("/apply")}>
                申请测试
              </a>
            </div>

            <div className="release-pill-grid" aria-label="当前下载状态">
              {channels.length > 0 ? (
                channels.map((item) => (
                  <a key={`${item.audience}-${item.platform}`} className="release-pill" href={siteHref(item.primaryHref)}>
                    <span>{item.title}</span>
                    <strong>{item.status}</strong>
                  </a>
                ))
              ) : (
                <a className="release-pill" href={siteHref("/download")}>
                  <span>下载入口</span>
                  <strong>同步中</strong>
                </a>
              )}
            </div>
          </section>

          <section className="hero-visual" aria-label="大乘 产品预览">
            <ZenOrbit />
            <div className="phone-stack">
              <div className="phone-frame main-phone">
                <img src={siteHref("/product/home.png")} alt="大乘 全球法布施界面预览" />
              </div>
              <div className="phone-frame side-phone">
                <img src={siteHref("/product/video.png")} alt="大乘 法流视频界面预览" />
              </div>
            </div>
          </section>
        </div>
      </header>

      <section className="band compact-band" id="download">
        <div className="section-heading tight">
          <p>下载</p>
          <h2>按你的平台进入。</h2>
        </div>
        <div className="platform-strip">
          {channels.map((item) => (
            <a key={`${item.audience}-${item.platform}`} className="platform-row" href={siteHref(item.primaryHref)}>
              <div>
                <span className="platform-name">{item.title}</span>
                <p>{item.description}</p>
              </div>
              <div className="platform-meta">
                <strong>{item.status}</strong>
                <span>{item.primaryLabel}</span>
              </div>
            </a>
          ))}
          <a className="platform-row accent-row" href={siteHref("/download")}>
            <div>
              <span className="platform-name">全部入口</span>
              <p>查看 Android、iOS、正式版和镜像说明。</p>
            </div>
            <div className="platform-meta">
              <strong>下载页</strong>
              <span>进入</span>
            </div>
          </a>
        </div>
      </section>

      <section className="band feature-band" id="features">
        <div className="section-heading tight">
          <p>体验</p>
          <h2>留下真正有用的信息。</h2>
        </div>
        <div className="feature-grid">
          {homeHighlights.map((item) => (
            <article key={item.title} className="feature-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band product-band">
        <div className="section-heading tight">
          <p>预览</p>
          <h2>打开后会看到这些。</h2>
        </div>
        <div className="moment-grid">
          {productMoments.map((item) => (
            <article key={item.title} className="moment-card">
              <div className="moment-image">
                <img src={siteHref(item.image)} alt={`${item.title}界面预览`} loading="lazy" />
              </div>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band faq-band" id="faq">
        <div className="section-heading tight">
          <p>FAQ</p>
          <h2>先回答最关键的。</h2>
        </div>
        <div className="faq-list">
          {faqPreview.map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/faq")}>
            查看全部常见问题
          </a>
          <a className="secondary-action" href={`mailto:${supportEmail}`}>
            联系支持
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
