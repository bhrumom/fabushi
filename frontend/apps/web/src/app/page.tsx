import { fabushiApiClient } from "@fabushi/api-client";
import {
  audienceJourneys,
  brand,
  contactChannels,
  faqItems,
  homeHighlights,
  launchRoadmap,
  productSurfaceMap,
  trustHighlights,
} from "@fabushi/shared";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { getAllArticles, getFeaturedArticles } from "../lib/content";
import { getOfficialSiteReleaseCollection } from "../lib/official-site-releases";
import { siteHref, siteUrl } from "../lib/site-url";

async function getLeaderboardPreview() {
  try {
    const data = await fabushiApiClient.get<{
      leaderboard: Array<{
        username: string;
        displayName: string;
        totalBytes: number;
      }>;
    }>("/api/leaderboard?limit=3");
    return data.leaderboard;
  } catch {
    return [];
  }
}

export default async function HomePage() {
  const leaderboard = await getLeaderboardPreview();
  const featuredArticles = getFeaturedArticles();
  const allArticles = getAllArticles();
  const releaseCollection = await getOfficialSiteReleaseCollection();
  const releasePreview = [...releaseCollection.betaChannels, ...releaseCollection.stableChannels].slice(0, 3);

  const structuredData = [
    {
      "@context": "https://schema.org",
      "@type": "Organization",
      name: brand.name,
      alternateName: brand.englishName,
      url: siteUrl("/"),
      email: "support@fabushi.com",
      sameAs: ["https://github.com/bhrumom/fabushi"],
      description: brand.mission,
    },
    {
      "@context": "https://schema.org",
      "@type": "WebSite",
      name: `${brand.name}官网`,
      url: siteUrl("/"),
      description: brand.mission,
      inLanguage: "zh-CN",
    },
    {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      mainEntity: faqItems.slice(0, 4).map((item) => ({
        "@type": "Question",
        name: item.question,
        acceptedAnswer: {
          "@type": "Answer",
          text: item.answer,
        },
      })),
    },
  ];

  return (
    <main className="page-shell">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }} />

      <header className="hero">
        <SiteHeader />

        <div className="hero-grid">
          <div className="hero-copy">
            <p className="eyebrow">法布施官网</p>
            <p className="brand-kicker">{brand.name}</p>
            <h1>把佛法传播、修行记录与共修协作，收进一个清楚、可信、可持续的数字入口。</h1>
            <p className="lede">
              {brand.mission} 当前官网优先解决三件事：把产品讲清楚，把下载与测试入口讲明白，把官网、微信小程序和主应用的职责边界讲透。
            </p>
            <div className="hero-actions">
              <a className="primary-action" href={siteHref("/download")}>
                查看下载入口
              </a>
              <a className="secondary-action" href={siteHref("/#product-surfaces")}>
                了解三端分工
              </a>
            </div>
            <div className="kicker-list" aria-label="首页关键信息">
              <span>官网承接搜索与对外入口</span>
              <span>小程序承接微信生态轻触达</span>
              <span>主应用承接完整长期体验</span>
            </div>
          </div>

          <aside className="hero-panel" aria-label="当前站点策略">
            <p>当前站点策略</p>
            <strong>先把入口和边界讲清楚，再把发布链路、内容运营和搜索可见性持续接进来。</strong>
            <div className="hero-route-map">
              <div className="hero-route-item">
                <span>官网</span>
                <strong>说明、搜索、下载入口、FAQ</strong>
              </div>
              <div className="hero-route-item">
                <span>微信小程序</span>
                <strong>轻浏览、榜单、公开档案、基础登录</strong>
              </div>
              <div className="hero-route-item">
                <span>Flutter 主应用</span>
                <strong>沉浸式体验、创作上传、长期记录</strong>
              </div>
            </div>
          </aside>
        </div>
      </header>

      <section className="band trust-band" aria-labelledby="trust-heading">
        <div className="section-heading compact" id="trust-heading">
          <p>信任与判断依据</p>
          <h2>不只讲愿景，也把用户现在最需要确认的真实信息直接放在首页。</h2>
        </div>
        <div className="trust-grid">
          {trustHighlights.map((item) => (
            <article key={item.title} className="trust-item">
              <span>{item.title}</span>
              <strong>{item.value}</strong>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band" id="capabilities">
        <div className="section-heading">
          <p>核心能力</p>
          <h2>法布施当前最适合先被理解成一个帮助传播、记录、发现与共修连接的多端产品体系。</h2>
        </div>
        <div className="feature-grid feature-grid-wide">
          {homeHighlights.map((item) => (
            <article key={item.title} className="feature-block">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt" id="audiences">
        <div className="section-heading">
          <p>适合谁用</p>
          <h2>首页不只回答“这是什么”，也应该回答“这对谁现在最有用”。</h2>
        </div>
        <div className="journey-grid">
          {audienceJourneys.map((item) => (
            <article key={item.title} className="journey-card">
              <h3>{item.title}</h3>
              <p className="journey-summary">{item.summary}</p>
              <p>{item.detail}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band" id="product-surfaces">
        <div className="section-heading">
          <p>产品分工</p>
          <h2>官网、小程序和主应用不是三张重复页面，而是三种职责清楚的入口与工作面。</h2>
        </div>
        <div className="surface-grid">
          {productSurfaceMap.map((item) => (
            <article key={item.title} className="surface-card">
              <span className="surface-tag">{item.title}</span>
              <h3>{item.role}</h3>
              <p>{item.bestFor}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band cinematic">
        <div className="section-heading">
          <p>下载与发布状态</p>
          <h2>官网现在已经开始承接真实发布状态，而不是只放一段静态等待说明。</h2>
        </div>
        <div className="platform-strip">
          {releasePreview.map((item) => (
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
        </div>
        <div className="status-note-list">
          {releaseCollection.notes.map((item) => (
            <p key={item}>{item}</p>
          ))}
        </div>
      </section>

      <section className="band alt" id="mini-program">
        <div className="section-heading">
          <p>为什么先这样做</p>
          <h2>当前阶段最重要的不是把所有功能一次堆满，而是先把每个入口的工作边界和推进顺序做对。</h2>
        </div>
        <div className="definition-grid">
          <div className="definition-card">
            <h3>先把官网做成真实入口</h3>
            <p>官网先承接品牌说明、下载判断、FAQ 和内容页，才能稳定支持搜索、分享和后续活动页面扩展。</p>
          </div>
          <div className="definition-card">
            <h3>小程序先做轻路径</h3>
            <p>微信生态更适合轻浏览、公开发现和快速传播，所以首期优先覆盖榜单、档案、登录和基础触达链路。</p>
          </div>
          <div className="definition-card">
            <h3>主应用保留重体验</h3>
            <p>更完整的创作、上传、沉浸式浏览和长期记录仍由主应用承接，避免为了轻入口反而稀释核心体验。</p>
          </div>
        </div>
        <ol className="roadmap-list">
          {launchRoadmap.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ol>
      </section>

      <section className="band" id="proof">
        <div className="section-heading">
          <p>真实接口验证</p>
          <h2>首页已经不只是文案展示，它会直接读取现有后端接口和持续内容资产。</h2>
        </div>
        <div className="proof-layout">
          <div>
            <h3>排行榜预览</h3>
            <div className="preview-list">
              {leaderboard.length === 0 ? (
                <p className="empty-copy">当前没有拉到排行榜预览，页面仍可正常展示静态说明与下载入口。</p>
              ) : (
                leaderboard.map((item, index) => (
                  <div key={item.username} className="preview-row">
                    <span>#{index + 1}</span>
                    <strong>{item.displayName || item.username}</strong>
                    <span>{item.totalBytes.toLocaleString()} bytes</span>
                  </div>
                ))
              )}
            </div>
          </div>
          <div>
            <h3>内容专栏</h3>
            <div className="editorial-list">
              {featuredArticles.map((item) => (
                <a key={item.slug} className="editorial-row" href={siteHref(`/insights/${item.slug}`)}>
                  <span>{item.category}</span>
                  <div>
                    <strong>{item.title}</strong>
                    <p>{item.description}</p>
                    <small>
                      {item.author} · {item.readTime}
                    </small>
                  </div>
                </a>
              ))}
            </div>
            <div className="inline-cta">
              <a className="secondary-action" href={siteHref("/insights")}>
                查看全部 {allArticles.length} 篇内容
              </a>
            </div>
          </div>
        </div>
      </section>

      <section className="band alt">
        <div className="section-heading">
          <p>常见问题</p>
          <h2>把最常反复解释的问题直接写成清楚答案，更利于搜索理解、AI 摘要和人工判断。</h2>
        </div>
        <div className="faq-list">
          {faqItems.slice(0, 4).map((item) => (
            <details key={item.question} className="faq-item" open>
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="inline-cta">
          <a className="secondary-action" href={siteHref("/faq")}>
            查看完整 FAQ
          </a>
          <a className="secondary-action" href={siteHref("/contact")}>
            联系我们
          </a>
        </div>
      </section>

      <section className="band final-cta-band">
        <div className="final-cta">
          <div>
            <p className="eyebrow">下一步</p>
            <h2>先选正确入口，再决定是体验、反馈、传播还是合作。</h2>
            <p className="lede small">
              当前官网已经适合承担说明、下载判断和内容承接。下一步最自然的动作，是去看下载状态、申请测试资格，或者直接进入公开开发记录。
            </p>
          </div>
          <div className="hero-actions final-actions">
            <a className="primary-action" href={siteHref("/download")}>
              去下载入口
            </a>
            <a className="secondary-action" href={siteHref("/apply")}>
              申请测试
            </a>
          </div>
        </div>
      </section>

      <section className="band">
        <div className="section-heading compact">
          <p>联系</p>
          <h2>除了下载入口之外，官网也要把支持、反馈和公开协作的去处讲清楚。</h2>
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

      <SiteFooter />
    </main>
  );
}
