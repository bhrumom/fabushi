import { fabushiApiClient } from "@fabushi/api-client";
import { brand, contactChannels, faqItems, homeHighlights, launchRoadmap } from "@fabushi/shared";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import { getAllArticles, getFeaturedArticles } from "../lib/content";
import { getOfficialSiteReleaseCollection } from "../lib/official-site-releases";
import { siteHref, siteUrl } from "../lib/site-url";

const audienceGroups = [
  {
    title: "第一次接触法布施的人",
    description: "先在官网看清产品定位、下载状态、FAQ 和首期开放范围，不必先进入应用才理解项目。",
  },
  {
    title: "想参与内测与反馈的人",
    description: "直接找到 Android Beta、iOS TestFlight、申请入口和支持邮箱，减少来回询问。",
  },
  {
    title: "关注传播与共修的人",
    description: "通过内容专栏、公开榜单、公开档案与后续专题页，理解平台如何承接佛法传播与同行连接。",
  },
] as const;

const trustPillars = [
  {
    title: "官网不是一张静态海报",
    description: "首页、下载入口、FAQ、内容专栏和联系信息都围绕真实用户问题来组织，降低首次理解成本。",
  },
  {
    title: "发布状态会回流到官网",
    description: "Android Beta、iOS TestFlight 与正式版信息会随着发布资产同步更新，避免入口失真或过期。",
  },
  {
    title: "内容、入口与应用体验分工清晰",
    description: "官网负责理解与转化，小程序负责轻触达，主应用负责完整体验，减少用户对渠道角色的困惑。",
  },
] as const;

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
        description:
          "Fabushi 法布施官网，集中提供产品介绍、下载入口、测试申请、FAQ 与更新内容，帮助用户快速理解平台定位与当前开放能力。",
      },
      {
        "@type": "SoftwareApplication",
        name: `${brand.name} ${brand.englishName}`,
        applicationCategory: "LifestyleApplication",
        operatingSystem: "iOS, Android, Web",
        url: siteUrl("/download"),
        description:
          "围绕佛法传播、修行记录、公开档案、榜单与共修连接构建的产品体系，官网负责下载引导、信息说明与持续内容更新。",
      },
      {
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
          <div className="hero-copy">
            <p className="eyebrow">佛法传播平台</p>
            <p className="brand-kicker">
              {brand.name} <span>Fabushi</span>
            </p>
            <h1>让佛法传播、修行记录与共修连接，在一个清晰可信的入口里开始。</h1>
            <p className="lede">
              Fabushi 官网集中承接产品介绍、下载入口、测试申请、FAQ 与更新内容，让第一次接触项目的人也能快速知道：
              这是什么、适合谁、现在能做什么。
            </p>
            <div className="hero-actions">
              <a className="primary-action" href={siteHref("/download")}>
                查看下载入口
              </a>
              <a className="secondary-action" href={siteHref("/apply")}>
                申请测试资格
              </a>
              <a className="tertiary-action" href={siteHref("/faq")}>
                先看常见问题
              </a>
            </div>
          </div>

          <aside className="hero-rail">
            <div className="hero-panel">
              <p>当前开放重点</p>
              <strong>官网先负责理解、入口与转化，再把轻触达交给小程序，把完整体验交给主应用。</strong>
              <span>
                这意味着首页会优先说清定位、下载状态、首期范围、FAQ 与联系路径，而不是只展示一句抽象口号。
              </span>
            </div>

            <div className="hero-mini-grid">
              <div className="mini-stat">
                <span>下载与发布</span>
                <strong>{releasePreview.length > 0 ? `${releasePreview.length} 个入口已同步` : "入口持续更新中"}</strong>
              </div>
              <div className="mini-stat">
                <span>内容专栏</span>
                <strong>{allArticles.length} 篇公开内容已上线</strong>
              </div>
              <div className="mini-stat">
                <span>信任与证明</span>
                <strong>{leaderboard.length > 0 ? "排行榜预览可直接读取" : "静态页面也能先完整理解项目"}</strong>
              </div>
            </div>
          </aside>
        </div>
      </header>

      <section className="band proof-band" id="why-fabushi">
        <div className="section-heading narrow">
          <p>为什么官网值得先看</p>
          <h2>先把“这是什么、现在开放到哪里、我下一步该点哪里”讲清楚，用户才会继续往下走。</h2>
        </div>
        <div className="proof-grid">
          {trustPillars.map((item) => (
            <article key={item.title} className="proof-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band alt" id="for-whom">
        <div className="section-heading">
          <p>适合谁先进入</p>
          <h2>如果你想理解法布施平台，而不是先下载再摸索，官网应该先把这三类人服务好。</h2>
        </div>
        <div className="audience-grid">
          {audienceGroups.map((item) => (
            <article key={item.title} className="audience-card">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band" id="capabilities">
        <div className="section-heading">
          <p>核心能力</p>
          <h2>官网要先把用户能感受到的价值说具体，再把渠道和技术分工解释清楚。</h2>
        </div>
        <div className="feature-grid">
          {homeHighlights.map((item) => (
            <article key={item.title} className="feature-block">
              <h3>{item.title}</h3>
              <p>{item.description}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band cinematic" id="download">
        <div className="section-heading">
          <p>下载与状态</p>
          <h2>下载页会优先承接真实发布状态，而不是让用户进入一个只会让他继续等待的空入口。</h2>
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
        <div className="inline-cta">
          <a className="primary-action" href={siteHref("/download")}>
            打开完整下载页
          </a>
          <a className="secondary-action" href={siteHref("/contact")}>
            联系支持
          </a>
        </div>
      </section>

      <section className="band alt" id="roadmap">
        <div className="split-layout">
          <div className="stack-card">
            <div className="section-heading compact">
              <p>首期范围</p>
              <h2>先把高频入口和轻触达路径跑通，再逐步扩到更重的体验。</h2>
            </div>
            <ol className="roadmap-list">
              {launchRoadmap.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ol>
            <div className="inline-cta">
              <a className="secondary-action" href={siteHref("/apply")}>
                申请参与首期测试
              </a>
            </div>
          </div>

          <div className="stack-card">
            <div className="section-heading compact">
              <p>公开证明</p>
              <h2>除了路线说明，官网也要给出能被快速验证的公开信息。</h2>
            </div>
            <div className="preview-list">
              {leaderboard.length === 0 ? (
                <p className="empty-copy">当前没有拉到排行榜预览，但下载、FAQ 与内容说明仍然可以完整承接首次访问。</p>
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
        </div>
      </section>

      <section className="band" id="insights">
        <div className="dual-grid">
          <div className="stack-card transparent">
            <div className="section-heading compact">
              <p>内容专栏</p>
              <h2>官网不仅负责下载和说明，也要持续承接路线、更新与专题解释。</h2>
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
          </div>

          <div className="stack-card transparent">
            <div className="section-heading compact">
              <p>常见问题</p>
              <h2>把搜索里最容易出现的问题先答出来，SEO 和 GEO 才更容易真正生效。</h2>
            </div>
            <div className="faq-list">
              {faqItems.slice(0, 4).map((item) => (
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
        </div>
      </section>

      <section className="band cta-band" id="contact">
        <div className="section-heading narrow">
          <p>联系与下一步</p>
          <h2>准备下载、申请测试、反馈问题或讨论合作时，官网应该把可执行的下一步摆在最前面。</h2>
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
