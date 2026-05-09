import { fabushiApiClient } from "@fabushi/api-client";
import { brand, contactChannels, faqItems, homeHighlights, homeUseCases } from "@fabushi/shared";
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
  const supportEmail = contactChannels.find((item) => item.href.startsWith("mailto:"))?.value ?? "support@fabushi.com";
  const faqPreview = faqItems.slice(0, 4);

  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        name: `${brand.name} Fabushi`,
        url: siteUrl("/"),
        email: supportEmail,
        description: brand.mission,
        sameAs: contactChannels.filter((item) => item.href.startsWith("https://")).map((item) => item.href),
      },
      {
        "@type": "WebSite",
        name: `${brand.name} 官网`,
        url: siteUrl("/"),
        inLanguage: "zh-CN",
        description: "Fabushi 官网，统一承接品牌说明、下载入口、测试申请、FAQ 与内容专栏。",
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} Fabushi`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "iOS, Android, Web, WeChat Mini Program",
        url: siteUrl("/download"),
        description:
          "围绕佛法传播、修行记录、公开档案、榜单与同行连接构建的多端产品体系。",
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

        <div className="hero-center">
          <div className="app-mark" aria-hidden="true">
            <span>法</span>
          </div>
          <p className="eyebrow">Fabushi official site</p>
          <h1>{brand.name}</h1>
          <p className="hero-subtitle">{brand.tagline}</p>
          <p className="lede">
            一个面向佛法传播、修行记录与同行连接的数字入口。官网负责把项目定位、下载状态、测试申请和常见问题讲清楚，让第一次到达的人也能知道下一步该去哪里。
          </p>
          <div className="hero-actions">
            <a className="primary-action" href={siteHref("/download")}>
              查看下载入口
            </a>
            <a className="secondary-action" href={siteHref("/apply")}>
              申请测试资格
            </a>
          </div>
          <div className="trust-strip" aria-label="当前官网状态">
            <span>官网</span>
            <span>下载状态</span>
            <span>测试申请</span>
            <span>内容专栏</span>
          </div>
        </div>
      </header>

      <section className="showcase-band" id="experience">
        <div className="product-frame" aria-label="Fabushi 官网体验预览">
          <div className="frame-sidebar">
            <span className="window-dot red" />
            <span className="window-dot yellow" />
            <span className="window-dot green" />
            <strong>Fabushi</strong>
            <nav>
              <span className="active">下载状态</span>
              <span>共修连接</span>
              <span>内容专栏</span>
              <span>FAQ</span>
            </nav>
          </div>
          <div className="frame-main">
            <div className="frame-topbar">
              <span>今日入口</span>
              <strong>{releasePreview.length > 0 ? `${releasePreview.length} 个发布入口` : "发布入口同步中"}</strong>
            </div>
            <div className="conversation">
              <p>我第一次看到 Fabushi，应该先做什么？</p>
              <article>
                <strong>先确认当前状态。</strong>
                <span>官网会把下载、内测、内容路线和支持入口放在同一处，减少来回寻找。</span>
              </article>
            </div>
            <div className="status-board">
              {releasePreview.length === 0 ? (
                <div className="status-card">
                  <span>发布</span>
                  <strong>入口持续同步中</strong>
                </div>
              ) : (
                releasePreview.map((item) => (
                  <a key={`${item.audience}-${item.platform}`} className="status-card" href={siteHref(item.primaryHref)}>
                    <span>{item.platform}</span>
                    <strong>{item.status}</strong>
                  </a>
                ))
              )}
            </div>
          </div>
        </div>
      </section>

      <section className="band feature-story" id="capabilities">
        <div className="section-heading">
          <p>核心能力</p>
          <h2>把理解、触达和深度使用连成一条清晰路径。</h2>
        </div>
        <div className="feature-rows">
          {homeHighlights.map((item, index) => (
            <article key={item.title} className="feature-row">
              <span>{String(index + 1).padStart(2, "0")}</span>
              <div>
                <h3>{item.title}</h3>
                <p>{item.description}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="band dark-band" id="audience">
        <div className="section-heading">
          <p>适合谁</p>
          <h2>官网先服务真实到达场景，而不是堆满抽象介绍。</h2>
        </div>
        <div className="use-case-grid">
          {homeUseCases.slice(0, 4).map((item) => (
            <article key={item.audience} className="use-case-block">
              <span className="detail-label">{item.audience}</span>
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band" id="download">
        <div className="section-heading">
          <p>下载与申请</p>
          <h2>当前能做什么，直接给出入口。</h2>
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
          <a className="platform-row accent-row" href={siteHref("/apply")}>
            <div>
              <span className="platform-name">测试与反馈</span>
              <p>适合想参与 iOS、Android 或合作沟通的人，直接进入申请路径。</p>
            </div>
            <div className="platform-meta">
              <strong>开放申请</strong>
              <span>提交意向</span>
            </div>
          </a>
        </div>
      </section>

      <section className="band content-band" id="insights">
        <div className="section-heading">
          <p>内容专栏</p>
          <h2>路线、更新和说明沉淀成可复查的公开内容。</h2>
        </div>
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
      </section>

      <section className="band faq-band" id="faq">
        <div className="section-heading">
          <p>常见问题</p>
          <h2>把用户最容易卡住的问题提前回答。</h2>
        </div>
        <div className="faq-list">
          {faqPreview.map((item) => (
            <details key={item.question} className="faq-item">
              <summary>{item.question}</summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
        <div className="contact-strip">
          <div>
            <span className="detail-label">公开数据</span>
            <strong>{leaderboard.length > 0 ? "排行榜预览已接入" : "静态信息可稳定访问"}</strong>
          </div>
          <a className="primary-action" href={`mailto:${supportEmail}`}>
            联系支持
          </a>
        </div>
      </section>

      <SiteFooter />
    </main>
  );
}
